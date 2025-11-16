output "namespace_id" {
  value = aws_service_discovery_private_dns_namespace.namespace.id
}

output "namespace_name" {
  value = aws_service_discovery_private_dns_namespace.namespace.name
}

output "service_arns" {
  value = {
    for k, v in aws_service_discovery_service.services :
    k => v.arn
  }
}

output "service_names" {
  value = {
    for k, v in aws_service_discovery_service.services :
    k => v.name
  }
}
