output "s3_frontend_bucket" {
  value = aws_s3_bucket.frontend.bucket
}


output "cloudfront_domain_name" {
  value = aws_cloudfront_distribution.frontend.domain_name
}

output "cloudfront_url" {
  value = "https://${aws_cloudfront_distribution.frontend.domain_name}"
}