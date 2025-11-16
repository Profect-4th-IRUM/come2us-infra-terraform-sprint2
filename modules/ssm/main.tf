resource "aws_ssm_parameter" "this" {
  for_each = var.parameters

  name        = each.key
  type        = "SecureString"
  value       = each.value
  description = "Parameter for ECS services"
}
