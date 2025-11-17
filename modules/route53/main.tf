resource "aws_route53_zone" "main" {
  name = var.domain_name

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_route53_record" "api" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "api.${var.domain_name}"
  type    = "A"

  alias {
    name                   = var.service_alb_dns_name
    zone_id                = var.service_alb_zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "jenkins" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "jenkins.${var.domain_name}"
  type    = "A"

  alias {
    name                   = var.jenkins_alb_dns_name
    zone_id                = var.jenkins_alb_zone_id
    evaluate_target_health = true
  }
}