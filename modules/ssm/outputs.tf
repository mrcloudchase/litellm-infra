output "litellm_master_key_arn" {
  description = "ARN of the LiteLLM master key SSM parameter"
  value       = aws_ssm_parameter.litellm_master_key.arn
}

output "litellm_salt_key_arn" {
  description = "ARN of the LiteLLM salt key SSM parameter"
  value       = aws_ssm_parameter.litellm_salt_key.arn
}

output "database_url_arn" {
  description = "ARN of the database URL SSM parameter"
  value       = aws_ssm_parameter.database_url.arn
}

output "litellm_master_key_name" {
  description = "Name of the LiteLLM master key SSM parameter"
  value       = aws_ssm_parameter.litellm_master_key.name
}

output "litellm_salt_key_name" {
  description = "Name of the LiteLLM salt key SSM parameter"
  value       = aws_ssm_parameter.litellm_salt_key.name
}

output "database_url_name" {
  description = "Name of the database URL SSM parameter"
  value       = aws_ssm_parameter.database_url.name
}

output "additional_parameter_arns" {
  description = "ARNs of additional SSM parameters"
  value       = { for k, v in aws_ssm_parameter.additional : k => v.arn }
}

output "additional_parameter_names" {
  description = "Names of additional SSM parameters"
  value       = { for k, v in aws_ssm_parameter.additional : k => v.name }
}

output "all_parameter_arns" {
  description = "List of all SSM parameter ARNs created by this module"
  value = concat(
    [
      aws_ssm_parameter.litellm_master_key.arn,
      aws_ssm_parameter.litellm_salt_key.arn,
      aws_ssm_parameter.database_url.arn
    ],
    [for param in aws_ssm_parameter.additional : param.arn]
  )
}
