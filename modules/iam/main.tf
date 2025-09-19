# ECS Task Execution Role
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "${var.name_prefix}-ecs-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

# Attach the AWS managed policy for ECS task execution
resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Custom policy for ECS task execution to access SSM parameters
resource "aws_iam_policy" "ecs_task_execution_ssm_policy" {
  count = length(var.ssm_parameter_arns) > 0 ? 1 : 0

  name        = "${var.name_prefix}-ecs-task-execution-ssm-policy"
  description = "Policy for ECS task execution to access SSM parameters"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameters",
          "ssm:GetParameter",
          "ssm:GetParametersByPath"
        ]
        Resource = var.ssm_parameter_arns
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "kms:ViaService" = "ssm.*.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = var.tags
}

# Attach SSM policy to execution role
resource "aws_iam_role_policy_attachment" "ecs_task_execution_ssm_policy_attachment" {
  count = length(var.ssm_parameter_arns) > 0 ? 1 : 0

  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = aws_iam_policy.ecs_task_execution_ssm_policy[0].arn
}

# ECS Task Role (for application-level permissions)
resource "aws_iam_role" "ecs_task_role" {
  name = "${var.name_prefix}-ecs-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

# Custom policy for ECS task role to access SSM parameters
resource "aws_iam_policy" "ecs_task_ssm_policy" {
  count = length(var.ssm_parameter_arns) > 0 ? 1 : 0

  name        = "${var.name_prefix}-ecs-task-ssm-policy"
  description = "Policy for ECS tasks to access SSM parameters"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameters",
          "ssm:GetParameter",
          "ssm:GetParametersByPath"
        ]
        Resource = var.ssm_parameter_arns
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "kms:ViaService" = "ssm.*.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = var.tags
}

# Attach SSM policy to task role
resource "aws_iam_role_policy_attachment" "ecs_task_ssm_policy_attachment" {
  count = length(var.ssm_parameter_arns) > 0 ? 1 : 0

  role       = aws_iam_role.ecs_task_role.name
  policy_arn = aws_iam_policy.ecs_task_ssm_policy[0].arn
}

# Attach additional policies to task role
resource "aws_iam_role_policy_attachment" "ecs_task_additional_policies" {
  count = length(var.additional_task_policy_arns)

  role       = aws_iam_role.ecs_task_role.name
  policy_arn = var.additional_task_policy_arns[count.index]
}

# CloudWatch Logs policy for task role
resource "aws_iam_policy" "ecs_task_cloudwatch_policy" {
  name        = "${var.name_prefix}-ecs-task-cloudwatch-policy"
  description = "Policy for ECS tasks to write to CloudWatch Logs"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ]
        Resource = "*"
      }
    ]
  })

  tags = var.tags
}

# Attach CloudWatch Logs policy to task role
resource "aws_iam_role_policy_attachment" "ecs_task_cloudwatch_policy_attachment" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = aws_iam_policy.ecs_task_cloudwatch_policy.arn
}

# Note: S3 policy removed - configuration is now baked into container
# No S3 access needed for configuration files
