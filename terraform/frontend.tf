# ---------------------------------------------------------------------------
# Frontend: S3 bucket (Next.js static export under /frontend) + CloudFront +
# ACM certificate.
# Mirrors: group-2-286664220957-us-east-1-an, distribution E3MRCL1361H3LW
# ---------------------------------------------------------------------------

data "aws_caller_identity" "current" {}

resource "aws_s3_bucket" "frontend" {
  bucket = "${var.project}-${data.aws_caller_identity.current.account_id}-${var.region}-an"
}

resource "aws_s3_bucket_public_access_block" "frontend" {
  bucket                  = aws_s3_bucket.frontend.id
  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy      = false
  restrict_public_buckets = false
}

# ---- TLS certificate -------------------------------------------------------
# The domain's DNS is NOT in Route 53, so a brand-new cert must be DNS-validated
# by hand at the registrar. By default we reuse the already-issued cert
# (var.existing_certificate_arn). Set that to null to have TF create a new one.
resource "aws_acm_certificate" "cert" {
  count             = var.existing_certificate_arn == null ? 1 : 0
  domain_name       = var.domain_name
  subject_alternative_names = var.subject_alternative_names
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

locals {
  certificate_arn = coalesce(
    var.existing_certificate_arn,
    try(aws_acm_certificate.cert[0].arn, null),
  )
}

# ---- CloudFront ------------------------------------------------------------
resource "aws_cloudfront_origin_access_control" "s3" {
  count                             = var.enable_cloudfront ? 1 : 0
  name                              = "${var.project}-s3-oac"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "cdn" {
  count           = var.enable_cloudfront ? 1 : 0
  enabled         = true
  aliases         = concat([var.domain_name], var.subject_alternative_names)
  price_class     = "PriceClass_100"
  default_root_object = "index.html"

  # S3 frontend origin (static assets, served from /frontend prefix)
  origin {
    origin_id                = "${var.project}-s3-frontend"
    domain_name              = aws_s3_bucket.frontend.bucket_regional_domain_name
    origin_path              = "/frontend"
    origin_access_control_id = aws_cloudfront_origin_access_control.s3[0].id
  }

  # ALB origin (the dynamic app)
  origin {
    origin_id   = "alb-${var.project}"
    domain_name = aws_lb.app.dns_name

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  # Default -> ALB
  default_cache_behavior {
    target_origin_id       = "alb-${var.project}"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    # Managed-CachingOptimized
    cache_policy_id = "658327ea-f89d-4fab-a63d-7e88639e58f6"
  }

  # _next/static/* -> S3
  ordered_cache_behavior {
    path_pattern           = "_next/static/*"
    target_origin_id       = "${var.project}-s3-frontend"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    cache_policy_id        = "658327ea-f89d-4fab-a63d-7e88639e58f6"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = local.certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }
}

# ---- Bucket policy ---------------------------------------------------------
# Allows: CloudFront OAC read, the EC2 role read, ALB access-log writes; denies
# unencrypted uploads. Mirrors the live bucket policy.
data "aws_elb_service_account" "main" {}

data "aws_iam_policy_document" "frontend_bucket" {
  dynamic "statement" {
    for_each = var.enable_cloudfront ? [1] : []
    content {
      sid     = "AllowCloudFrontOAC"
      effect  = "Allow"
      actions = ["s3:GetObject"]
      resources = ["${aws_s3_bucket.frontend.arn}/frontend/*"]
      principals {
        type        = "Service"
        identifiers = ["cloudfront.amazonaws.com"]
      }
      condition {
        test     = "StringEquals"
        variable = "AWS:SourceArn"
        values   = [aws_cloudfront_distribution.cdn[0].arn]
      }
    }
  }

  statement {
    sid    = "AllowEC2RoleSync"
    effect = "Allow"
    actions = ["s3:GetObject", "s3:ListBucket"]
    resources = [
      aws_s3_bucket.frontend.arn,
      "${aws_s3_bucket.frontend.arn}/frontend/*",
    ]
    principals {
      type        = "AWS"
      identifiers = [aws_iam_role.ec2_ssm.arn]
    }
  }

  statement {
    sid       = "AllowALBLogs"
    effect    = "Allow"
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.frontend.arn}/logs/alb/*"]
    principals {
      type        = "AWS"
      identifiers = [data.aws_elb_service_account.main.arn]
    }
  }

  statement {
    sid       = "DenyUnencryptedUploads"
    effect    = "Deny"
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.frontend.arn}/*"]
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    condition {
      test     = "Null"
      variable = "s3:x-amz-server-side-encryption"
      values   = ["false"]
    }
    condition {
      test     = "StringNotEquals"
      variable = "s3:x-amz-server-side-encryption"
      values   = ["AES256"]
    }
  }
}

resource "aws_s3_bucket_policy" "frontend" {
  bucket = aws_s3_bucket.frontend.id
  policy = data.aws_iam_policy_document.frontend_bucket.json

  depends_on = [aws_s3_bucket_public_access_block.frontend]
}
