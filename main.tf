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
}

module "keypair" {
  source = "./modules/keypair"
  prefix = var.prefix
}

# module "jenkins" {
#   source        = "./modules/jenkins"
#   ami_id        = var.docker_ami_id
#   instance_type = var.jenkins_instance_type
#   prefix        = var.prefix
#   subnet_id     = module.network.private_subnet_a_id
#   vpc_id        = module.network.vpc_id
#   key_name      = module.keypair.key_name
#   az            = var.azs[0]
#   sg_id         = module.sg.backend_sg_id
# }

# module "alb_jenkins" {
#   source             = "./modules/alb"
#   vpc_id             = module.network.vpc_id
#   alb_sg_id          = module.sg.alb_sg_id
#   subnet_ids         = module.network.public_subnet_ids
#   target_instance_id = module.jenkins.instance_id
#   prefix             = "${var.prefix}-jenkins"
# }

module "alb_service" {
  source     = "./modules/alb"
  vpc_id     = module.network.vpc_id
  alb_sg_id  = module.sg.alb_sg_id
  subnet_ids = module.network.public_subnet_ids
  prefix     = "${var.prefix}-service"
  active_color = var.active_color
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
# module "rds" {
#   source            = "./modules/rds"
#   prefix            = "${var.prefix}-db"
#   subnet_ids        = module.network.db_subnet_ids
#   vpc_id            = module.network.vpc_id
#   sg_id             = module.sg.rds_sg_id
#   instance_class    = var.rds_instance_class
#   allocated_storage = var.rds_allocated_storage
#   engine_version    = var.rds_engine_version
#   db_name           = var.rds_db_name
#   username          = var.rds_username
#   password          = var.rds_password
#   port              = var.rds_port
# }

# module "elasticache" {
#   source         = "./modules/elasticache"
#   prefix         = var.prefix
#   subnet_ids     = module.network.db_subnet_ids
#   sg_id          = module.sg.redis_sg_id
#   azs            = var.azs
#   engine_version = var.elasticache_engine_version
#   node_type      = var.elasticache_node_type
#   auth_token     = var.elasticache_auth_token
# }

resource "aws_ecs_cluster" "come2us" {
  name = "${var.prefix}-cluster"
}

module "ecs_test" {
  source = "./modules/ecs"
  prefix = "${var.prefix}-test"
  subnets = module.network.private_subnet_ids
  backend_sg_id = module.sg.test_sg_id
  alb_target_group_blue  = module.alb_service.gateway_tg_blue_arn_test
  alb_target_group_green = module.alb_service.gateway_tg_green_arn_test
  ecr_image = "nginx"
  image_tag = "alpine"
  container_port = 80
  cluster_name = aws_ecs_cluster.come2us.name
  region = var.region
  active_color = var.active_color
  warmup_color = var.warmup_color
}

# module "ecs_gateway" {
#   source                 = "./modules/ecs"
#   prefix                 = "${var.prefix}-gateway"
#   subnets                = module.network.private_subnet_ids
#   backend_sg_id          = module.sg.backend_sg_id
#   alb_target_group_blue  = module.alb_service.gateway_tg_blue_arn
#   alb_target_group_green = module.alb_service.gateway_tg_green_arn
#   ecr_image              = "${var.ecr_uri}-gateway"
#   image_tag              = var.image_tag
#   cluster_name           = aws_ecs_cluster.come2us.name
#   active_color           = var.active_color
# }

# module "ecs_eureka" {
#   source                 = "./modules/ecs"
#   prefix                 = "${var.prefix}-eureka"
#   subnets                = module.network.private_subnet_ids
#   backend_sg_id          = module.sg.backend_sg_id
#   alb_target_group_blue  = module.alb_service.eureka_tg_blue_arn
#   alb_target_group_green = module.alb_service.eureka_tg_green_arn
#   ecr_image              = "${var.ecr_uri}-eureka"
#   image_tag              = var.image_tag
#   cluster_name           = aws_ecs_cluster.come2us.name
#   active_color           = var.active_color
# }

# module "ecs_config_server" {
#   source        = "./modules/ecs"
#   prefix        = "${var.prefix}-config"
#   subnets       = module.network.private_subnet_ids
#   backend_sg_id = module.sg.backend_sg_id
#   ecr_image     = "${var.ecr_uri}-config"
#   image_tag     = var.image_tag
#   cluster_name  = aws_ecs_cluster.come2us.name
#   active_color  = var.active_color

#   alb_target_group_blue  = ""
#   alb_target_group_green = ""
# }

# module "ecs_product" {
#   source        = "./modules/ecs"
#   prefix        = "${var.prefix}-product"
#   subnets       = module.network.private_subnet_ids
#   backend_sg_id = module.sg.backend_sg_id
#   ecr_image     = "${var.ecr_uri}-product"
#   image_tag     = var.image_tag
#   cluster_name  = aws_ecs_cluster.come2us.name
#   active_color  = var.active_color

#   alb_target_group_blue  = ""
#   alb_target_group_green = ""
# }

# module "ecs_member" {
#   source        = "./modules/ecs"
#   prefix        = "${var.prefix}-member"
#   subnets       = module.network.private_subnet_ids
#   backend_sg_id = module.sg.backend_sg_id
#   ecr_image     = "${var.ecr_uri}-member"
#   image_tag     = var.image_tag
#   cluster_name  = aws_ecs_cluster.come2us.name
#   active_color  = var.active_color

#   alb_target_group_blue  = ""
#   alb_target_group_green = ""
# }

# module "ecs_order" {
#   source        = "./modules/ecs"
#   prefix        = "${var.prefix}-order"
#   subnets       = module.network.private_subnet_ids
#   backend_sg_id = module.sg.backend_sg_id
#   ecr_image     = "${var.ecr_uri}-order"
#   image_tag     = var.image_tag
#   cluster_name  = aws_ecs_cluster.come2us.name
#   active_color  = var.active_color

#   alb_target_group_blue  = ""
#   alb_target_group_green = ""
# }

# module "ecs_payment" {
#   source        = "./modules/ecs"
#   prefix        = "${var.prefix}-payment"
#   subnets       = module.network.private_subnet_ids
#   backend_sg_id = module.sg.backend_sg_id
#   ecr_image     = "${var.ecr_uri}-payment"
#   image_tag     = var.image_tag
#   cluster_name  = aws_ecs_cluster.come2us.name
#   active_color  = var.active_color

#   alb_target_group_blue  = ""
#   alb_target_group_green = ""
# }

# module "ecs_ai" {
#   source        = "./modules/ecs"
#   prefix        = "${var.prefix}-ai"
#   subnets       = module.network.private_subnet_ids
#   backend_sg_id = module.sg.backend_sg_id
#   ecr_image     = "${var.ecr_uri}-ai"
#   image_tag     = var.image_tag
#   cluster_name  = aws_ecs_cluster.come2us.name
#   active_color  = var.active_color

#   alb_target_group_blue  = ""
#   alb_target_group_green = ""
# }