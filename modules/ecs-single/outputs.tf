output "ecs_service_name" {
  description = "ECS service name"
  value       = aws_ecs_service.this.name
}

output "ecs_task_family" {
  description = "ECS task definition family"
  value       = aws_ecs_task_definition.this.family
}

output "ecs_task_arn" {
  description = "ECS task definition ARN"
  value       = aws_ecs_task_definition.this.arn
}
