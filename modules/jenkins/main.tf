# 기존 EBS 볼륨이 있을 경우
data "aws_ebs_volume" "existing" {
  filter {
    name   = "tag:Name"
    values = ["${var.prefix}-jenkins-data"]
  }

  filter {
    name   = "availability-zone"
    values = [var.az]
  }

  most_recent = true
}

# 기존 EBS 볼륨이 없을 경우에만 생성
resource "aws_ebs_volume" "data" {
  count             = data.aws_ebs_volume.existing.id != "" ? 0 : 1
  availability_zone = var.az
  size              = 20

  tags = {
    Name = "${var.prefix}-jenkins-data"
  }

  lifecycle {
    prevent_destroy = false
  }
}

# Volume ID 결정 (기존 → 신규 순)
locals {
  jenkins_volume_id = coalesce(
    try(data.aws_ebs_volume.existing.id, null),
    try(aws_ebs_volume.data[0].id, null)
  )
}

resource "aws_instance" "this" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = [var.sg_id]
  associate_public_ip_address = false
  key_name                    = var.key_name

  user_data = file("${path.module}/scripts/jenkins-userdata.sh")

  tags = {
    Name = "${var.prefix}-jenkins"
  }
}

resource "aws_volume_attachment" "this" {
  device_name  = "/dev/sdf"
  volume_id    = local.jenkins_volume_id
  instance_id  = aws_instance.this.id
  force_detach = true

  lifecycle {
    ignore_changes = [volume_id]
  }

  depends_on = [aws_instance.this]
}
