# ========== Jenkins Data Volume ==========
# 기존 EBS 볼륨이 있을 경우
data "aws_ebs_volumes" "existing" {
  filter {
    name   = "tag:Name"
    values = ["${var.prefix}-jenkins-data"]
  }

  filter {
    name   = "availability-zone"
    values = [var.az]
  }
}

locals {
  existing_volume_ids = try(data.aws_ebs_volumes.existing.ids, [])
}

# 기존 EBS 볼륨이 없을 경우에만 생성
resource "aws_ebs_volume" "data" {
  count             = length(local.existing_volume_ids) > 0 ? 0 : 1
  availability_zone = var.az
  size              = var.jenkins_ebs_size
  type              = var.jenkins_ebs_type
  iops              = var.jenkins_ebs_iops
  throughput        = var.jenkins_ebs_throughput

  tags = {
    Name = "${var.prefix}-jenkins-data"
  }

  lifecycle {
    prevent_destroy = true
  }
}

# Volume ID 결정 (기존 → 신규 순)
locals {
  jenkins_volume_id = coalesce(
    try(local.existing_volume_ids[0], null),
    try(aws_ebs_volume.data[0].id, null)
  )
}

# ========== Docker Volume ==========
data "aws_ebs_volumes" "docker_existing" {
  filter {
    name   = "tag:Name"
    values = ["${var.prefix}-docker-data"]
  }

  filter {
    name   = "availability-zone"
    values = [var.az]
  }
}

locals {
  docker_existing_ids = try(data.aws_ebs_volumes.docker_existing.ids, [])
}

resource "aws_ebs_volume" "docker" {
  count             = length(local.docker_existing_ids) > 0 ? 0 : 1
  availability_zone = var.az

  size       = var.docker_ebs_size
  type       = var.docker_ebs_type
  iops       = var.docker_ebs_iops
  throughput = var.docker_ebs_throughput

  tags = {
    Name = "${var.prefix}-docker-data"
  }

  lifecycle {
    prevent_destroy = true
  }
}

locals {
  docker_volume_id = coalesce(
    try(local.docker_existing_ids[0], null),
    try(aws_ebs_volume.docker[0].id, null)
  )
}

# ========== Instance ==========
resource "aws_instance" "this" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = [var.sg_id]
  associate_public_ip_address = false
  key_name                    = var.key_name

  user_data = templatefile("${path.module}/scripts/jenkins-userdata.tpl.sh", {
    jenkins_volume_id = local.jenkins_volume_id
    docker_volume_id  = local.docker_volume_id
  })

  tags = {
    Name = "${var.prefix}-jenkins"
  }

  root_block_device {
    volume_type = "gp3"
    volume_size = 20
    iops        = 3000
    throughput  = 125
  }
}

resource "aws_volume_attachment" "jenkins" {
  device_name  = "/dev/sdf"
  volume_id    = local.jenkins_volume_id
  instance_id  = aws_instance.this.id
  force_detach = true

  lifecycle {
    ignore_changes = [volume_id]
  }
}

resource "aws_volume_attachment" "docker" {
  device_name  = "/dev/sdg"
  volume_id    = local.docker_volume_id
  instance_id  = aws_instance.this.id
  force_detach = true

  lifecycle {
    ignore_changes = [volume_id]
  }
}
