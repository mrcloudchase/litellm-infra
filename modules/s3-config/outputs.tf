output "bucket_name" {
  description = "Name of the S3 bucket"
  value       = aws_s3_bucket.config.id
}

output "bucket_arn" {
  description = "ARN of the S3 bucket"
  value       = aws_s3_bucket.config.arn
}

output "config_key" {
  description = "S3 key of the configuration file"
  value       = aws_s3_object.litellm_config.key
}

output "config_version_id" {
  description = "Version ID of the configuration file"
  value       = aws_s3_object.litellm_config.version_id
}

output "config_etag" {
  description = "ETag of the configuration file"
  value       = aws_s3_object.litellm_config.etag
}
