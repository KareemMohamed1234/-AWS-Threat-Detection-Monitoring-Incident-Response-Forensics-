"""SOAR responder: isolates a compromised EC2 instance and/or deactivates an
exposed IAM access key, starts the forensic-snapshot runbook and notifies SNS.

Triggered by EventBridge from Security Hub (automatic rule or analyst custom action).
Environment variables: QUARANTINE_SG_ID, SNS_TOPIC_ARN, RUNBOOK_NAME, AUTOMATION_ROLE_ARN
"""
import json
import os

import boto3
from botocore.exceptions import ClientError

ec2 = boto3.client("ec2")
iam = boto3.client("iam")
ssm = boto3.client("ssm")
sns = boto3.client("sns")

QUARANTINE_SG = os.environ["QUARANTINE_SG_ID"]
TOPIC_ARN = os.environ["SNS_TOPIC_ARN"]
RUNBOOK = os.environ["RUNBOOK_NAME"]
AUTOMATION_ROLE = os.environ["AUTOMATION_ROLE_ARN"]


def isolate_instance(instance_id):
    reservations = ec2.describe_instances(InstanceIds=[instance_id])["Reservations"]
    instance = reservations[0]["Instances"][0]
    tags = {t["Key"]: t["Value"] for t in instance.get("Tags", [])}
    if tags.get("IR-Exempt") == "true":
        return f"{instance_id}: skipped (tag IR-Exempt=true)"
    enis = instance["NetworkInterfaces"]
    current = {g["GroupId"] for eni in enis for g in eni["Groups"]}
    if current == {QUARANTINE_SG}:
        return f"{instance_id}: already quarantined"
    for eni in enis:
        ec2.modify_network_interface_attribute(NetworkInterfaceId=eni["NetworkInterfaceId"], Groups=[QUARANTINE_SG])
    ec2.create_tags(Resources=[instance_id], Tags=[{"Key": "IR-Status", "Value": "Quarantined"}])
    ssm.start_automation_execution(
        DocumentName=RUNBOOK,
        Parameters={"InstanceId": [instance_id], "TopicArn": [TOPIC_ARN], "AutomationAssumeRole": [AUTOMATION_ROLE]},
    )
    return f"{instance_id}: isolated with {QUARANTINE_SG}; forensic snapshot runbook started"


def deactivate_key(details):
    key_id = details.get("AccessKeyId")
    user = details.get("PrincipalName")
    if not key_id or not user:
        return "access key: finding has no user/key id, nothing deactivated"
    iam.update_access_key(UserName=user, AccessKeyId=key_id, Status="Inactive")
    return f"access key {key_id} of user {user}: deactivated"


def handler(event, context):
    actions = []
    for finding in event.get("detail", {}).get("findings", []):
        title = finding.get("Title", "(no title)")
        sev = finding.get("Severity", {}).get("Label", "?")
        for res in finding.get("Resources", []):
            try:
                if res.get("Type") == "AwsEc2Instance":
                    actions.append(isolate_instance(res["Id"].split("/")[-1]))
                elif res.get("Type") == "AwsIamAccessKey":
                    actions.append(deactivate_key(res.get("Details", {}).get("AwsIamAccessKey", {})))
            except ClientError as err:
                actions.append(f"{res.get('Id')}: FAILED - {err.response['Error']['Code']}")
        message = f"Finding: {title}\nSeverity: {sev}\nActions:\n- " + "\n- ".join(actions or ["none (no supported resource)"])
        sns.publish(TopicArn=TOPIC_ARN, Subject=f"IR automated response: {sev} finding"[:100], Message=message)
        print(message)
    return {"actions": actions}
