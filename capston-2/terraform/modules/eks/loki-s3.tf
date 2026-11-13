locals {
  loki_bucket_names = {
    chunks = "${lower(var.cluster_name)}-loki-chunks-${data.aws_caller_identity.current.account_id}"
    ruler  = "${lower(var.cluster_name)}-loki-ruler-${data.aws_caller_identity.current.account_id}"
  }

  loki_service_account = "system:serviceaccount:monitoring:loki"
}

resource "aws_s3_bucket" "loki" {
  for_each = local.loki_bucket_names

  bucket        = each.value
  force_destroy = false

  tags = {
    Name      = each.value
    ManagedBy = "Terraform"
    Purpose   = "Loki ${each.key} storage"
  }
}

resource "aws_s3_bucket_public_access_block" "loki" {
  for_each = aws_s3_bucket.loki

  bucket = each.value.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "loki" {
  for_each = aws_s3_bucket.loki

  bucket = each.value.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_iam_role" "loki" {
  name = "${var.cluster_name}-loki-s3-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = aws_iam_openid_connect_provider.cluster.arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${replace(aws_eks_cluster.this.identity[0].oidc[0].issuer, "https://", "")}:aud" = "sts.amazonaws.com"
          "${replace(aws_eks_cluster.this.identity[0].oidc[0].issuer, "https://", "")}:sub" = local.loki_service_account
        }
      }
    }]
  })

  tags = {
    Name      = "${var.cluster_name}-loki-s3-role"
    ManagedBy = "Terraform"
  }
}

resource "aws_iam_role_policy" "loki_s3" {
  name = "${var.cluster_name}-loki-s3-policy"
  role = aws_iam_role.loki.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.loki["chunks"].arn,
          aws_s3_bucket.loki["ruler"].arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = [
          "${aws_s3_bucket.loki["chunks"].arn}/*",
          "${aws_s3_bucket.loki["ruler"].arn}/*"
        ]
      }
    ]
  })
}
