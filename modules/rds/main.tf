# Random password for database if not provided
resource "random_password" "database_password" {
  count = var.database_password == "" ? 1 : 0

  length  = 32
  special = true
}

locals {
  database_password = var.database_password != "" ? var.database_password : random_password.database_password[0].result
}

# DB Parameter Group
resource "aws_db_parameter_group" "main" {
  family = var.parameter_group_family
  name   = "${var.name_prefix}-db-params"

  parameter {
    name  = "log_statement"
    value = "all"
  }

  parameter {
    name  = "log_min_duration_statement"
    value = "1000"
  }

  parameter {
    name  = "shared_preload_libraries"
    value = "pg_stat_statements"
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-db-params"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# DB Option Group (not needed for PostgreSQL, but keeping for consistency)
resource "aws_db_option_group" "main" {
  name                     = "${var.name_prefix}-db-options"
  option_group_description = "Option group for ${var.name_prefix}"
  engine_name              = "postgres"
  major_engine_version     = split(".", var.engine_version)[0]

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-db-options"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# Enhanced Monitoring Role
resource "aws_iam_role" "enhanced_monitoring" {
  count = var.monitoring_interval > 0 ? 1 : 0

  name = "${var.name_prefix}-rds-enhanced-monitoring"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "monitoring.rds.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "enhanced_monitoring" {
  count = var.monitoring_interval > 0 ? 1 : 0

  role       = aws_iam_role.enhanced_monitoring[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

# RDS Instance
resource "aws_db_instance" "main" {
  identifier = "${var.name_prefix}-db"

  # Engine
  engine         = "postgres"
  engine_version = var.engine_version

  # Instance
  instance_class = var.instance_class

  # Storage
  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_type          = var.storage_type
  storage_encrypted     = var.storage_encrypted
  kms_key_id            = var.kms_key_id

  # Database
  db_name  = var.database_name
  username = var.database_username
  password = local.database_password

  # Network
  db_subnet_group_name   = var.db_subnet_group_name
  vpc_security_group_ids = var.security_group_ids
  publicly_accessible    = var.publicly_accessible

  # Backup
  backup_retention_period = var.backup_retention_period
  backup_window          = var.backup_window
  maintenance_window     = var.maintenance_window

  # High Availability
  multi_az = var.multi_az

  # Parameter and Option Groups
  parameter_group_name = aws_db_parameter_group.main.name
  option_group_name    = aws_db_option_group.main.name

  # Monitoring
  monitoring_interval = var.monitoring_interval
  monitoring_role_arn = var.monitoring_interval > 0 ? aws_iam_role.enhanced_monitoring[0].arn : null

  # Performance Insights
  performance_insights_enabled = var.performance_insights_enabled

  # Deletion Protection
  deletion_protection       = var.deletion_protection
  skip_final_snapshot      = var.skip_final_snapshot
  final_snapshot_identifier = var.skip_final_snapshot ? null : coalesce(var.final_snapshot_identifier, "${var.name_prefix}-final-snapshot-${formatdate("YYYY-MM-DD-hhmm", timestamp())}")

  # Auto Minor Version Upgrade
  auto_minor_version_upgrade = true

  # Copy tags to snapshots
  copy_tags_to_snapshot = true

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-db"
  })

  depends_on = [
    aws_db_parameter_group.main,
    aws_db_option_group.main
  ]
}
