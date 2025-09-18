output "cluster_id" {
  description = "ID of the ECS cluster"
  value       = aws_ecs_cluster.main.id
}

output "cluster_arn" {
  description = "ARN of the ECS cluster"
  value       = aws_ecs_cluster.main.arn
}

output "cluster_name" {
  description = "Name of the ECS cluster"
  value       = aws_ecs_cluster.main.name
}

output "service_id" {
  description = "ID of the ECS service"
  value       = aws_ecs_service.main.id
}

output "service_name" {
  description = "Name of the ECS service"
  value       = aws_ecs_service.main.name
}

output "service_arn" {
  description = "ARN of the ECS service"
  value       = aws_ecs_service.main.id
}

output "task_definition_arn" {
  description = "ARN of the task definition"
  value       = aws_ecs_task_definition.main.arn
}

output "task_definition_family" {
  description = "Family of the task definition"
  value       = aws_ecs_task_definition.main.family
}

output "task_definition_revision" {
  description = "Revision of the task definition"
  value       = aws_ecs_task_definition.main.revision
}

output "log_group_name" {
  description = "Name of the CloudWatch log group"
  value       = aws_cloudwatch_log_group.ecs_logs.name
}

output "log_group_arn" {
  description = "ARN of the CloudWatch log group"
  value       = aws_cloudwatch_log_group.ecs_logs.arn
}

output "autoscaling_target_resource_id" {
  description = "Resource ID of the autoscaling target"
  value       = var.enable_autoscaling ? aws_appautoscaling_target.ecs_target[0].resource_id : null
}
