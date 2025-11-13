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

resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/ecs/${var.prefix}"
  retention_in_days = 30
}

locals {
  task_def_blue = templatefile("${path.module}/task-definition-blue.json", {
    ecr_image      = var.ecr_image
    image_tag      = var.image_tag
    log_group      = aws_cloudwatch_log_group.ecs.name
    region         = var.region
    container_port = var.container_port
    active_color = var.active_color
  })

  task_def_green = templatefile("${path.module}/task-definition-green.json", {
    ecr_image      = var.ecr_image
    image_tag      = var.image_tag
    log_group      = aws_cloudwatch_log_group.ecs.name
    region         = var.region
    container_port = var.container_port
    active_color = var.active_color
  })
}

resource "aws_ecs_task_definition" "blue" {
  family                   = "${var.prefix}-task-blue"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "512"
  memory                   = "1024"
  execution_role_arn       = aws_iam_role.ecs_task_exec.arn
  task_role_arn            = aws_iam_role.ecs_task_exec.arn
  container_definitions    = local.task_def_blue
}

resource "aws_ecs_task_definition" "green" {
  family                   = "${var.prefix}-task-green"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "512"
  memory                   = "1024"
  execution_role_arn       = aws_iam_role.ecs_task_exec.arn
  task_role_arn            = aws_iam_role.ecs_task_exec.arn
  container_definitions    = local.task_def_green
}

# Blue Service
resource "aws_ecs_service" "blue" {
  name            = "${var.prefix}-blue"
  cluster         = var.cluster_name
  task_definition = aws_ecs_task_definition.blue.arn
  desired_count   = (
    var.active_color == "blue" || var.warmup_color == "blue"
  ) ? 2 : 0
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.subnets
    security_groups  = [var.backend_sg_id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = var.alb_target_group_blue
    container_name   = "app"
    container_port   = var.container_port
  }

  deployment_controller {
    type = "ECS"
  }

  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200
  health_check_grace_period_seconds  = 60

  depends_on = [aws_ecs_task_definition.blue]
}

# Green Service
resource "aws_ecs_service" "green" {
  name            = "${var.prefix}-green"
  cluster         = var.cluster_name
  task_definition = aws_ecs_task_definition.green.arn
  desired_count   = (
    var.active_color == "green" || var.warmup_color == "green"
  ) ? 2 : 0
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.subnets
    security_groups  = [var.backend_sg_id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = var.alb_target_group_green
    container_name   = "app"
    container_port   = var.container_port
  }
  deployment_controller {
    type = "ECS"
  }

  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200
  health_check_grace_period_seconds = 60

  depends_on = [aws_ecs_task_definition.green]
}
