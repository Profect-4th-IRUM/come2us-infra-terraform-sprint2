variable "prefix" {
  description = "Project prefix"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-2"
}

variable "subnets" {
  description = "Private subnets for ECS tasks"
  type        = list(string)
}

variable "backend_sg_id" {
  description = "Security Group for ECS tasks"
  type        = string
}

variable "alb_target_group_blue" {
  description = "Blue Target Group ARN"
  type        = string
}

variable "alb_target_group_green" {
  description = "Green Target Group ARN"
  type        = string
}

variable "active_color" {
  description = "Active deployment color (blue or green)"
  type        = string
}

variable "warmup_color" {
  type = string
}

variable "container_port" {
  description = "Container port for ECS task"
  type        = number
  default     = 8080
}

variable "ecr_image" {
  description = "ECR image base URL (ex: 123456789012.dkr.ecr.ap-northeast-2.amazonaws.com/come2us)"
  type        = string
}

variable "image_tag" {
  description = "Image tag from Jenkins (e.g., Git SHA)"
  type        = string
}

variable "cluster_name" {
  description = "ECS cluster name to join"
  type        = string
}
