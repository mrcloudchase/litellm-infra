# SSM Parameter for LiteLLM Master Key
resource "aws_ssm_parameter" "litellm_master_key" {
  name        = "/${var.name_prefix}/litellm/master-key"
  description = "LiteLLM master key for authentication"
  type        = "SecureString"
  value       = var.litellm_master_key
  key_id      = var.kms_key_id

  tags = merge(var.tags, {
    Name        = "${var.name_prefix}-litellm-master-key"
    Application = "litellm"
    Type        = "secret"
  })
}

# SSM Parameter for LiteLLM Salt Key
resource "aws_ssm_parameter" "litellm_salt_key" {
  name        = "/${var.name_prefix}/litellm/salt-key"
  description = "LiteLLM salt key for encryption/decryption of API keys"
  type        = "SecureString"
  value       = var.litellm_salt_key
  key_id      = var.kms_key_id

  tags = merge(var.tags, {
    Name        = "${var.name_prefix}-litellm-salt-key"
    Application = "litellm"
    Type        = "secret"
  })
}

# SSM Parameter for Database URL
resource "aws_ssm_parameter" "database_url" {
  name        = "/${var.name_prefix}/litellm/database-url"
  description = "Database connection URL for LiteLLM"
  type        = "SecureString"
  value       = var.database_url
  key_id      = var.kms_key_id

  tags = merge(var.tags, {
    Name        = "${var.name_prefix}-database-url"
    Application = "litellm"
    Type        = "secret"
  })
}

# Additional SSM Parameters
resource "aws_ssm_parameter" "additional" {
  for_each = var.additional_parameters

  name        = "/${var.name_prefix}/litellm/${each.key}"
  description = each.value.description
  type        = each.value.type
  value       = each.value.value
  key_id      = each.value.type == "SecureString" ? var.kms_key_id : null

  tags = merge(var.tags, {
    Name        = "${var.name_prefix}-${each.key}"
    Application = "litellm"
    Type        = each.value.type == "SecureString" ? "secret" : "config"
  })
}
