data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# AWS account that writes ALB logs in this region
data "aws_elb_service_account" "this" {}

locals {
  account_id  = data.aws_caller_identity.current.account_id
  app_bucket  = "${var.name_prefix}-app-${local.account_id}"
  logs_bucket = "${var.name_prefix}-alb-logs-${local.account_id}"
  logs_prefix = "alb"
}

# ================= App bucket =================
resource "aws_s3_bucket" "app" {
  bucket        = local.app_bucket
  force_destroy = var.force_destroy
  tags          = merge(var.tags, { Name = local.app_bucket })
}

resource "aws_s3_bucket_versioning" "app" {
  bucket = aws_s3_bucket.app.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "app" {
  bucket = aws_s3_bucket.app.id
  rule {
    apply_server_side_encryption_by_default { sse_algorithm = "aws:kms" }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "app" {
  bucket                  = aws_s3_bucket.app.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

data "aws_iam_policy_document" "app_tls" {
  statement {
    sid       = "DenyInsecureTransport"
    effect    = "Deny"
    actions   = ["s3:*"]
    resources = [aws_s3_bucket.app.arn, "${aws_s3_bucket.app.arn}/*"]
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "app" {
  bucket     = aws_s3_bucket.app.id
  policy     = data.aws_iam_policy_document.app_tls.json
  depends_on = [aws_s3_bucket_public_access_block.app]
}

# ================= ALB logs bucket =================
resource "aws_s3_bucket" "logs" {
  bucket        = local.logs_bucket
  force_destroy = var.force_destroy
  tags          = merge(var.tags, { Name = local.logs_bucket })
}

# ALB access logs only support SSE-S3 (AES256), not KMS
resource "aws_s3_bucket_server_side_encryption_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id
  rule {
    apply_server_side_encryption_by_default { sse_algorithm = "AES256" }
  }
}

resource "aws_s3_bucket_public_access_block" "logs" {
  bucket                  = aws_s3_bucket.logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id
  rule {
    id     = "expire-logs"
    status = "Enabled"
    filter {}
    expiration { days = var.log_retention_days }
  }
}

data "aws_iam_policy_document" "logs" {
  statement {
    sid       = "AllowALBLogDelivery"
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.logs.arn}/${local.logs_prefix}/AWSLogs/${local.account_id}/*"]
    principals {
      type        = "AWS"
      identifiers = [data.aws_elb_service_account.this.arn]
    }
  }

  statement {
    sid       = "DenyInsecureTransport"
    effect    = "Deny"
    actions   = ["s3:*"]
    resources = [aws_s3_bucket.logs.arn, "${aws_s3_bucket.logs.arn}/*"]
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "logs" {
  bucket     = aws_s3_bucket.logs.id
  policy     = data.aws_iam_policy_document.logs.json
  depends_on = [aws_s3_bucket_public_access_block.logs]
}
