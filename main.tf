provider "aws" {
  region     = var.region
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
}

module "network" {
  source               = "./modules/network"
  vpc_cidr             = var.vpc_cidr
  azs                  = var.azs
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
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

module "alb" {
  source             = "./modules/alb"
  vpc_id             = module.network.vpc_id
  alb_sg_id          = module.sg.alb_sg_id
  subnet_ids         = module.network.public_subnet_ids
  target_instance_id = module.jenkins.instance_id
  prefix             = var.prefix
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
