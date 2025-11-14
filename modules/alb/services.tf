resource "aws_lb" "service" {
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
resource "aws_lb_target_group" "gateway_blue" {
  name        = "${var.prefix}-gateway-blue-tg"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  deregistration_delay = 10

  health_check {
    path                = "/actuator/health"
    interval            = 10
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
    matcher             = "200-399"
  }
}

resource "aws_lb_target_group" "gateway_green" {
  name        = "${var.prefix}-gateway-green-tg"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  deregistration_delay = 10

  health_check {
    path                = "/actuator/health"
    interval            = 10
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
    matcher             = "200-399"
  }
}

# Eureka
# resource "aws_lb_target_group" "eureka_blue" {
#   name     = "${var.prefix}-eureka-blue-tg"
#   port     = 8761
#   protocol = "HTTP"
#   vpc_id   = var.vpc_id
#   target_type = "ip"

#   health_check {
#     path = "/eureka/apps"
#   }
# }

# resource "aws_lb_target_group" "eureka_green" {
#   name     = "${var.prefix}-eureka-green-tg"
#   port     = 8761
#   protocol = "HTTP"
#   vpc_id   = var.vpc_id
#   target_type = "ip"

#   health_check {
#     path = "/eureka/apps"
#   }
# }

###### HTTP 80 (DEV)
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.service.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "forward"
    target_group_arn = (
      var.active_color == "blue"
      ? aws_lb_target_group.gateway_blue.arn
      : aws_lb_target_group.gateway_green.arn
    )
  }

  depends_on = [
    aws_lb_target_group.gateway_blue,
    aws_lb_target_group.gateway_green
  ]
}

resource "aws_lb_listener" "http_dummy" {
  load_balancer_arn = aws_lb.service.arn
  port              = 81
  protocol          = "HTTP"

  default_action {
    type = "forward"
    forward {
      target_group {
        arn    = aws_lb_target_group.gateway_blue.arn
        weight = 1
      }
      target_group {
        arn    = aws_lb_target_group.gateway_green.arn
        weight = 1
      }
    }
  }

  depends_on = [
    aws_lb_target_group.gateway_blue,
    aws_lb_target_group.gateway_green
  ]
}
