variable "vpc_id" {
  type        = string
  description = "VPC ID"
}

variable "alb_sg_id" {
  type        = string
  description = "Security Group ID for ALB"
}

variable "subnet_ids" {
  type        = list(string)
  description = "Public Subnet IDs for ALB"
}

variable "prefix" {
  type        = string
  description = "Name prefix"
}

variable "acm_certificate_arn" {
  type        = string
  description = "ACM Certificate ARN for HTTPS listener"
  default     = null
}

variable "active_color" {
  type    = string
  default = ""
}