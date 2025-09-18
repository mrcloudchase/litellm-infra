variable "name_prefix" {
  description = "Name prefix for all resources"
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC"
  type        = string
}

variable "vpc_cidr_block" {
  description = "CIDR block of the VPC"
  type        = string
}

variable "allowed_cidr_blocks" {
  description = "List of CIDR blocks allowed to access the ALB"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "litellm_port" {
  description = "Port that LiteLLM runs on"
  type        = number
  default     = 4000
}

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}
