# General Variables
variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-west-2"
}

variable "name_prefix" {
  description = "Name prefix for all resources"
  type        = string
  validation {
    condition     = length(var.name_prefix) <= 20
    error_message = "Name prefix must be 20 characters or less."
  }
}

variable "default_tags" {
  description = "Default tags to apply to all resources"
  type        = map(string)
  default     = {}
}

# VPC Variables
variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.20.0/24"]
}

variable "database_subnet_cidrs" {
  description = "CIDR blocks for database subnets"
  type        = list(string)
  default     = ["10.0.100.0/24", "10.0.200.0/24"]
}

variable "enable_nat_gateway" {
  description = "Enable NAT Gateway for private subnets"
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Use a single NAT Gateway for all private subnets"
  type        = bool
  default     = false
}

# Security Variables
variable "allowed_cidr_blocks" {
  description = "List of CIDR blocks allowed to access the ALB"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

# LiteLLM Variables
variable "litellm_port" {
  description = "Port that LiteLLM runs on"
  type        = number
  default     = 4000
}

variable "litellm_master_key" {
  description = "LiteLLM master key for authentication"
  type        = string
  sensitive   = true
}

variable "litellm_salt_key" {
  description = "LiteLLM salt key for encryption/decryption of API keys"
  type        = string
  sensitive   = true
}

variable "container_image" {
  description = "Docker image for LiteLLM"
  type        = string
  default     = "ghcr.io/berriai/litellm:main-stable"
}

# Database Variables
variable "database_name" {
  description = "Name of the database to create"
  type        = string
  default     = "litellm"
}

variable "database_username" {
  description = "Username for the database"
  type        = string
  default     = "litellm"
}

variable "database_password" {
  description = "Password for the database"
  type        = string
  sensitive   = true
}

variable "db_engine_version" {
  description = "PostgreSQL engine version"
  type        = string
  default     = "15.8"
}

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "db_allocated_storage" {
  description = "Initial allocated storage in GB"
  type        = number
  default     = 20
}

variable "db_max_allocated_storage" {
  description = "Maximum allocated storage in GB"
  type        = number
  default     = 100
}

variable "db_storage_encrypted" {
  description = "Enable storage encryption"
  type        = bool
  default     = true
}

variable "db_backup_retention_period" {
  description = "Backup retention period in days"
  type        = number
  default     = 7
}

variable "db_multi_az" {
  description = "Enable Multi-AZ deployment"
  type        = bool
  default     = false
}

variable "db_deletion_protection" {
  description = "Enable deletion protection"
  type        = bool
  default     = false
}

variable "db_skip_final_snapshot" {
  description = "Skip final snapshot when deleting"
  type        = bool
  default     = false
}

# ECS Variables
variable "ecs_cpu" {
  description = "CPU units for the task (256, 512, 1024, etc.)"
  type        = number
  default     = 512
}

variable "ecs_memory" {
  description = "Memory for the task in MB"
  type        = number
  default     = 1024
}

variable "ecs_desired_count" {
  description = "Desired number of tasks"
  type        = number
  default     = 1
}

variable "ecs_min_capacity" {
  description = "Minimum number of tasks for autoscaling"
  type        = number
  default     = 1
}

variable "ecs_max_capacity" {
  description = "Maximum number of tasks for autoscaling"
  type        = number
  default     = 10
}

variable "ecs_enable_autoscaling" {
  description = "Enable autoscaling for the ECS service"
  type        = bool
  default     = true
}

variable "ecs_enable_execute_command" {
  description = "Enable ECS Exec for debugging"
  type        = bool
  default     = false
}

# ALB Variables
variable "health_check_path" {
  description = "Health check path"
  type        = string
  default     = "/health"
}

variable "health_check_interval" {
  description = "Health check interval in seconds"
  type        = number
  default     = 30
}

variable "health_check_timeout" {
  description = "Health check timeout in seconds"
  type        = number
  default     = 5
}

variable "health_check_healthy_threshold" {
  description = "Number of consecutive successful health checks"
  type        = number
  default     = 2
}

variable "health_check_unhealthy_threshold" {
  description = "Number of consecutive failed health checks"
  type        = number
  default     = 3
}

variable "alb_enable_deletion_protection" {
  description = "Enable deletion protection for the ALB"
  type        = bool
  default     = false
}

variable "alb_idle_timeout" {
  description = "Idle timeout for the ALB"
  type        = number
  default     = 60
}

# Additional Variables
variable "environment_variables" {
  description = "Additional environment variables for the container"
  type        = map(string)
  default     = {}
}

variable "additional_ssm_parameters" {
  description = "Additional SSM parameters to create"
  type = map(object({
    value       = string
    type        = string
    description = string
  }))
  default = {}
}

variable "additional_task_policy_arns" {
  description = "List of additional policy ARNs to attach to the task role"
  type        = list(string)
  default     = []
}
