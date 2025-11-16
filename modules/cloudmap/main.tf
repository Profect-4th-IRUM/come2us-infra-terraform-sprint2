resource "aws_service_discovery_private_dns_namespace" "namespace" {
  name        = "${var.prefix}.local"
  description = "Service discovery namespace"
  vpc         = var.vpc_id
}

resource "aws_service_discovery_service" "services" {
  for_each = var.services

  name = each.key

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.namespace.id

    dns_records {
      ttl  = 10
      type = "A"
    }

    routing_policy = "MULTIVALUE"
  }
}
