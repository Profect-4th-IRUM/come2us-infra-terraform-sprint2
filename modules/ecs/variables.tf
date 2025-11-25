variable "alb_target_group_blue" { default = null }
variable "alb_target_group_green" { default = null }

variable "service_name" {}
variable "cluster_name" {}
variable "region" {}

variable "subnets" {
  type = list(string)
}

variable "security_group_id" {}

variable "execution_role_arn" {}
variable "task_role_arn" {}

variable "ecr_image" {}
variable "image_tag_blue" {}
variable "image_tag_green" {}
variable "container_name" {}
variable "container_port" {}

variable "environment" {
  type    = map(string)
  default = {}
}

variable "ssm_parameters" {
  type    = map(string)
  default = {}
}

variable "service_discovery_arn" {
  type    = string
  default = ""
}

variable "desired_count" {
  default = 2
}

variable "cpu" { default = "512" }
variable "memory" { default = "1024" }

variable "active_color" {}
variable "warmup_color" {
  default = ""
}
