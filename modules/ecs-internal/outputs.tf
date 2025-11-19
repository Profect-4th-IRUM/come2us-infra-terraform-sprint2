output "blue_service_name" {
  value = aws_ecs_service.blue.name
}

output "green_service_name" {
  value = aws_ecs_service.green.name
}
