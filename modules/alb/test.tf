resource "aws_lb" "service_test" {
  name               = "${var.prefix}-service-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.alb_sg_id]
  subnets            = var.subnet_ids

  enable_deletion_protection = false

  tags = {
    Name = "${var.prefix}-service-alb"
  }
}

# Gateway
resource "aws_lb_target_group" "gateway_blue_test" {
  name     = "${var.prefix}-gateway-blue-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id
  target_type = "ip"

  deregistration_delay = 10

  health_check {
    path                = "/"
    interval            = 6
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
    matcher             = "200-399"
  }
}

resource "aws_lb_target_group" "gateway_green_test" {
  name     = "${var.prefix}-gateway-green-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id
  target_type = "ip"

  deregistration_delay = 10

  health_check {
    path                = "/"
    interval            = 6
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
    matcher             = "200-399"
  }
}

# ALB Listener (HTTP 80)
resource "aws_lb_listener" "http_test" {
  load_balancer_arn = aws_lb.service_test.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "forward"
    target_group_arn = (
      var.active_color == "blue"
      ? aws_lb_target_group.gateway_blue_test.arn
      : aws_lb_target_group.gateway_green_test.arn
    )
  }

  depends_on = [
    aws_lb_target_group.gateway_blue_test,
    aws_lb_target_group.gateway_green_test
  ]
}

resource "aws_lb_listener" "http_dummy" {
  load_balancer_arn = aws_lb.service_test.arn
  port              = 81
  protocol          = "HTTP"

  default_action {
    type = "forward"
    forward {
      target_group {
        arn = aws_lb_target_group.gateway_blue_test.arn
        weight = 1
      }
      target_group {
        arn = aws_lb_target_group.gateway_green_test.arn
        weight = 1
      }
    }
  }

  depends_on = [
    aws_lb_target_group.gateway_blue_test,
    aws_lb_target_group.gateway_green_test
  ]
}

variable "active_color" {
    type = string
}

output "service_test_alb_dns" {
  value = aws_lb.service_test.dns_name
}

output "gateway_tg_blue_arn_test" {
  value = aws_lb_target_group.gateway_blue_test.arn
}

output "gateway_tg_green_arn_test" {
  value = aws_lb_target_group.gateway_green_test.arn
}