terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# ========== VPC ==========
resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(
    var.common_tags,
    { Name = "${var.environment}-vpc" }
  )
}

# ========== IGW ==========
resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(
    var.common_tags,
    { Name = "${var.environment}-igw" }
  )
}

# ========== Public Subnets (for ALB) ==========
resource "aws_subnet" "public" {
  count                   = length(var.azs)
  vpc_id                  = aws_vpc.this.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index)
  availability_zone       = var.azs[count.index]
  map_public_ip_on_launch = true

  tags = merge(
    var.common_tags,
    {
      Name                              = "${var.environment}-public-${count.index}"
      "kubernetes.io/role/elb"          = "1"
      "kubernetes.io/role/internal-elb" = "1"
    }
  )
}

# ========== Private Subnets (for App) ==========
resource "aws_subnet" "private" {
  count             = length(var.azs)
  vpc_id            = aws_vpc.this.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + length(var.azs))
  availability_zone = var.azs[count.index]

  tags = merge(
    var.common_tags,
    {
      Name                              = "${var.environment}-private-${count.index}"
      "kubernetes.io/role/internal-elb" = "1"
    }
  )
}

# ========== DB Subnets (isolated) ==========
resource "aws_subnet" "db" {
  count             = length(var.azs)
  vpc_id            = aws_vpc.this.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + (length(var.azs) * 2))
  availability_zone = var.azs[count.index]

  tags = merge(
    var.common_tags,
    { Name = "${var.environment}-db-${count.index}" }
  )
}

# ========== EIP for NAT ==========
resource "aws_eip" "nat" {
  count      = length(var.azs)
  domain     = "vpc"
  depends_on = [aws_internet_gateway.this]

  tags = merge(
    var.common_tags,
    { Name = "${var.environment}-nat-eip-${count.index}" }
  )
}

# ========== NAT Gateways ==========
resource "aws_nat_gateway" "this" {
  count         = length(var.azs)
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = merge(
    var.common_tags,
    { Name = "${var.environment}-nat-${count.index}" }
  )

  # Wait for NAT to be available before routing
  depends_on = [aws_internet_gateway.this]
}

# ========== Route Tables ==========
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = merge(
    var.common_tags,
    { Name = "${var.environment}-public-rt" }
  )
}

resource "aws_route_table" "private" {
  count  = length(var.azs)
  vpc_id = aws_vpc.this.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this[count.index].id
  }

  tags = merge(
    var.common_tags,
    { Name = "${var.environment}-private-rt-${count.index}" }
  )
}

# ========== Route Table Associations ==========
resource "aws_route_table_association" "public" {
  count          = length(var.azs)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  count          = length(var.azs)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

resource "aws_route_table_association" "db" {
  count          = length(var.azs)
  subnet_id      = aws_subnet.db[count.index].id
  route_table_id = aws_route_table.private[count.index].id # No internet access
}

# ========== Security Groups ==========
resource "aws_security_group" "alb" {
  vpc_id      = aws_vpc.this.id
  name        = "${var.environment}-alb-sg"
  description = "ALB security group"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.common_tags, { Name = "${var.environment}-alb-sg" })
}

resource "aws_security_group" "app" {
  vpc_id      = aws_vpc.this.id
  name        = "${var.environment}-app-sg"
  description = "App tier security group"

  ingress {
    from_port       = var.app_port
    to_port         = var.app_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.bastion_cidrs # Optional: restrict to jump host only
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.common_tags, { Name = "${var.environment}-app-sg" })
}

resource "aws_security_group" "db" {
  vpc_id      = aws_vpc.this.id
  name        = "${var.environment}-db-sg"
  description = "DB tier security group"

  ingress {
    from_port       = var.db_port
    to_port         = var.db_port
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.common_tags, { Name = "${var.environment}-db-sg" })
}

# ========== Outputs ==========
output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.this.id
}

output "public_subnets" {
  description = "Public subnet IDs"
  value       = aws_subnet.public[*].id
}

output "private_subnets" {
  description = "Private subnet IDs (app tier)"
  value       = aws_subnet.private[*].id
}

output "db_subnets" {
  description = "DB subnet IDs"
  value       = aws_subnet.db[*].id
}

output "alb_sg_id" {
  description = "ALB security group ID"
  value       = aws_security_group.alb.id
}

output "app_sg_id" {
  description = "App security group ID"
  value       = aws_security_group.app.id
}

output "db_sg_id" {
  description = "DB security group ID"
  value       = aws_security_group.db.id
}
