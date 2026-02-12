variable "environment" {
  description = "Environment name"
  type        = string
}

variable "ami_id" {
  description = "AMI ID (Amazon Linux 2 recommended)"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.medium"
}
variable "app_port" {
  description = "Application port"
  type        = number
  default     = 8080
}

variable "root_volume_size" {
  description = "Root volume size (GB)"
  type        = number
  default     = 30
}

variable "private_subnets" {
  description = "Private subnet IDs"
  type        = list(string)
}

variable "app_security_group_id" {
  description = "App security group ID"
  type        = string
}

variable "target_group_arn" {
  description = "ALB target group ARN"
  type        = string
}

variable "asg_min_size" {
  description = "ASG min size"
  type        = number
  default     = 2
}

variable "asg_max_size" {
  description = "ASG max size"
  type        = number
  default     = 4
}

variable "asg_desired_capacity" {
  description = "ASG desired capacity"
  type        = number
  default     = 2
}

variable "artifact_bucket" {
  description = "S3 bucket for Java JAR"
  type        = string
}

variable "artifact_key" {
  description = "S3 key for JAR file"
  type        = string
}

variable "db_host" {
  description = "RDS endpoint"
  type        = string
}

variable "db_port" {
  description = "RDS port"
  type        = number
}

variable "db_name" {
  description = "Database name"
  type        = string
}

variable "db_user" {
  description = "Database username"
  type        = string
}

variable "db_password" {
  description = "Database password (use secrets manager in prod!)"
  type        = string
  sensitive   = true
}

variable "common_tags" {
  description = "Common tags"
  type        = map(string)
}
