# Jenkins ALB
output "jenkins_alb_dns" {
  value = aws_lb.jenkins.dns_name
}

output "jenkins_tg_arn" {
  value = aws_lb_target_group.jenkins.arn
}

# Service ALB
output "service_alb_dns" {
  value = aws_lb.service.dns_name
}

# Gateway TGs
output "gateway_tg_blue_arn" {
  value = aws_lb_target_group.gateway_blue.arn
}

output "gateway_tg_green_arn" {
  value = aws_lb_target_group.gateway_green.arn
}

# Eureka TGs
output "eureka_tg_blue_arn" {
  value = aws_lb_target_group.eureka_blue.arn
}

output "eureka_tg_green_arn" {
  value = aws_lb_target_group.eureka_green.arn
}
