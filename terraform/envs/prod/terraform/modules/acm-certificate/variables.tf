variable "domain_name" {
  description = "Primary domain for certificate (e.g., app.example.com)"
  type        = string
}

variable "subject_alternative_names" {
  description = "Additional domains (e.g., www.app.example.com)"
  type        = list(string)
  default     = []
}

variable "route53_zone_id" {
  description = "Route53 Hosted Zone ID for domain"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "common_tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}
