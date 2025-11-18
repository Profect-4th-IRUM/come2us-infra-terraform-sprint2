variable "ami_id" {}
variable "instance_type" {}
variable "subnet_id" {}
variable "vpc_id" {}
variable "key_name" {}
variable "sg_id" {}
variable "az" {}
variable "prefix" {}
variable "jenkins_ebs_size" { default = 50 }
variable "jenkins_ebs_iops" { default = 3000 }
variable "jenkins_ebs_throughput" { default = 125 }
variable "jenkins_ebs_type" { default = "gp3" }
variable "docker_ebs_size" { default = 50 }
variable "docker_ebs_iops" { default = 6000 }
variable "docker_ebs_throughput" { default = 125 }
variable "docker_ebs_type" { default = "gp3" }