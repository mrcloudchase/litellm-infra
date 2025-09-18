variable "name_prefix" {
  description = "Name prefix for all resources"
  type        = string
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

variable "database_url" {
  description = "Database connection URL"
  type        = string
  sensitive   = true
}

variable "additional_parameters" {
  description = "Additional SSM parameters to create"
  type = map(object({
    value       = string
    type        = string
    description = string
  }))
  default = {}
}

variable "kms_key_id" {
  description = "KMS key ID for encrypting SecureString parameters"
  type        = string
  default     = "alias/aws/ssm"
}

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}
