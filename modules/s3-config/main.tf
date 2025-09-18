# S3 Bucket for LiteLLM configuration
resource "aws_s3_bucket" "config" {
  bucket = "${var.name_prefix}-litellm-config"

  tags = merge(var.tags, {
    Name    = "${var.name_prefix}-litellm-config"
    Purpose = "litellm-configuration"
  })
}

# Enable versioning for config file history
resource "aws_s3_bucket_versioning" "config" {
  bucket = aws_s3_bucket.config.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Enable server-side encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "config" {
  bucket = aws_s3_bucket.config.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block public access to the bucket
resource "aws_s3_bucket_public_access_block" "config" {
  bucket = aws_s3_bucket.config.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Upload LiteLLM configuration file
resource "aws_s3_object" "litellm_config" {
  bucket  = aws_s3_bucket.config.id
  key     = "litellm-config.yaml"
  content = var.config_content
  etag    = md5(var.config_content)

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-litellm-config"
  })
}
