packer {
  required_plugins {
    amazon = {
      source  = "github.com/hashicorp/amazon"
      version = ">= 1.2.0"
    }
  }
}

variable "region" {
  default = "ap-northeast-2"
}

variable "ami_name" {
  type    = string
  default = "docker-ubuntu"
}

source "amazon-ebs" "docker_ubuntu" {
  profile                     = "come2us"
  region                      = var.region
  instance_type               = "t3.small"
  ssh_username                = "ubuntu"
  ami_name                    = "${var.ami_name}"
  ami_description             = "Ubuntu 22.04 LTS with Docker preinstalled"
  associate_public_ip_address = true

  source_ami_filter {
    filters = {
      name                = "ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    owners      = ["099720109477"] # Canonical
    most_recent = true
  }

  tags = {
    Name = "docker-ubuntu-base"
  }
}

build {
  name    = "docker-ubuntu"
  sources = ["source.amazon-ebs.docker_ubuntu"]

  provisioner "shell" {
    inline = [
      "sudo rm -rf /var/lib/apt/lists/*",
      "sudo mkdir -p /var/lib/apt/lists/partial",
      "sudo apt-get clean",
      "sudo apt-get update -y -o Acquire::CompressionTypes::Order::=gz",
      "sudo DEBIAN_FRONTEND=noninteractive apt-get install -y apt-transport-https ca-certificates curl software-properties-common",
      "curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -",
      "sudo add-apt-repository \"deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable\"",
      "sudo apt-get update -y",
      "sudo DEBIAN_FRONTEND=noninteractive apt-get install -y docker-ce docker-ce-cli containerd.io",
      "sudo systemctl enable docker",
      "sudo usermod -aG docker ubuntu",
      "sudo systemctl start docker"
    ]
  }
}