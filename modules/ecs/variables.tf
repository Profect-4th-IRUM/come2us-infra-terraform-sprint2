variable "prefix" {}
variable "region" {}
variable "subnets" {}
variable "backend_sg_id" {}

variable "alb_target_group_blue" { default = null }
variable "alb_target_group_green" { default = null }

variable "active_color" {}
variable "warmup_color" {}

variable "container_port" {}
variable "ecr_image" {}

variable "image_tag_blue" {}
variable "image_tag_green" {}

variable "cluster_name" {}
variable "container_name" {}

variable "rds_primary_endpoint" { default = "" }
variable "rds_replica_endpoint" { default = "" }
variable "rds_port" { default = "" }
variable "rds_username" { default = "" }
variable "rds_password" { default = "" }
variable "rds_db_name" { default = "" }

variable "session_redis_endpoint" { default = "" }
variable "session_redis_port" { default = "" }
variable "session_redis_password" { default = "" }

variable "cache_redis_endpoint" { default = "" }
variable "cache_redis_port" { default = "" }

variable "service_discovery_arn" { default = "" }
variable "profile_active" {}

variable "config_server_host" { default = "" }
variable "config_server_port" { default = 8888 }
variable "eureka_host" { default = "" }
variable "eureka_port" { default = 8761}

variable "execution_role_arn" {}
variable "task_role_arn" {}
