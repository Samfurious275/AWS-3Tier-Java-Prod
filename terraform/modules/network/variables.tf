variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.0.0.0/16"
}

variable "azs" {
  description = "Availability zones"
  type        = list(string)
}

variable "environment" {
  description = "Environment name (prod/staging/dev)"
  type        = string
}

variable "common_tags" {
  description = "Common tags for all resources"
  type        = map(string)
}

variable "app_port" {
  description = "Application port (Java app)"
  type        = number
  default     = 8080
}

variable "db_port" {
  description = "Database port"
  type        = number
  default     = 5432
}

variable "bastion_cidrs" {
  description = "CIDR blocks allowed to SSH (optional bastion)"
  type        = list(string)
  default     = ["0.0.0.0/0"]  # 🔒 RESTRICT IN PRODUCTION!
}
