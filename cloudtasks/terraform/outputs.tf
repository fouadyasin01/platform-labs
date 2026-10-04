
output "bucket_name" {
  value = module.frontend.s3_frontend_bucket
}

output "cloudfront_domain_name" {
  value = module.frontend.cloudfront_domain_name
}

output "cloudfront_url" {
  value = module.frontend.cloudfront_url
}

output "alarm_names" {
  description = "Names of the CloudWatch alarms."
  value       = module.monitoring.alarm_names
}