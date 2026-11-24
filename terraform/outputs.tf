output "cloudfront_url" {
  description = "Open this in the browser"
  value       = "https://${aws_cloudfront_distribution.cdn.domain_name}"
}

output "alb_dns_name" {
  value = aws_lb.app.dns_name
}

output "rds_endpoint" {
  value = aws_db_instance.db.endpoint
}

output "db_secret_arn" {
  description = "Secrets Manager secret holding the DB master password"
  value       = aws_db_instance.db.master_user_secret[0].secret_arn
}

output "asg_name" {
  value = aws_autoscaling_group.app.name
}
