output "ecs_service_blue" {
  value = aws_ecs_service.blue.name
}

output "ecs_service_green" {
  value = aws_ecs_service.green.name
}

output "ecs_task_blue_family" {
  value = aws_ecs_task_definition.blue.family
}

output "ecs_task_green_family" {
  value = aws_ecs_task_definition.green.family
}