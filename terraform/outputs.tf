output "vpc_id" {
  value = aws_vpc.main.id
}

output "instance_ids" {
  value = aws_instance.app[*].id
}

output "instance_public_ips" {
  value = aws_instance.app[*].public_ip
}

output "alb_dns_name" {
  description = "Point CloudFront (or your DNS) at this."
  value       = aws_lb.app.dns_name
}

output "cloudfront_domain" {
  value = var.enable_cloudfront ? aws_cloudfront_distribution.cdn[0].domain_name : null
}

output "frontend_bucket" {
  value = aws_s3_bucket.frontend.bucket
}

output "database_endpoint" {
  value = var.enable_database ? aws_rds_cluster.aurora[0].endpoint : null
}

output "acm_validation_records" {
  description = "If Terraform created a new cert, add these CNAMEs at your DNS registrar to validate it."
  value = var.existing_certificate_arn == null ? [
    for o in aws_acm_certificate.cert[0].domain_validation_options : {
      name  = o.resource_record_name
      type  = o.resource_record_type
      value = o.resource_record_value
    }
  ] : []
}
