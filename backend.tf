# Terraform Backend Configuration
# This file configures remote state storage for the LiteLLM infrastructure

terraform {
  # Uncomment and configure one of the backend options below

  # Option 1: AWS S3 Backend with DynamoDB locking (Recommended for AWS deployments)
  # backend "s3" {
  #   bucket         = "your-terraform-state-bucket"           # Replace with your S3 bucket name
  #   key            = "litellm-infra/terraform.tfstate"       # State file path in bucket
  #   region         = "us-west-2"                             # AWS region for the bucket
  #   encrypt        = true                                    # Encrypt state file
  #   dynamodb_table = "terraform-lock-table"                 # DynamoDB table for state locking
  # }

  # Option 2: Terraform Cloud (Recommended for teams)
  # cloud {
  #   organization = "your-terraform-cloud-org"               # Your Terraform Cloud organization
  #   workspaces {
  #     name = "litellm-infra"                                # Workspace name
  #   }
  # }

  # Option 3: Multiple workspaces for different environments
  # cloud {
  #   organization = "your-terraform-cloud-org"
  #   workspaces {
  #     tags = ["litellm", "infrastructure"]                  # Use tags to group workspaces
  #   }
  # }
}

# Uncomment the resources below if using S3 backend and you need to create the bucket and table

# # S3 Bucket for Terraform State
# resource "aws_s3_bucket" "terraform_state" {
#   bucket = "your-terraform-state-bucket"                    # Must be globally unique
# 
#   lifecycle {
#     prevent_destroy = true
#   }
# 
#   tags = {
#     Name        = "Terraform State Bucket"
#     Environment = "shared"
#     Purpose     = "terraform-state"
#   }
# }
# 
# # Enable versioning on the S3 bucket
# resource "aws_s3_bucket_versioning" "terraform_state" {
#   bucket = aws_s3_bucket.terraform_state.id
#   versioning_configuration {
#     status = "Enabled"
#   }
# }
# 
# # Enable server-side encryption
# resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
#   bucket = aws_s3_bucket.terraform_state.id
# 
#   rule {
#     apply_server_side_encryption_by_default {
#       sse_algorithm = "AES256"
#     }
#   }
# }
# 
# # Block public access to the bucket
# resource "aws_s3_bucket_public_access_block" "terraform_state" {
#   bucket = aws_s3_bucket.terraform_state.id
# 
#   block_public_acls       = true
#   block_public_policy     = true
#   ignore_public_acls      = true
#   restrict_public_buckets = true
# }
# 
# # DynamoDB table for state locking
# resource "aws_dynamodb_table" "terraform_lock" {
#   name           = "terraform-lock-table"
#   billing_mode   = "PAY_PER_REQUEST"
#   hash_key       = "LockID"
# 
#   attribute {
#     name = "LockID"
#     type = "S"
#   }
# 
#   tags = {
#     Name        = "Terraform Lock Table"
#     Environment = "shared"
#     Purpose     = "terraform-locking"
#   }
# }
