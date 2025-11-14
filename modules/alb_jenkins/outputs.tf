# Jenkins ALB
output "jenkins_alb_dns" {
  value = aws_lb.this.dns_name
}

output "jenkins_tg_arn" {
  value = aws_lb_target_group.this.arn
}
