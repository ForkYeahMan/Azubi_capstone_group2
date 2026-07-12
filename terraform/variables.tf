variable "region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "us-east-1"
}

variable "aws_profile" {
  description = "Local AWS CLI/credentials profile to use."
  type        = string
  default     = "personal"
}

variable "project" {
  description = "Name prefix applied to all resources."
  type        = string
  default     = "group-2"
}

variable "vpc_cidr" {
  description = "CIDR for the project VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "subnet_cidrs" {
  description = "CIDRs for the two public subnets (one per AZ)."
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "azs" {
  description = "Availability zones for the subnets (must match subnet_cidrs length)."
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "instance_type" {
  description = "EC2 instance type for the backend nodes."
  type        = string
  default     = "t3.small"
}

variable "instance_count" {
  description = "How many backend EC2 instances to run (all are registered to the ALB target group)."
  type        = number
  default     = 3
}

variable "key_name" {
  description = "Name of an EXISTING EC2 key pair to attach to instances. Leave as-is to reuse the current 'group2' key. Set to null for no SSH key."
  type        = string
  default     = "group2"
}

variable "ami_id" {
  description = "Override the AMI. Leave null to auto-select the latest Amazon Linux 2023 x86_64 AMI."
  type        = string
  default     = null
}

# ---- Domain / TLS ----------------------------------------------------------
variable "domain_name" {
  description = "Primary domain served by CloudFront."
  type        = string
  default     = "solarpanel.lol"
}

variable "subject_alternative_names" {
  description = "Extra names on the CloudFront cert (e.g. www)."
  type        = list(string)
  default     = ["www.solarpanel.lol"]
}

variable "existing_certificate_arn" {
  description = "Reuse an already-issued ACM cert (in us-east-1) instead of creating + DNS-validating a new one. Recommended, since the domain's DNS is managed outside AWS. Set to null to have Terraform create a new cert you must validate manually."
  type        = string
  default     = "arn:aws:acm:us-east-1:286664220957:certificate/3f82af42-4019-4f87-a67d-cceca2b9b4bb"
}

variable "enable_cloudfront" {
  description = "Whether to create the CloudFront distribution. It takes ~15-20 min to create/destroy; set false for faster iteration."
  type        = bool
  default     = true
}

# ---- Database --------------------------------------------------------------
variable "enable_database" {
  description = "Whether to manage the Aurora PostgreSQL Serverless v2 cluster. NOTE: destroying it deletes all data unless a final snapshot is taken."
  type        = bool
  default     = true
}

variable "db_master_username" {
  description = "Aurora master username."
  type        = string
  default     = "postgres"
}

variable "db_master_password" {
  description = "Aurora master password. Provide via TF_VAR_db_master_password or terraform.tfvars (do NOT commit)."
  type        = string
  default     = null
  sensitive   = true
}

variable "db_min_capacity" {
  description = "Aurora Serverless v2 minimum ACU (0 = scale to zero / auto-pause)."
  type        = number
  default     = 0
}

variable "db_max_capacity" {
  description = "Aurora Serverless v2 maximum ACU."
  type        = number
  default     = 4
}

variable "db_skip_final_snapshot" {
  description = "Skip the final snapshot on destroy. true = faster teardown but permanent data loss."
  type        = bool
  default     = false
}
