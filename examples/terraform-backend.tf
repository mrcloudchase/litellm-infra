# Example Terraform backend configuration for remote state storage
# Uncomment and modify this configuration to use remote state

# terraform {
#   backend "s3" {
#     bucket         = "your-terraform-state-bucket"
#     key            = "litellm/terraform.tfstate"
#     region         = "us-west-2"
#     encrypt        = true
#     dynamodb_table = "terraform-lock-table"
#   }
# }

# Alternative: Use Terraform Cloud
# terraform {
#   cloud {
#     organization = "your-org"
#     workspaces {
#       name = "litellm-infra"
#     }
#   }
# }

# Create the S3 bucket and DynamoDB table for state locking
# resource "aws_s3_bucket" "terraform_state" {
#   bucket = "your-terraform-state-bucket"
# 
#   lifecycle {
#     prevent_destroy = true
#   }
# }
# 
# resource "aws_s3_bucket_versioning" "terraform_state" {
#   bucket = aws_s3_bucket.terraform_state.id
#   versioning_configuration {
#     status = "Enabled"
#   }
# }
# 
# resource "aws_s3_bucket_encryption" "terraform_state" {
#   bucket = aws_s3_bucket.terraform_state.id
# 
#   rule {
#     apply_server_side_encryption_by_default {
#       sse_algorithm = "AES256"
#     }
#   }
# }
# 
# resource "aws_dynamodb_table" "terraform_lock" {
#   name           = "terraform-lock-table"
#   billing_mode   = "PAY_PER_REQUEST"
#   hash_key       = "LockID"
# 
#   attribute {
#     name = "LockID"
#     type = "S"
#   }
# }
