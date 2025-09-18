variable "name_prefix" {
  description = "Name prefix for all resources"
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for ECS tasks"
  type        = list(string)
}

variable "security_group_ids" {
  description = "List of security group IDs for ECS tasks"
  type        = list(string)
}

variable "target_group_arn" {
  description = "ARN of the target group"
  type        = string
}

variable "task_execution_role_arn" {
  description = "ARN of the ECS task execution role"
  type        = string
}

variable "task_role_arn" {
  description = "ARN of the ECS task role"
  type        = string
}

variable "container_image" {
  description = "Docker image for LiteLLM"
  type        = string
  default     = "ghcr.io/berriai/litellm:main-stable"
}

variable "container_port" {
  description = "Port that the container exposes"
  type        = number
  default     = 4000
}

variable "cpu" {
  description = "CPU units for the task (256, 512, 1024, etc.)"
  type        = number
  default     = 512
}

variable "memory" {
  description = "Memory for the task in MB"
  type        = number
  default     = 1024
}

variable "desired_count" {
  description = "Desired number of tasks"
  type        = number
  default     = 1
}

variable "min_capacity" {
  description = "Minimum number of tasks for autoscaling"
  type        = number
  default     = 1
}

variable "max_capacity" {
  description = "Maximum number of tasks for autoscaling"
  type        = number
  default     = 10
}

variable "enable_autoscaling" {
  description = "Enable autoscaling for the ECS service"
  type        = bool
  default     = true
}

variable "scale_up_cpu_threshold" {
  description = "CPU threshold for scaling up"
  type        = number
  default     = 70
}

variable "scale_down_cpu_threshold" {
  description = "CPU threshold for scaling down"
  type        = number
  default     = 20
}

variable "scale_up_memory_threshold" {
  description = "Memory threshold for scaling up"
  type        = number
  default     = 80
}

variable "scale_down_memory_threshold" {
  description = "Memory threshold for scaling down"
  type        = number
  default     = 30
}

variable "environment_variables" {
  description = "Environment variables for the container"
  type        = map(string)
  default     = {}
}

variable "secrets" {
  description = "Secrets for the container (from SSM Parameter Store)"
  type = list(object({
    name      = string
    valueFrom = string
  }))
  default = []
}

variable "litellm_config_content" {
  description = "Content of the LiteLLM config.yaml file"
  type        = string
  default     = ""
}

variable "enable_execute_command" {
  description = "Enable ECS Exec for debugging"
  type        = bool
  default     = false
}

variable "health_check_grace_period_seconds" {
  description = "Health check grace period for the ECS service"
  type        = number
  default     = 60
}

variable "deployment_minimum_healthy_percent" {
  description = "Minimum healthy percent during deployment"
  type        = number
  default     = 50
}

variable "deployment_maximum_percent" {
  description = "Maximum percent during deployment"
  type        = number
  default     = 200
}

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}
