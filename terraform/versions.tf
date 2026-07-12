terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.60"
    }
  }

  # Optional: uncomment to keep state in S3 instead of a local file.
  # backend "s3" {
  #   bucket = "group-2-286664220957-us-east-1-an"
  #   key    = "terraform/state.tfstate"
  #   region = "us-east-1"
  # }
}

provider "aws" {
  region  = var.region
  profile = var.aws_profile

  default_tags {
    tags = {
      Project   = "group-2"
      ManagedBy = "terraform"
    }
  }
}
