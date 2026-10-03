output "azs" {
  value = data.aws_availability_zones.available.names
}

output "bucket_name" {
  value = module.frontend.s3_frontend_bucket
}

output "cloudfront_domain_name" {
  value = module.frontend.cloudfront_domain_name
}

output "cloudfront_url" {
  value = module.frontend.cloudfront_url
}