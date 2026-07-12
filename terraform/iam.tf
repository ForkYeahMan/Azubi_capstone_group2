# ---------------------------------------------------------------------------
# EC2 instance role/profile: SSM managed access + read of the frontend bucket.
# Mirrors: group-2-ec2-ssm-role / group-2-ec2-ssm-profile
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "ec2_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ec2_ssm" {
  name               = "${var.project}-ec2-ssm-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.ec2_ssm.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

data "aws_iam_policy_document" "s3_read_frontend" {
  statement {
    sid     = "S3ReadFrontendPrefix"
    effect  = "Allow"
    actions = ["s3:GetObject", "s3:ListBucket"]
    resources = [
      aws_s3_bucket.frontend.arn,
      "${aws_s3_bucket.frontend.arn}/frontend/*",
    ]
  }
}

resource "aws_iam_role_policy" "s3_read_frontend" {
  name   = "S3ReadFrontend"
  role   = aws_iam_role.ec2_ssm.id
  policy = data.aws_iam_policy_document.s3_read_frontend.json
}

resource "aws_iam_instance_profile" "ec2_ssm" {
  name = "${var.project}-ec2-ssm-profile"
  role = aws_iam_role.ec2_ssm.name
}
