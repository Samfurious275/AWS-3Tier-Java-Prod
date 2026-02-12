variable "account_id" {
  description = "AWS Account ID (for bucket naming)"
  type        = string
}

variable "domain_name" {
  description = "Primary domain for ALB (e.g., app.yourcompany.com)"
  type        = string
}

variable "subject_alternative_names" {
  description = "Additional domains for certificate"
  type        = list(string)
  default     = []
}

variable "route53_zone_id" {
  description = "Route53 Hosted Zone ID (e.g., Z1234567890ABC)"
  type        = string
}

variable "artifact_key" {
  description = "S3 key for JAR file (e.g., app-v1.2.3.jar)"
  type        = string
}
variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "prod"
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.0.0.0/16"
}

variable "azs" {
  description = "Availability zones"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "app_port" {
  description = "Application port"
  type        = number
  default     = 8080
}

variable "db_port" {
  description = "Database port"
  type        = number
  default     = 5432
}

variable "db_name" {
  description = "Database name"
  type        = string
  default     = "javaprod"
}

variable "db_username" {
  description = "Database master username"
  type        = string
  default     = "admin"
}

variable "db_password" {
  description = "Database master password"
  type        = string
  sensitive   = true
}

variable "ami_id" {
  description = "AMI ID (Amazon Linux 2)"
  type        = string
  default     = "ami-0c02fb55956c7d336"  # us-east-1 AL2
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.medium"
}

variable "key_name" {
  description = "SSH key name (set to null for SSM-only)"
  type        = string
  default     = null  # 🔒 NULL FOR PRODUCTION (SSM ONLY)
}

variable "root_volume_size" {
  description = "Root volume size (GB)"
  type        = number
  default     = 30
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
variable "artifact_key" {
  description = "S3 key for JAR file"
  type        = string
}

variable "bastion_cidrs" {
  description = "CIDRs allowed to SSH (optional)"
  type        = list(string)
  default     = ["10.0.0.0/8"]  # 🔒 RESTRICT TO CORPORATE IP
}

variable "enable_deletion_protection" {
  description = "Enable deletion protection for critical resources"
  type        = bool
  default     = true
}

variable "common_tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default = {
    Environment = "prod"
    Owner       = "devops-team"
    Project     = "java-3tier-app"
    CostCenter  = "cc-12345"
  }
}
