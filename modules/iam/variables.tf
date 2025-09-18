variable "name_prefix" {
  description = "Name prefix for all resources"
  type        = string
}

variable "ssm_parameter_arns" {
  description = "List of SSM parameter ARNs that ECS tasks need access to"
  type        = list(string)
  default     = []
}

variable "s3_config_bucket_arn" {
  description = "ARN of the S3 bucket containing LiteLLM configuration"
  type        = string
  default     = ""
}

variable "additional_task_policy_arns" {
  description = "List of additional policy ARNs to attach to the task role"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}
