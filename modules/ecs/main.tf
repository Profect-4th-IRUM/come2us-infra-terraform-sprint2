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
  profile = var.profile_active
  config_server_url = "http://${var.config_server_host}:${var.config_server_port}"
  eureka_host = var.eureka_host
  eureka_port = var.eureka_port

  task_def_blue = templatefile("${path.module}/task-definition-blue.json", {
    container_name = var.container_name
    ecr_image      = var.ecr_image
    image_tag      = var.image_tag
    log_group      = aws_cloudwatch_log_group.ecs.name
    region         = var.region
    container_port = var.container_port

    profile = local.profile
    config_server_url = local.config_server_url
    eureka_host = local.eureka_host
    eureka_port = local.eureka_port
  })

  task_def_green = templatefile("${path.module}/task-definition-green.json", {
    container_name = var.container_name
    ecr_image      = var.ecr_image
    image_tag      = var.image_tag
    log_group      = aws_cloudwatch_log_group.ecs.name
    region         = var.region
    container_port = var.container_port

    profile = local.profile
    config_server_url = local.config_server_url
    eureka_host = local.eureka_host
    eureka_port = local.eureka_port
  })
}

resource "aws_ecs_task_definition" "app" {
  family                   = "${var.prefix}-task"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "512"
  memory                   = "1024"
  execution_role_arn       = aws_iam_role.ecs_task_exec.arn
  task_role_arn            = aws_iam_role.ecs_task_exec.arn
  container_definitions    = local.task_def
}

# Blue Service
resource "aws_ecs_service" "blue" {
  name            = "${var.prefix}-blue"
  cluster         = var.cluster_name
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = var.active_color == "blue" ? 2 : 0
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.subnets
    security_groups  = [var.backend_sg_id]
    assign_public_ip = false
  }

  dynamic "service_registries" {
    for_each = var.service_discovery_arn != "" ? [1] : []
    content {
      registry_arn = var.service_discovery_arn
    }
  }

  dynamic "load_balancer" {
    for_each = var.alb_target_group_blue != null ? [1] : []
    content {
      target_group_arn = var.alb_target_group_blue
      container_name   = var.container_name
      container_port   = var.container_port
    }
  }

  lifecycle {
    ignore_changes = [desired_count]
  }

  depends_on = [aws_ecs_task_definition.app]
}

# Green Service
resource "aws_ecs_service" "green" {
  name            = "${var.prefix}-green"
  cluster         = var.cluster_name
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = var.active_color == "green" ? 2 : 0
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.subnets
    security_groups  = [var.backend_sg_id]
    assign_public_ip = false
  }

  dynamic "service_registries" {
    for_each = var.service_discovery_arn != "" ? [1] : []
    content {
      registry_arn = var.service_discovery_arn
    }
  }

  dynamic "load_balancer" {
    for_each = var.alb_target_group_green != null ? [1] : []
    content {
      target_group_arn = var.alb_target_group_green
      container_name   = var.container_name
      container_port   = var.container_port
    }
  }

  lifecycle {
    ignore_changes = [desired_count]
  }

  depends_on = [aws_ecs_task_definition.app]
}
