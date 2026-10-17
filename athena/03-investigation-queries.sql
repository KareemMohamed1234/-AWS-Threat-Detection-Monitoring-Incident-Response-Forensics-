-- 1) Who is talking to us and being REJECTED? (VPC Flow Logs)
SELECT srcaddr, dstport, count(*) AS hits
FROM ir_lab.vpc_flow_logs
WHERE action = 'REJECT' AND "date" >= date_format(current_date - interval '1' day, '%Y/%m/%d')
GROUP BY srcaddr, dstport ORDER BY hits DESC LIMIT 20;

-- 2) Everything one access key did (CloudTrail) - replace the key id
SELECT eventtime, eventsource, eventname, sourceipaddress, useragent, errorcode
FROM ir_lab.cloudtrail_logs
WHERE useridentity.accesskeyid = 'AKIAXXXXXXXXXXXXXXXX'
ORDER BY eventtime;

-- 3) Calls from IPs other than the app server (find leaked-key use)
SELECT sourceipaddress, count(*) AS calls, array_agg(DISTINCT eventname) AS events
FROM ir_lab.cloudtrail_logs
WHERE useridentity.username = 'app-storage-user'
GROUP BY sourceipaddress ORDER BY calls DESC;

-- 4) Public-access / policy changes on S3 (the public-bucket scenario)
SELECT eventtime, useridentity.arn, eventname, json_extract_scalar(requestparameters, '$.bucketName') AS bucket
FROM ir_lab.cloudtrail_logs
WHERE eventname IN ('PutBucketPolicy','PutBucketAcl','DeletePublicAccessBlock','PutPublicAccessBlock','PutBucketPublicAccessBlock')
ORDER BY eventtime DESC;

-- 5) Security-group changes (isolation actions and tampering)
SELECT eventtime, useridentity.arn, eventname, sourceipaddress
FROM ir_lab.cloudtrail_logs
WHERE eventname IN ('ModifyInstanceAttribute','ModifyNetworkInterfaceAttribute','AuthorizeSecurityGroupIngress','RevokeSecurityGroupEgress')
ORDER BY eventtime DESC;
