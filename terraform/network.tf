# ---------------------------------------------------------------------------
# VPC, subnets, internet gateway, routing
# Mirrors: group-2-vpc (10.0.0.0/16) with two public subnets across AZs.
# ---------------------------------------------------------------------------

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = "${var.project}-vpc" }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${var.project}-igw" }
}

resource "aws_subnet" "public" {
  count             = length(var.subnet_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.subnet_cidrs[count.index]
  availability_zone = var.azs[count.index]

  # The live subnets have MapPublicIpOnLaunch=false; instances instead get a
  # public IP explicitly (see compute.tf). Kept faithful here.
  map_public_ip_on_launch = false

  tags = { Name = count.index == 0 ? "${var.project}-subnet" : "${var.project}-subnet-${count.index + 1}" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = { Name = "${var.project}-rtb" }
}

resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# ---------------------------------------------------------------------------
# Security groups
# ---------------------------------------------------------------------------

# App + ALB share this SG in the live account (Group-2-SG). Ingress on :80 is
# restricted to the CloudFront managed prefix list + itself.
data "aws_ec2_managed_prefix_list" "cloudfront" {
  name = "com.amazonaws.global.cloudfront.origin-facing"
}

resource "aws_security_group" "app" {
  name        = "${var.project}-SG"
  description = "Allow SSH, HTTP and HTTPS"
  vpc_id      = aws_vpc.main.id

  tags = { Name = "${var.project}-SG" }
}

resource "aws_security_group_rule" "app_http_from_cloudfront" {
  security_group_id = aws_security_group.app.id
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  prefix_list_ids   = [data.aws_ec2_managed_prefix_list.cloudfront.id]
  description       = "HTTP from CloudFront origin-facing ranges"
}

resource "aws_security_group_rule" "app_http_self" {
  security_group_id        = aws_security_group.app.id
  type                     = "ingress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.app.id
  description              = "HTTP from members of this SG (e.g. the ALB)"
}

resource "aws_security_group_rule" "app_egress_all" {
  security_group_id = aws_security_group.app.id
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
}
