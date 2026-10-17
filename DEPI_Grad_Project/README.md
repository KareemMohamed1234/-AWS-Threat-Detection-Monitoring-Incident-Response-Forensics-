# AWS Threat Detection, Monitoring, Incident Response & Forensics

**Central Logging, Managed Threat Detection, Forensic Incident Response & SOAR-Style Automation on AWS**

DEPI – AWS Security Cloud Computing Track – Project 4

## Overview

A cloud security operations environment on AWS that records every action, detects threats, contains incidents while preserving evidence, and automates the response:

- **Logging & Audit Foundation:** CloudTrail organization trail, CloudWatch Logs, AWS Config, VPC Flow Logs, S3 server access logs, and ELB access logs delivered to an encrypted S3 log archive with a retention policy, queried using Amazon Athena.
- **Threat Detection:** Amazon GuardDuty, AWS Security Hub, Amazon Detective, Amazon Inspector, Amazon Macie, AWS Trusted Advisor, and AWS Config rules. Findings are triaged and mapped to MITRE ATT&CK.
- **Incident Response & Forensics:** Three simulated incidents: compromised EC2 instance, exposed access keys, and public S3 bucket. Response actions include instance isolation, IAM access revocation, key rotation, S3 Block Public Access, EBS snapshots, log capture, evidence hashing, incident timelines, root cause analysis, and chain-of-custody notes.
- **Automation & Reporting:** EventBridge, Lambda, SSM Automation, and Security Hub custom actions form SOAR-style playbooks that isolate instances, create snapshots, revoke exposed keys, and notify the team through SNS email. Technical and executive incident response reports include lessons learned.
- **Infrastructure as Code:** All infrastructure is provisioned using Terraform.

The environment protects a reference workload consisting of an internet-facing load balancer, a web server in a public subnet, an application server in a private subnet, an Amazon RDS database containing customer test data, EBS volumes, an S3 data bucket, and IAM users with access keys. All data is test data.

## Team

| Name | Role |
| --- | --- |
| Kareem Mohamed Abdalmged | Team Lead, IaC & Documentation |
| Adham Ramzy Mohamed Eltohamy | Threat Detection Engineer |
| Hossam Abdelghany Mostafa | Incident Response & Forensics Engineer |
| Alaa Ahmed Ramadan | Logging & Audit Engineer |
| Amira Ashraf Saber | Automation & Reporting Engineer |

**Instructor:** Ahmed Gamal

## Deliverables

| # | Deliverable | Due | Status | Location |
| --- | --- | --- | --- | --- |
| 1 | Project Planning & Management | 16 Oct 2026 | Ready | [Project Planning PDF](docs/1_Project_Planning_and_Management.pdf) |
| 2 | Literature Review | 16 Oct 2026 | Ready | [Literature Review PDF](docs/2_Literature_Review.pdf) |
| 3 | Requirements Gathering | 16 Oct 2026 | Ready | [Requirements PDF](docs/3_Requirements_Gathering.pdf) |
| 4 | System Analysis & Design | 6 Nov 2026 | Not started | [System_Design](docs/4_System_Design) |
| 5 | Implementation (Source Code) | 30 Nov 2026 | Not started | [terraform](terraform), [lambda](lambda) |
| 6 | Testing & Quality Assurance | 4 Dec 2026 | Not started | [docs/05-testing](docs/05-testing) |
| 7 | Final Presentation & Reports | 4 Dec 2026 | Not started | [docs/06-final-presentation](docs/06-final-presentation) |

## Repository Structure

    DEPI_Grad_Project/
    ├── docs/
    │   ├── 01-project-planning/
    │   ├── 02-literature-review/
    │   ├── 03-requirements/
    │   ├── 04-system-design/
    │   ├── 05-testing/
    │   └── 06-final-presentation/
    ├── terraform/
    │   ├── modules/
    │   │   ├── logging-audit/
    │   │   ├── threat-detection/
    │   │   ├── ir-forensics/
    │   │   └── soar-automation/
    │   └── environments/lab/
    ├── lambda/
    │   ├── isolate-instance/
    │   └── deactivate-access-key/
    ├── playbooks/
    ├── athena-queries/
    └── evidence/

## Branching Strategy

- `main` holds reviewed, working code and final documents only.
- Each team member works on a feature branch, such as `feature/logging-audit`, `feature/soar-automation`, or `docs/system-design`.
- Changes reach `main` through a pull request reviewed by the team leader.
- Commit messages clearly describe the change, for example: `Add organization trail with log file validation to logging-audit`.

## Security Rules for This Repository

- Never commit AWS access keys, `.tfstate`, or `.tfvars` files. These files must be excluded through `.gitignore`.
- Use temporary credentials through IAM Identity Center and `aws sso login`.
- The exposed-key simulation uses a canary IAM user with minimal permissions; its access keys must never be committed.
- Simulate incidents only on tagged lab resources. Do not use real malware or real sensitive data.
- Run `terraform destroy` and disable detection services after every lab session to avoid unnecessary charges.

Setup, configuration, and execution instructions will be added with the implementation.
