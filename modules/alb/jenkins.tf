resource "aws_lb" "jenkins" {
  name               = "${var.prefix}-jenkins-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.alb_sg_id]
  subnets            = var.subnet_ids

  enable_deletion_protection = false

  tags = {
    Name = "${var.prefix}-jenkins-alb"
  }
}

resource "aws_lb_target_group" "jenkins" {
  name     = "${var.prefix}-jenkins-tg"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    path                = "/"
    port                = "8080"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    matcher             = "200-399"
  }

  tags = { Name = "${var.prefix}-jenkins-tg" }
}

resource "aws_lb_target_group_attachment" "jenkins_instance" {
  target_group_arn = aws_lb_target_group.jenkins.arn
  target_id        = var.target_instance_id
  port             = 8080
}

resource "aws_lb_listener" "jenkins_http" {
  load_balancer_arn = aws_lb.jenkins.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.jenkins.arn
  }
}
