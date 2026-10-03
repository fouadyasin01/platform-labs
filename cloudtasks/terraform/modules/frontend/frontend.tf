


# ============================================================
# FRONTEND HOSTING & CDN
# ============================================================





data "aws_caller_identity" "current" {}

locals {
  common_tags = {
    Project     = "cloudtasks"
    Environment = "dev"
    ManagedBy   = "terraform"
  }

  frontend_files = fileset(
    var.frontend_dist_path,
    "**"
  )
}


resource "aws_s3_bucket" "frontend" {
  bucket = "cloudtasks-frontend-${data.aws_caller_identity.current.account_id}"

  tags = merge(local.common_tags, {
    Name = "cloudtasks-frontend"
  })
}

resource "aws_s3_bucket_public_access_block" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}


resource "aws_s3_object" "frontend" {
  for_each = local.frontend_files

  bucket = aws_s3_bucket.frontend.id

  key    = each.value
  source = "${var.frontend_dist_path}/${each.value}"

  etag = filemd5(
    "${var.frontend_dist_path}/${each.value}"
  )

  content_type = lookup(
    {
      html = "text/html"
      css  = "text/css"
      js   = "application/javascript"
      svg  = "image/svg+xml"
      json = "application/json"
    },
    try(regex("\\.([^.]+)$", each.value)[0], ""),
    "application/octet-stream"
  )
}

# ============================================================
# CLOUDFRONT
# ============================================================

resource "aws_cloudfront_origin_access_control" "frontend" {
  name                              = "cloudtasks-frontend-oac"
  description                       = "OAC for CloudTasks frontend S3 bucket"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "frontend" {
  enabled             = true
  default_root_object = "index.html"

  # Frontend: S3
  origin {
    domain_name = aws_s3_bucket.frontend.bucket_regional_domain_name
    origin_id   = "cloudtasks-frontend-s3"

    origin_access_control_id = aws_cloudfront_origin_access_control.frontend.id
  }

  # Backend API: ALB
  origin {
    domain_name = var.lb_dns_name
    origin_id   = "cloudtasks-alb"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"

      origin_ssl_protocols = [
        "TLSv1.2"
      ]
    }
  }

  # API requests -> ALB
  ordered_cache_behavior {
    path_pattern     = "/api/*"
    target_origin_id = "cloudtasks-alb"

    viewer_protocol_policy = "redirect-to-https"

    allowed_methods = [
      "DELETE",
      "GET",
      "HEAD",
      "OPTIONS",
      "PATCH",
      "POST",
      "PUT"
    ]

    cached_methods = [
      "GET",
      "HEAD"
    ]

    forwarded_values {
      query_string = true

      headers = [
        "Host"
      ]

      cookies {
        forward = "all"
      }
    }
  }

  # Everything else -> S3
  default_cache_behavior {
    target_origin_id       = "cloudtasks-frontend-s3"
    viewer_protocol_policy = "redirect-to-https"

    allowed_methods = [
      "GET",
      "HEAD",
      "OPTIONS"
    ]

    cached_methods = [
      "GET",
      "HEAD",
      "OPTIONS"
    ]

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = merge(local.common_tags, {
    Name = "cloudtasks-frontend-cdn"
  })
}

# ============================================================
# S3 BUCKET POLICY
# ============================================================

resource "aws_s3_bucket_policy" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Sid    = "AllowCloudFrontRead"
        Effect = "Allow"

        Principal = {
          Service = "cloudfront.amazonaws.com"
        }

        Action = "s3:GetObject"

        Resource = "${aws_s3_bucket.frontend.arn}/*"

        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.frontend.arn
          }
        }
      }
    ]
  })

  depends_on = [
    aws_s3_bucket_public_access_block.frontend
  ]
}