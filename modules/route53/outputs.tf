output "name_servers" {
  description = "The name servers assigned by Route53"
  value       = aws_route53_zone.main.name_servers
}