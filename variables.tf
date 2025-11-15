# provider
variable "region" {
  default = "ap-northeast-2"
}

variable "aws_access_key" {
  type        = string
  description = "AWS Access Key"
}

variable "aws_secret_key" {
  type        = string
  description = "AWS Secret Key"
}

variable "terraform_role_arn" {
  description = "Terraform Role ARN"
}

# common
variable "prefix" {
  default     = "come2us"
  type        = string
  description = "Jenkins Instance Type"
}

# jenkins
variable "docker_ami_id" {
  type        = string
  description = "AWS Machine Images"
}

variable "jenkins_instance_type" {
  type        = string
  description = "Jenkins Instance Type"
}

# network
variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "azs" {
  type    = list(string)
  default = ["ap-northeast-2a", "ap-northeast-2b"]
}

variable "public_subnet_cidrs" {
  type        = list(string)
  description = "Public subnet CIDRs"
}

variable "private_subnet_cidrs" {
  type        = list(string)
  description = "Private subnet CIDRs"
}

variable "db_subnet_cidrs" {
  type        = list(string)
  description = "Private subnet CIDRs for RDS"
}

variable "enable_nat" {
  type        = bool
  description = "Enable NAT Gateway in public_a"
  default     = true
}

# bastion
variable "bastion_instance_type" {
  default = "t3.micro"
}

variable "ubuntu_ami_id" {
  type        = string
  description = "AMI for Bastion host"
  default     = "ami-0c9c942bd7bf113a2" # Ubuntu 22.04
}

# RDS
variable "rds_db_name" {
  type = string
}

variable "rds_instance_class" {
  default = "db.t3.micro"
}

variable "rds_allocated_storage" {
  type    = number
  default = 20
}

variable "rds_engine_version" {
  type    = string
  default = "17.4"
}

variable "rds_username" {
  type = string
}

variable "rds_password" {
  type      = string
  sensitive = true
}

variable "rds_port" {
  type    = number
  default = 5432
}

# ECR image tag
variable "image_tag" {
  description = "ECR Docker image tag"
  type        = string
  default     = "latest"
}

# Blue/Green Deployment
variable "active_color" {
  description = "Current active deployment color (blue or green)"
  type        = string
  default     = "blue"
}

variable "ecr_uri" {
  description = "ECR repository URI"
  type        = string
}

# ALB
variable "acm_certificate_arn" {
  description = "ACM Certificate ARN for HTTPS listener"
  type        = string
  default     = ""
}

# ElastiCache
variable "elasticache_engine_version" {
  type    = string
  default = "7.1"
}

variable "elasticache_node_type" {
  type    = string
  default = "cache.t3.micro"
}

variable "elasticache_auth_token" {
  type      = string
  default   = null
  sensitive = true
}

# container port
variable "eureka_port" {
  description = "Container Port for Eureka"
  type        = number
  default     = 8761
}

variable "config_port" {
  description = "Container Port for Config Server"
  type        = number
  default     = 8888
}

variable "gateway_port" {
  description = "Container Port for API Gateway"
  type        = number
  default     = 8080
}

variable "member_port" {
  description = "Container Port for Member Service"
  type        = number
  default     = 8081
}

variable "product_port" {
  description = "Container Port for Product Service"
  type        = number
  default     = 8082
}

variable "order_port" {
  description = "Container Port for Order Service"
  type        = number
  default     = 8083
}

variable "payment_port" {
  description = "Container Port for Payment Service"
  type        = number
  default     = 8084
}

variable "ai_port" {
  description = "Container Port for AI Service"
  type        = number
  default     = 8085
}

variable "spring_profile_active" {
  description = "Active Profile of Spring Application"
  type        = string
  default     = "prod"
}
