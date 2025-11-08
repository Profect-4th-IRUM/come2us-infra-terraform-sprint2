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
  name     = "${var.prefix}-gateway-blue-tg"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    path = "/actuator/health"
  }
}

resource "aws_lb_target_group" "gateway_green" {
  name     = "${var.prefix}-gateway-green-tg"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    path = "/actuator/health"
  }
}

# Eureka
resource "aws_lb_target_group" "eureka_blue" {
  name     = "${var.prefix}-eureka-blue-tg"
  port     = 8761
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    path = "/eureka/apps"
  }
}

resource "aws_lb_target_group" "eureka_green" {
  name     = "${var.prefix}-eureka-green-tg"
  port     = 8761
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    path = "/eureka/apps"
  }
}

###### HTTP 80 (DEV)
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.service.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.gateway_blue.arn
  }
}

resource "aws_lb_listener_rule" "eureka_rule" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 10

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.eureka_blue.arn
  }

  condition {
    path_pattern {
      values = ["/eureka/*"]
    }
  }
}

resource "aws_lb_listener_rule" "gateway_rule" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 20

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.gateway_blue.arn
  }

  condition {
    path_pattern {
      values = ["/*"]
    }
  }
}

###### HTTPS 443 (PROD)
# resource "aws_lb_listener" "https" {
#   count = var.acm_certificate_arn != null ? 1 : 0

#   load_balancer_arn = aws_lb.service.arn
#   port              = 443
#   protocol          = "HTTPS"
#   ssl_policy        = "ELBSecurityPolicy-2016-08"
#   certificate_arn   = var.acm_certificate_arn

#   default_action {
#     type             = "forward"
#     target_group_arn = aws_lb_target_group.gateway_blue.arn
#   }
# }

# resource "aws_lb_listener_rule" "eureka_rule" {
#   listener_arn = aws_lb_listener.https.arn
#   priority     = 10

#   action {
#     type             = "forward"
#     target_group_arn = aws_lb_target_group.eureka_blue.arn
#   }

#   condition {
#     path_pattern {
#       values = ["/eureka/*"]
#     }
#   }
# }

# resource "aws_lb_listener_rule" "gateway_rule" {
#   listener_arn = aws_lb_listener.https.arn
#   priority     = 20

#   action {
#     type             = "forward"
#     target_group_arn = aws_lb_target_group.gateway_blue.arn
#   }

#   condition {
#     path_pattern {
#       values = ["/*"]
#     }
#   }
# }
