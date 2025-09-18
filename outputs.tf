# VPC Outputs
output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "List of IDs of the public subnets"
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "List of IDs of the private subnets"
  value       = module.vpc.private_subnet_ids
}

# Database Outputs
output "database_endpoint" {
  description = "RDS instance endpoint"
  value       = module.rds.db_instance_endpoint
}

output "database_port" {
  description = "RDS instance port"
  value       = module.rds.db_instance_port
}

# Load Balancer Outputs
output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = module.alb.alb_dns_name
}

output "alb_url" {
  description = "URL of the Application Load Balancer"
  value       = module.alb.alb_url
}

output "alb_zone_id" {
  description = "Zone ID of the Application Load Balancer"
  value       = module.alb.alb_zone_id
}

# ECS Outputs
output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = module.ecs.cluster_name
}

output "ecs_service_name" {
  description = "Name of the ECS service"
  value       = module.ecs.service_name
}

output "ecs_log_group_name" {
  description = "Name of the ECS CloudWatch log group"
  value       = module.ecs.log_group_name
}

# Security Group Outputs
output "alb_security_group_id" {
  description = "ID of the ALB security group"
  value       = module.security_groups.alb_security_group_id
}

output "ecs_security_group_id" {
  description = "ID of the ECS tasks security group"
  value       = module.security_groups.ecs_tasks_security_group_id
}

output "rds_security_group_id" {
  description = "ID of the RDS security group"
  value       = module.security_groups.rds_security_group_id
}

# SSM Outputs
output "ssm_parameter_names" {
  description = "Names of the SSM parameters"
  value = {
    master_key   = module.ssm.litellm_master_key_name
    salt_key     = module.ssm.litellm_salt_key_name
    database_url = module.ssm.database_url_name
  }
}

# IAM Outputs
output "ecs_task_role_arn" {
  description = "ARN of the ECS task role"
  value       = module.iam.ecs_task_role_arn
}

output "ecs_task_execution_role_arn" {
  description = "ARN of the ECS task execution role"
  value       = module.iam.ecs_task_execution_role_arn
}

# Generated Secrets Outputs
output "litellm_master_key" {
  description = "Auto-generated LiteLLM master key"
  value       = local.litellm_master_key
  sensitive   = true
}

output "secret_retrieval_commands" {
  description = "Commands to retrieve secrets from SSM"
  value = {
    master_key = "aws ssm get-parameter --name '${module.ssm.litellm_master_key_name}' --with-decryption --query 'Parameter.Value' --output text"
    salt_key   = "aws ssm get-parameter --name '${module.ssm.litellm_salt_key_name}' --with-decryption --query 'Parameter.Value' --output text"
    db_url     = "aws ssm get-parameter --name '${module.ssm.database_url_name}' --with-decryption --query 'Parameter.Value' --output text"
  }
}
