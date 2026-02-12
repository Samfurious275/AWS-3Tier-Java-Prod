variable "bucket_prefix" {
  description = "Prefix for S3 bucket name"
  type        = string
  default     = "mycompany-java-artifacts"
}

variable "environment" {
  description = "Environment name (prod/staging/dev)"
  type        = string
}

variable "account_id" {
  description = "AWS Account ID (for unique bucket naming)"
  type        = string
}

variable "common_tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default     = {}
}
