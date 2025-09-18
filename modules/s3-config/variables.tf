variable "name_prefix" {
  description = "Name prefix for all resources"
  type        = string
}

variable "config_content" {
  description = "Content of the LiteLLM configuration file"
  type        = string
}

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}
