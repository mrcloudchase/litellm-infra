# Main Terraform configuration for LiteLLM deployment
terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = var.default_tags
  }
}

# Data sources
data "aws_availability_zones" "available" {
  state = "available"
}

# Generate secrets using random provider
resource "random_string" "litellm_master_key_suffix" {
  length  = 48
  special = false
  upper   = true
  lower   = true
  numeric = true
}

resource "random_bytes" "litellm_salt_key" {
  length = 32
}

resource "random_password" "database_password" {
  length  = 32
  special = true
  upper   = true
  lower   = true
  numeric = true
  override_special = "!#$%&*+-=?^_`{|}~"
}

# Local values
locals {
  availability_zones = slice(data.aws_availability_zones.available.names, 0, 2)
  
  # Format-compliant secrets
  litellm_master_key = "sk-${random_string.litellm_master_key_suffix.result}"
  litellm_salt_key   = base64encode(random_bytes.litellm_salt_key.result)
  
  # Generate database URL with auto-generated password
  database_url = "postgresql://${module.rds.db_instance_username}:${random_password.database_password.result}@${module.rds.db_instance_endpoint}/${module.rds.db_instance_name}"
}

# VPC Module
module "vpc" {
  source = "./modules/vpc"

  name_prefix        = var.name_prefix
  vpc_cidr          = var.vpc_cidr
  availability_zones = local.availability_zones
  
  public_subnet_cidrs   = var.public_subnet_cidrs
  private_subnet_cidrs  = var.private_subnet_cidrs
  database_subnet_cidrs = var.database_subnet_cidrs
  
  enable_nat_gateway = var.enable_nat_gateway
  single_nat_gateway = var.single_nat_gateway
  
  tags = var.default_tags
}

# Security Groups Module
module "security_groups" {
  source = "./modules/security-groups"

  name_prefix       = var.name_prefix
  vpc_id           = module.vpc.vpc_id
  vpc_cidr_block   = module.vpc.vpc_cidr_block
  allowed_cidr_blocks = var.allowed_cidr_blocks
  litellm_port     = var.litellm_port
  
  tags = var.default_tags
}

# RDS Module
module "rds" {
  source = "./modules/rds"

  name_prefix           = var.name_prefix
  vpc_id               = module.vpc.vpc_id
  db_subnet_group_name = module.vpc.database_subnet_group_name
  security_group_ids   = [module.security_groups.rds_security_group_id]
  
  engine_version      = var.db_engine_version
  instance_class      = var.db_instance_class
  allocated_storage   = var.db_allocated_storage
  max_allocated_storage = var.db_max_allocated_storage
  storage_encrypted   = var.db_storage_encrypted
  
  database_name     = var.database_name
  database_username = var.database_username
  database_password = random_password.database_password.result
  
  backup_retention_period = var.db_backup_retention_period
  multi_az               = var.db_multi_az
  deletion_protection    = var.db_deletion_protection
  skip_final_snapshot    = var.db_skip_final_snapshot
  
  tags = var.default_tags
}

# SSM Module
module "ssm" {
  source = "./modules/ssm"

  name_prefix        = var.name_prefix
  litellm_master_key = local.litellm_master_key
  litellm_salt_key   = local.litellm_salt_key
  database_url       = local.database_url
  
  additional_parameters = var.additional_ssm_parameters
  
  tags = var.default_tags
}

# S3 Config Module
module "s3_config" {
  source = "./modules/s3-config"

  name_prefix    = var.name_prefix
  config_content = file("${path.root}/examples/litellm-config.yaml")
  
  tags = var.default_tags
}

# IAM Module
module "iam" {
  source = "./modules/iam"

  name_prefix           = var.name_prefix
  ssm_parameter_arns    = module.ssm.all_parameter_arns
  s3_config_bucket_arn  = module.s3_config.bucket_arn
  additional_task_policy_arns = var.additional_task_policy_arns
  
  tags = var.default_tags
}

# ALB Module
module "alb" {
  source = "./modules/alb"

  name_prefix        = var.name_prefix
  vpc_id            = module.vpc.vpc_id
  subnet_ids        = module.vpc.public_subnet_ids
  security_group_ids = [module.security_groups.alb_security_group_id]
  
  target_port                    = var.litellm_port
  health_check_path             = var.health_check_path
  health_check_interval         = var.health_check_interval
  health_check_timeout          = var.health_check_timeout
  health_check_healthy_threshold = var.health_check_healthy_threshold
  health_check_unhealthy_threshold = var.health_check_unhealthy_threshold
  
  enable_deletion_protection = var.alb_enable_deletion_protection
  idle_timeout              = var.alb_idle_timeout
  
  tags = var.default_tags
}

# ECS Module
module "ecs" {
  source = "./modules/ecs"

  name_prefix           = var.name_prefix
  vpc_id               = module.vpc.vpc_id
  subnet_ids           = module.vpc.private_subnet_ids
  security_group_ids   = [module.security_groups.ecs_tasks_security_group_id]
  target_group_arn     = module.alb.target_group_arn
  
  task_execution_role_arn = module.iam.ecs_task_execution_role_arn
  task_role_arn          = module.iam.ecs_task_role_arn
  
  container_image = var.container_image
  container_port  = var.litellm_port
  cpu            = var.ecs_cpu
  memory         = var.ecs_memory
  desired_count  = var.ecs_desired_count
  
  min_capacity  = var.ecs_min_capacity
  max_capacity  = var.ecs_max_capacity
  enable_autoscaling = var.ecs_enable_autoscaling
  
  environment_variables = merge(var.environment_variables, {
    S3_CONFIG_BUCKET = module.s3_config.bucket_name
    S3_CONFIG_KEY    = module.s3_config.config_key
  })
  
  secrets = concat([
    {
      name      = "LITELLM_MASTER_KEY"
      valueFrom = module.ssm.litellm_master_key_arn
    },
    {
      name      = "LITELLM_SALT_KEY"
      valueFrom = module.ssm.litellm_salt_key_arn
    },
    {
      name      = "DATABASE_URL"
      valueFrom = module.ssm.database_url_arn
    }
  ], [
    for key, arn in module.ssm.additional_parameter_arns : {
      name      = upper(replace(key, "-", "_"))
      valueFrom = arn
    }
  ])
  
  config_etag = module.s3_config.config_etag
  
  enable_execute_command = var.ecs_enable_execute_command
  
  tags = var.default_tags
}
