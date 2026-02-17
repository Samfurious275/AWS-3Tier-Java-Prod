terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}


provider "aws" {
  region = var.aws_region
  default_tags {
    tags = var.common_tags
  }
}

# Provider alias for ACM (must be in us-east-1)
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}

# ========== S3 Artifacts Bucket ==========
module "s3_artifacts" {
  source = "../../modules/s3-artifacts"

  bucket_prefix = "mycompany-java-artifacts"
  environment   = var.environment
  account_id    = var.account_id
  common_tags   = var.common_tags
}

# ========== ACM Certificate (us-east-1) ==========
module "acm_certificate" {
  source = "../../modules/acm-certificate"

  providers = {
    aws = aws.us_east_1
  }
  # 🔑 FREE TIER FIX: Only create if enable_https = true
  count = var.enable_https ? 1 : 0

  domain_name               = var.domain_name
  subject_alternative_names = var.subject_alternative_names
  route53_zone_id           = var.route53_zone_id
  environment               = var.environment
  common_tags               = var.common_tags
}

# ========== Network Module ==========
module "network" {
  source = "../../modules/network"

  vpc_cidr      = var.vpc_cidr
  azs           = var.azs
  environment   = var.environment
  common_tags   = var.common_tags
  app_port      = var.app_port
  db_port       = var.db_port
  bastion_cidrs = var.bastion_cidrs
}

# ========== RDS Module ==========
module "rds" {
  source = "../../modules/rds"

  environment                = var.environment
  db_subnets                 = module.network.db_subnets
  db_security_group_id       = module.network.db_sg_id
  db_name                    = var.db_name
  username                   = var.db_username
  password                   = var.db_password
  port                       = var.db_port
  enable_deletion_protection = var.enable_deletion_protection
  common_tags                = var.common_tags
}

# ========== ALB Module ==========
module "alb" {
  source = "../../modules/alb"

  vpc_id                     = module.network.vpc_id
  public_subnets             = module.network.public_subnets
  alb_security_group_id      = module.network.alb_sg_id
  app_port                   = var.app_port
  environment                = var.environment
  common_tags                = var.common_tags
  # 🔑 FREE TIER FIX: Conditional certificate ARN
  ssl_certificate_arn    = var.enable_https ? module.acm_certificate[0].certificate_arn : null
  enable_deletion_protection = var.enable_deletion_protection
}

# ========== App Module (SSM-ONLY - NO SSH KEY) ==========
module "app" {
  source = "../../modules/app"

  environment   = var.environment
  ami_id        = var.ami_id
  instance_type = var.instance_type
  # 🔒 REMOVED: key_name = null → NO SSH ACCESS
  app_port              = var.app_port
  root_volume_size      = var.root_volume_size
  private_subnets       = module.network.private_subnets
  app_security_group_id = module.network.app_sg_id
  target_group_arn      = module.alb.target_group_arn
  asg_min_size          = var.asg_min_size
  asg_max_size          = var.asg_max_size
  asg_desired_capacity  = var.asg_desired_capacity
  artifact_bucket       = module.s3_artifacts.bucket_name # ✅ AUTO-CREATED
  artifact_key          = var.artifact_key
  db_host               = module.rds.endpoint
  db_port               = module.rds.port
  db_name               = module.rds.db_name
  db_user               = var.db_username
  db_password           = var.db_password
  common_tags           = var.common_tags
}

# ========== Outputs ==========
output "alb_dns" {
  description = "Application Load Balancer DNS name"
  value       = module.alb.alb_dns_name
}

output "artifact_bucket" {
  description = "S3 bucket for Java artifacts"
  value       = module.s3_artifacts.bucket_name
}

output "certificate_arn" {
  description = "ACM certificate ARN"
  value       = module.acm_certificate.certificate_arn
  sensitive   = true
}
