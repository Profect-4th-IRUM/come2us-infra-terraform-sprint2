resource "aws_iam_role" "ecs_task_exec" {
  name = "${var.prefix}-ecsTaskExecutionRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Principal = { Service = "ecs-tasks.amazonaws.com" },
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_exec_policy" {
  role       = aws_iam_role.ecs_task_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_policy" "ecs_task_exec_ssm_policy" {
  name        = "${var.prefix}-ecsTaskExecutionRole-SSM"
  description = "Allow ECS tasks to fetch SSM parameters"

  policy = file("${path.module}/policies/ecs_task_execution_role.json")
}

resource "aws_iam_role_policy_attachment" "ecs_exec_ssm_policy_attach" {
  role       = aws_iam_role.ecs_task_exec.name
  policy_arn = aws_iam_policy.ecs_task_exec_ssm_policy.arn
}

resource "aws_iam_role" "ecs_task" {
  name = "${var.prefix}-ecsTaskRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Principal = { Service = "ecs-tasks.amazonaws.com" },
      Action    = "sts:AssumeRole"
    }]
  })
}

# resource "aws_iam_policy" "ecs_task_policy" {
#   name   = "${var.prefix}-ecsTaskRole-Policy"
#   policy = file("${path.module}/policies/ecs_task_role.json")
# }

# resource "aws_iam_role_policy_attachment" "ecs_task_policy_attach" {
#   role       = aws_iam_role.ecs_task.name
#   policy_arn = aws_iam_policy.ecs_task_policy.arn
# }
