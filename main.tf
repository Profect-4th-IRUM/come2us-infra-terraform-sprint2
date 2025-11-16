terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
  backend "s3" {}
}

provider "aws" {
  region     = var.region
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key

  assume_role {
    role_arn = var.terraform_role_arn
  }
}

module "network" {
  source               = "./modules/network"
  vpc_cidr             = var.vpc_cidr
  azs                  = var.azs
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  db_subnet_cidrs      = var.db_subnet_cidrs
  enable_nat           = var.enable_nat
  prefix               = var.prefix
}

module "sg" {
  source = "./modules/sg"
  vpc_id = module.network.vpc_id
  vpc_cidr = var.vpc_cidr
}

module "keypair" {
  source = "./modules/keypair"
  prefix = var.prefix
}

module "jenkins" {
  source        = "./modules/jenkins"
  ami_id        = var.docker_ami_id
  instance_type = var.jenkins_instance_type
  prefix        = var.prefix
  subnet_id     = module.network.private_subnet_a_id
  vpc_id        = module.network.vpc_id
  key_name      = module.keypair.key_name
  az            = var.azs[0]
  sg_id         = module.sg.backend_sg_id
}

module "alb_jenkins" {
  source             = "./modules/alb_jenkins"
  vpc_id             = module.network.vpc_id
  alb_sg_id          = module.sg.alb_sg_id
  subnet_ids         = module.network.public_subnet_ids
  target_instance_id = module.jenkins.instance_id
  prefix             = "${var.prefix}-jenkins"

  depends_on = [module.jenkins]
}

module "alb_service" {
  source       = "./modules/alb"
  vpc_id       = module.network.vpc_id
  alb_sg_id    = module.sg.alb_sg_id
  subnet_ids   = module.network.public_subnet_ids
  prefix       = "${var.prefix}-service"
  active_color = var.gateway_active_color
  # acm_certificate_arn = var.acm_certificate_arn
}

module "bastion" {
  source        = "./modules/bastion"
  ami_id        = var.ubuntu_ami_id
  instance_type = var.bastion_instance_type
  subnet_id     = module.network.public_subnet_a_id
  sg_id         = module.sg.bastion_sg_id
  key_name      = module.keypair.key_name
  prefix        = var.prefix
}

# RDS
module "rds" {
  source            = "./modules/rds"
  prefix            = "${var.prefix}-db"
  subnet_ids        = module.network.db_subnet_ids
  vpc_id            = module.network.vpc_id
  sg_id             = module.sg.rds_sg_id
  instance_class    = var.rds_instance_class
  allocated_storage = var.rds_allocated_storage
  engine_version    = var.rds_engine_version
  db_name           = var.rds_db_name
  username          = var.rds_username
  password          = var.rds_password
  port              = var.rds_port
}

module "elasticache" {
  source         = "./modules/elasticache"
  prefix         = var.prefix
  subnet_ids     = module.network.db_subnet_ids
  sg_id          = module.sg.redis_sg_id
  azs            = var.azs
  engine_version = var.elasticache_engine_version
  node_type      = var.elasticache_node_type
  auth_token     = var.elasticache_auth_token
}

resource "aws_ecs_cluster" "come2us" {
  name = "${var.prefix}-cluster"
}

module "ecs_iam" {
  source = "./modules/iam"
  prefix = var.prefix
}

module "ssm" {
  source = "./modules/ssm"

  parameters = {
    "/${var.prefix}/config/GIT_USERNAME"            = var.git_username
    "/${var.prefix}/config/GIT_TOKEN"               = var.git_token
    "/${var.prefix}/common/JWT_ACCESS_TOKEN_SECRET" = var.jwt_secret
  }
}

# Cloud Map
resource "aws_service_discovery_private_dns_namespace" "come2us" {
  name        = "${var.prefix}.local"
  description = "Service discovery namespace for internal ECS services"
  vpc         = module.network.vpc_id
}

# Cloud Map - config-server
resource "aws_service_discovery_service" "config" {
  name = "${var.prefix}-config"

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.come2us.id

    dns_records {
      ttl  = 10
      type = "A"
    }

    routing_policy = "MULTIVALUE"
  }
}

# Cloud Map - eureka(service discovery)
resource "aws_service_discovery_service" "eureka" {
  name = "${var.prefix}-eureka"

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.come2us.id

    dns_records {
      ttl  = 10
      type = "A"
    }

    routing_policy = "MULTIVALUE"
  }
}

module "ecs_gateway" {
  source                 = "./modules/ecs"

  prefix                 = "${var.prefix}-gateway"
  cluster_name = aws_ecs_cluster.come2us.name
  subnets                = module.network.private_subnet_ids
  backend_sg_id          = module.sg.backend_sg_id

  alb_target_group_blue  = module.alb_service.gateway_tg_blue_arn
  alb_target_group_green = module.alb_service.gateway_tg_green_arn

  image_tag_blue = var.gateway_image_tag_blue
  image_tag_green = var.gateway_image_tag_green

  ecr_image      = "${var.ecr_uri}-gateway"
  container_name = "${var.prefix}-gateway"
  container_port = var.gateway_port
  region         = var.region

  profile_active = var.spring_profile_active
  config_server_host = "${aws_service_discovery_service.config.name}.${var.prefix}.local"
  config_server_port = var.config_port
  eureka_host     = "${aws_service_discovery_service.eureka.name}.${var.prefix}.local"
  eureka_port    = var.eureka_port

  active_color = var.gateway_active_color
  warmup_color = var.gateway_warmup_color

  execution_role_arn = module.ecs_iam.task_execution_role_arn
  task_role_arn      = module.ecs_iam.task_role_arn

  ssm_parameters = {
    JWT_ACCESS_TOKEN_SECRET = module.ssm.parameter_arns["/${var.prefix}/common/JWT_ACCESS_TOKEN_SECRET"]
  }

  depends_on = [module.ecs_config_server]
}

module "ecs_config_server" {
  source = "./modules/ecs-single"

  prefix        = "${var.prefix}-config"
  cluster_name  = aws_ecs_cluster.come2us.name
  subnets       = module.network.private_subnet_ids
  backend_sg_id = module.sg.backend_sg_id

  ecr_image      = "${var.ecr_uri}-config"
  image_tag      = var.config_image_tag
  container_name = "${var.prefix}-config"
  container_port = var.config_port
  region         = var.region

  profile_active     = var.spring_profile_active
  config_server_host = ""
  config_server_port = var.config_port

  execution_role_arn = module.ecs_iam.task_execution_role_arn
  task_role_arn      = module.ecs_iam.task_role_arn

  service_discovery_arn = aws_service_discovery_service.config.arn

  desired_count    = 2
  assign_public_ip = false

  ssm_parameters = {
    GIT_USERNAME            = module.ssm.parameter_arns["/${var.prefix}/config/GIT_USERNAME"]
    GIT_TOKEN               = module.ssm.parameter_arns["/${var.prefix}/config/GIT_TOKEN"]
    JWT_ACCESS_TOKEN_SECRET = module.ssm.parameter_arns["/${var.prefix}/common/JWT_ACCESS_TOKEN_SECRET"]
  }
}

module "ecs_eureka" {
  source = "./modules/ecs-single"

  prefix        = "${var.prefix}-eureka"
  cluster_name  = aws_ecs_cluster.come2us.name
  subnets       = module.network.private_subnet_ids
  backend_sg_id = module.sg.backend_sg_id

  ecr_image      = "${var.ecr_uri}-eureka"
  image_tag      = var.eureka_image_tag
  container_name = "${var.prefix}-eureka"
  container_port = var.eureka_port
  region         = var.region

  profile_active     = var.spring_profile_active
  config_server_host = "${aws_service_discovery_service.config.name}.${var.prefix}.local"
  config_server_port = var.config_port
  eureka_host        = "${aws_service_discovery_service.eureka.name}.${var.prefix}.local"
  eureka_port        = var.eureka_port

  execution_role_arn = module.ecs_iam.task_execution_role_arn
  task_role_arn      = module.ecs_iam.task_role_arn

  service_discovery_arn = aws_service_discovery_service.eureka.arn

  desired_count    = 2
  assign_public_ip = true

  depends_on = [module.ecs_config_server]
}
