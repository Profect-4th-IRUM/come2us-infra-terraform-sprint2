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

variable "target_instance_id" {
  type        = string
  description = "Target EC2 instance to attach"
}

variable "prefix" {
  type        = string
  description = "Name prefix"
}
