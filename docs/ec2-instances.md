# EC2 Instances

Two instances run the Apache web server and serve the static Next.js export. They are manually registered in the ALB target group and also managed by the Auto Scaling Group.

---

## Instance Summary

| Field | group-2-1 | group-2-2 |
|-------|-----------|-----------|
| Instance ID | `i-0bb2773ea9a6be95b` | `i-0213095b44ff10b77` |
| State | Running | Running |
| AMI | `ami-0152204c1a187337c` (Amazon Linux 2023) | same |
| Type | `t3.small` (2 vCPU, 2 GB RAM) | same |
| Availability Zone | `us-east-1a` | `us-east-1b` |
| Subnet | `subnet-07424cf01d4ab25fb` (10.0.1.0/24) | `subnet-09a9816aff07475ff` (10.0.2.0/24) |
| Private IP | `10.0.1.35` | `10.0.2.218` |
| Public IP | `44.204.199.164` | `52.91.1.129` |
| Security Group | `sg-0ae5aec8d1bc6cb09` (Group-2-SG) | same |
| Key Pair | `group2` | `group2` |
| IAM Instance Profile | `group-2-ec2-ssm-profile` | same |
| ALB Target Health | Healthy | Healthy |
| SSM Status | Online (Agent 3.3.4515.0) | Online |

---

## IAM Instance Profile

Both instances use the profile `group-2-ec2-ssm-profile` backed by the role `group-2-ec2-ssm-role`.

### Attached Managed Policy

| Policy | Purpose |
|--------|---------|
| `AmazonSSMManagedInstanceCore` | Allows SSM Agent to register with Systems Manager, receive commands via `SendCommand`, and support Session Manager access without SSH |

### Inline Policy: `S3ReadFrontend`

```json
{
  "Statement": [{
    "Sid": "S3ReadFrontendPrefix",
    "Effect": "Allow",
    "Action": ["s3:GetObject", "s3:ListBucket"],
    "Resource": [
      "arn:aws:s3:::group-2-286664220957-us-east-1-an",
      "arn:aws:s3:::group-2-286664220957-us-east-1-an/frontend/*"
    ]
  }]
}
```

This allows the instance to run `aws s3 sync s3://group-2-286664220957-us-east-1-an/frontend/ /var/www/html/` during CI/CD deployments triggered via SSM.

---

## Web Server Configuration

- **Software:** Apache HTTPD 2.4.67 (Amazon Linux)
- **Document root:** `/var/www/html/`
- **DirectoryIndex:** `index.html`
- **Content:** Full static Next.js export synced from S3 on every deployment

Apache serves the files directly with no PHP, no Node.js, no proxy. The Next.js app is pre-rendered at build time to plain HTML/CSS/JS.

---

## Instance Access

SSH access to these instances is **disabled** (port 22 removed from the security group). Access is via AWS Systems Manager:

```bash
# Open an interactive shell
aws ssm start-session --target i-0bb2773ea9a6be95b

# Run a command remotely (used by CI/CD)
aws ssm send-command \
  --document-name AWS-RunShellScript \
  --instance-ids i-0bb2773ea9a6be95b i-0213095b44ff10b77 \
  --parameters 'commands=["ls /var/www/html/"]'
```

---

## Launch Template

The Auto Scaling Group uses launch template `Group-2-Templates` (`lt-0553607b55dd9c189`) to provision new instances:

| Field | Value |
|-------|-------|
| Template ID | `lt-0553607b55dd9c189` |
| Name | `Group-2-Templates` |
| Version | 2 (default) |
| AMI | `ami-0152204c1a187337c` |
| Instance Type | `t3.small` |
| Key Pair | `group2` |

New instances spun up by the ASG inherit the same AMI and configuration as the two existing instances.
