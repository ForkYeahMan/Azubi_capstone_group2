# IAM — Users, Groups & Policies

## Account ID: `286664220957`

---

## Users

| Username | Group | Role |
|----------|-------|------|
| `Amartey` | `project-architects` | Architect / lead |
| `Larry` | `project-architects` | Architect |
| `Loretta` | `project-backend-devops` | Backend / DevOps engineer |
| `Akosa` | `project-frontend` | Frontend engineer |
| `Bright` | `project-frontend` | Frontend engineer |
| `aws-cli-user` | none | CLI tooling / admin access |
| `nextjs-cicd-deploy` | none | GitHub Actions CI/CD service account |

---

## Groups & Policies

### `project-architects` — Amartey, Larry

**Policy:** `ProjectReadAllPolicy` (managed, customer)

This group is for the infrastructure architects who design and oversee the full stack. They have broad read and operational permissions but **cannot destroy production resources** (no `DeleteLoadBalancer`, no `DeleteDistribution`, no unrestricted `TerminateInstances`).

| Permission Area | What They Can Do | What They Cannot Do |
|----------------|-----------------|---------------------|
| EC2 | Start, stop, reboot, create SGs, manage keys, create snapshots/images | Terminate instances unless tagged `Project=group-2`; delete security groups; deregister AMIs |
| ALB | Modify, create target groups, register/deregister targets, manage listeners | Delete the load balancer or target groups |
| S3 | Full access to `group-2-286664220957-us-east-1-an` (read/write/policy/versioning) | Cannot delete the bucket policy |
| CloudFront | Create, update, manage OAC/cache policies, invalidate | Cannot delete distributions |
| ACM | Full certificate lifecycle | Cannot export private key material |
| IAM | Read-only — list users, roles, policies, simulate policies | Cannot create/modify/delete IAM entities |
| CloudWatch / CloudTrail | Full visibility and alarm management | — |
| Route 53 | Read-only visibility | — |
| Billing / Cost Explorer | Read-only | — |

---

### `project-backend-devops` — Loretta

**Policy:** `ProjectEC2ALBPolicy` (managed, customer)

This group handles EC2 provisioning, ALB management, deployments, and operational tasks.

| Permission Area | What She Can Do | What She Cannot Do |
|----------------|----------------|---------------------|
| EC2 | Describe, start/stop/reboot, create SGs, manage keys, get console output | Terminate instances unless tagged `Project=group-2`; delete security groups |
| ALB | Full ALB/target group/listener lifecycle | — |
| S3 | Read/write on `frontend/*`, `uploads/*`, `logs/*` | Cannot modify bucket policy; no access to other prefixes |
| SSM | Start Session Manager sessions on tagged instances; send commands (AWS-RunShellScript) on tagged instances; view command invocations | Send commands to instances not tagged `Project=group-2` |
| IAM | Read EC2 roles and instance profiles | Cannot create or modify IAM entities |
| CloudWatch/Logs | Read-only visibility | — |

---

### `project-frontend` — Akosa, Bright

**Policy:** `ProjectCDNACMPolicy` (managed, customer)

This group manages the CDN layer, TLS certificates, and S3 frontend deployment.

| Permission Area | What They Can Do | What They Cannot Do |
|----------------|-----------------|---------------------|
| CloudFront | Create/update distributions, create invalidations, manage OAC/cache policies | **Cannot delete distributions** |
| ACM | Request, describe, delete, and tag certificates | — |
| S3 | Read/write `frontend/*`; manage bucket policy and website config | Cannot access `uploads/*`, `logs/*`, or other prefixes |
| EC2 / ALB | Describe instances and target health (read-only context) | No write access to EC2 or ALB |

---

## Service Account: `nextjs-cicd-deploy`

Used exclusively by GitHub Actions workflows. Has no group membership; permissions are assigned directly via two policies.

### Attached Policy: `nextjs-cicd-deploy-policy` (v2)

| Action | Resource |
|--------|---------|
| `s3:ListBucket`, `ListBucketMultipartUploads`, `GetBucketLocation` | `group-2-286664220957-us-east-1-an` (bucket) |
| `s3:PutObject`, `GetObject`, `DeleteObject`, `AbortMultipartUpload`, `GetObjectTagging`, `PutObjectTagging`, `ListMultipartUploadParts` | `group-2-286664220957-us-east-1-an/frontend/*` (prefix only) |

### Inline Policy: `nextjs-cicd-deploy-extra`

| Sid | Actions | Resource |
|-----|---------|---------|
| `EC2Describe` | `ec2:DescribeInstances`, `ec2:DescribeInstanceStatus` | `*` |
| `SSMSendCommand` | `ssm:SendCommand` | `AWS-RunShellScript` document + two specific instance ARNs |
| `SSMReadInvocations` | `ssm:GetCommandInvocation`, `ListCommandInvocations`, `DescribeInstanceInformation` | `*` (AWS doesn't issue ARNs for invocation results) |
| `CloudFrontInvalidate` | `cloudfront:CreateInvalidation`, `GetInvalidation`, `ListInvalidations` | `E3MRCL1361H3LW` (specific distribution only) |

The CI/CD account **cannot** create or delete infrastructure — it can only sync S3, run shell commands on the two named instances, and create cache invalidations.

---

## EC2 Instance Role: `group-2-ec2-ssm-role`

| Field | Value |
|-------|-------|
| ARN | `arn:aws:iam::286664220957:role/group-2-ec2-ssm-role` |
| Trust Principal | `ec2.amazonaws.com` |
| Instance Profile | `group-2-ec2-ssm-profile` |

| Policy | Type | Purpose |
|--------|------|---------|
| `AmazonSSMManagedInstanceCore` | AWS Managed | SSM Agent registration, Session Manager, Run Command |
| `S3ReadFrontend` | Inline | `s3:GetObject` + `s3:ListBucket` on `frontend/*` for deployment sync |

---

## Policy-to-Resource Summary

| Policy | Attached To | Key Resources |
|--------|-------------|---------------|
| `ProjectReadAllPolicy` | group `project-architects` | EC2 `*`, ALB `*`, S3 bucket, CloudFront `*`, ACM `*`, IAM read `*` |
| `ProjectEC2ALBPolicy` | group `project-backend-devops` | EC2 `*`, ALB `*`, S3 `frontend/*` + `uploads/*` + `logs/*`, SSM tagged instances |
| `ProjectCDNACMPolicy` | group `project-frontend` | CloudFront `*`, ACM `*`, S3 `frontend/*`, EC2 describe `*` |
| `nextjs-cicd-deploy-policy` | user `nextjs-cicd-deploy` | S3 `frontend/*` |
| `nextjs-cicd-deploy-extra` | user `nextjs-cicd-deploy` | SSM two instances, CloudFront one distribution |
| `AmazonSSMManagedInstanceCore` | role `group-2-ec2-ssm-role` | SSM service endpoints |
| `S3ReadFrontend` | role `group-2-ec2-ssm-role` | S3 `frontend/*` |
