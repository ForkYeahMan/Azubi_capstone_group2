# Group-2 infrastructure (Terraform)

Reproduces the AWS stack for this project in `us-east-1` (account `286664220957`)
so you can tear it down to save money and bring it back later.

## What it manages

| Layer     | Resources |
|-----------|-----------|
| Network   | VPC `10.0.0.0/16`, 2 public subnets (us-east-1a/1b), IGW, route table, `group-2-SG` |
| Compute   | 2× fixed `t3.small` EC2 (Amazon Linux 2023) **+ an Auto Scaling Group** (`Group-2-Templates` launch template, min 1 / max 4 / desired 1), instance profile with SSM + S3 read |
| Ingress   | Application Load Balancer, HTTP:80 + HTTPS:443 listeners, `group-2-tg-http` |
| Frontend  | S3 bucket, CloudFront distribution (S3 `/frontend` + ALB origins), ACM cert |
| Database  | Aurora PostgreSQL 17.7 Serverless v2 (0–4 ACU, scale-to-zero) |

## Prerequisites

- Terraform >= 1.5, AWS CLI configured with the `personal` profile.
- The EC2 key pair `group2` still exists in the account (instances reference it by
  name; Terraform does **not** manage it so your private key is untouched).

## Usage

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars   # edit as needed
terraform init
terraform plan
terraform apply      # spin UP
terraform destroy    # spin DOWN
```

Faster iteration (skip the ~15–20 min CloudFront + the database):

```bash
terraform apply -var enable_cloudfront=false -var enable_database=false
```

## ⚠️ Read before you rely on this

1. **The hand-built stack was fully destroyed on 2026-07-12**, so a fresh
   `terraform apply` now creates everything cleanly with no name collisions —
   this is the intended path. (If you ever need to adopt live resources instead
   of recreating them, `terraform import` commands are at the bottom of this file.)

2. **EC2 instances come up bare.** The AMI is stock Amazon Linux 2023 — none of
   your app is baked in. After `apply`, redeploy via your GitHub Actions pipeline
   / SSM, or add a `user_data` bootstrap in `compute.tf`.

3. **Destroying the database deletes its data.** With `min_capacity = 0` Aurora
   Serverless v2 already auto-pauses when idle (near-zero cost), so you normally
   do **not** need to destroy it. If you do, leave `db_skip_final_snapshot = false`
   to keep a restorable snapshot.

4. **The domain's DNS lives outside AWS** (no Route 53 zone). By default the config
   reuses the already-issued ACM cert (`existing_certificate_arn`). If you set that
   to `null`, Terraform creates a new cert and prints CNAME records
   (`acm_validation_records` output) that you must add at your registrar before
   CloudFront can finish.

## Importing the existing resources (adoption path)

Run after `terraform init`. IDs are the live ones at time of writing — re-check
with the AWS console/CLI if they've changed.

```bash
terraform import aws_vpc.main vpc-0d296b2612e167872
terraform import aws_s3_bucket.frontend group-2-286664220957-us-east-1-an
terraform import aws_iam_role.ec2_ssm group-2-ec2-ssm-role
terraform import aws_iam_instance_profile.ec2_ssm group-2-ec2-ssm-profile
terraform import aws_lb.app arn:aws:elasticloadbalancing:us-east-1:286664220957:loadbalancer/app/group-2-alb/4d3c213ef930c0aa
terraform import 'aws_instance.app[0]' i-0bb2773ea9a6be95b
terraform import 'aws_instance.app[1]' i-0213095b44ff10b77
terraform import 'aws_instance.app[2]' i-0ca04a4c495654234
terraform import 'aws_rds_cluster.aurora[0]' database-1
terraform import 'aws_rds_cluster_instance.aurora[0]' database-1-instance-1
terraform import 'aws_cloudfront_distribution.cdn[0]' E3MRCL1361H3LW
# ...then `terraform plan` and reconcile any diffs before applying.
```
