terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# ========== DB Subnet Group ==========
resource "aws_db_subnet_group" "this" {
  name       = "${var.environment}-db-subnet-group"
  subnet_ids = var.db_subnets

  tags = merge(
    var.common_tags,
    { Name = "${var.environment}-db-subnet-group" }
  )
}

# ========== RDS Parameter Group ==========
resource "aws_db_parameter_group" "this" {
  name   = "${var.environment}-pg"
  family = "postgres14"

  parameter {
    name  = "log_connections"
    value = "1"
  }

  tags = var.common_tags
}

# ========== RDS Instance (Multi-AZ) ==========
resource "aws_db_instance" "this" {
  identifier                            = "${var.environment}-db"
  engine                                = "postgres"
  engine_version                        = "14.10"
  instance_class                        = var.instance_class
  allocated_storage                     = var.allocated_storage
  max_allocated_storage                 = var.max_allocated_storage
  storage_type                          = "gp3"
  storage_encrypted                     = true
  db_name                               = var.db_name
  username                              = var.username
  password                              = var.password
  port                                  = var.port
  publicly_accessible                   = false
  multi_az                              = true
  backup_retention_period               = 7
  backup_window                         = "03:00-04:00"
  maintenance_window                    = "sun:04:00-sun:05:00"
  skip_final_snapshot                   = false
  final_snapshot_identifier             = "${var.environment}-db-final-snapshot-${formatdate("YYYYMMDDhhmm", timestamp())}"
  deletion_protection                   = var.enable_deletion_protection
  db_subnet_group_name                  = aws_db_subnet_group.this.name
  vpc_security_group_ids                = [var.db_security_group_id]
  parameter_group_name                  = aws_db_parameter_group.this.name
  performance_insights_enabled          = true
  performance_insights_retention_period = 7

  tags = merge(
    var.common_tags,
    { Name = "${var.environment}-db" }
  )

  lifecycle {
    ignore_changes = [password] # Prevent forced replacement on password change
  }
}

output "endpoint" {
  description = "RDS endpoint"
  value       = aws_db_instance.this.endpoint
  sensitive   = true
}

output "port" {
  description = "RDS port"
  value       = aws_db_instance.this.port
}

output "db_name" {
  description = "Database name"
  value       = aws_db_instance.this.db_name
}
