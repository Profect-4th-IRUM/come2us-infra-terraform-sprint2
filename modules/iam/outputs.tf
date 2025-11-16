output "task_execution_role_arn" {
  value = aws_iam_role.ecs_task_exec.arn
}

output "task_role_arn" {
  value = aws_iam_role.ecs_task_exec.arn
}
