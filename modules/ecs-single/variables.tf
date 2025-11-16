variable "prefix" {
  description = "Service prefix (ex: come2us-config, come2us-eureka)"
  type        = string
}

variable "cluster_name" {
  description = "ECS Cluster name"
  type        = string
}

variable "subnets" {
  description = "Subnets for ECS tasks"
  type        = list(string)
}

variable "backend_sg_id" {
  description = "Security group ID for backend services"
  type        = string
}

variable "ecr_image" {
  description = "Base ECR image URI"
  type        = string
}

variable "image_tag" {
  description = "Docker image tag"
  type        = string
}

variable "container_name" {
  description = "Container name used in task definition"
  type        = string
}

variable "container_port" {
  description = "Container port"
  type        = number
}

variable "region" {
  description = "AWS region"
  type        = string
}

variable "profile_active" {
  description = "Spring profile active"
  type        = string
  default     = "prod"
}

variable "config_server_host" {
  description = "Config server host (for CONFIG_SERVER_URL)"
  type        = string
  default     = ""
}

variable "config_server_port" {
  description = "Config server port"
  type        = number
  default     = 8888
}

variable "eureka_host" {
  description = "Eureka host (for EUREKA_HOST)"
  type        = string
  default     = ""
}

variable "eureka_port" {
  description = "Eureka port"
  type        = number
  default     = 8761
}

variable "execution_role_arn" {
  description = "IAM role ARN for ECS task execution"
  type        = string
}

variable "task_role_arn" {
  description = "IAM role ARN for ECS task"
  type        = string
}

variable "service_discovery_arn" {
  description = "Cloud Map service ARN (optional)"
  type        = string
  default     = ""
}

variable "desired_count" {
  description = "Desired task count"
  type        = number
  default     = 2
}

variable "assign_public_ip" {
  description = "Assign public IP to ECS tasks"
  type        = bool
  default     = false
}
