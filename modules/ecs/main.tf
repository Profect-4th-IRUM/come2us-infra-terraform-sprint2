resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/ecs/${var.container_name}"
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
    image_tag      = var.image_tag_blue
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
    image_tag      = var.image_tag_green
    log_group      = aws_cloudwatch_log_group.ecs.name
    region         = var.region
    container_port = var.container_port

    profile = local.profile
    config_server_url = local.config_server_url
    eureka_host = local.eureka_host
    eureka_port = local.eureka_port
  })
}

resource "aws_ecs_task_definition" "blue" {
  family                   = "${var.prefix}-task-blue"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "512"
  memory                   = "1024"
  execution_role_arn       = var.execution_role_arn
  task_role_arn            = var.task_role_arn
  container_definitions    = local.task_def_blue
}

resource "aws_ecs_task_definition" "green" {
  family                   = "${var.prefix}-task-green"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "512"
  memory                   = "1024"
  execution_role_arn       = var.execution_role_arn
  task_role_arn            = var.task_role_arn
  container_definitions    = local.task_def_green
}

# Blue Service
resource "aws_ecs_service" "blue" {
  name            = "${var.prefix}-blue"
  cluster         = var.cluster_name
  task_definition = aws_ecs_task_definition.blue.arn
  launch_type     = "FARGATE"

  desired_count = (
    var.active_color == "blue" || var.warmup_color == "blue"
  ) ? 2 : 0

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
  launch_type     = "FARGATE"

  desired_count = (
    var.active_color == "green" || var.warmup_color == "green"
  ) ? 2 : 0

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

  deployment_controller {
    type = "ECS"
  }

  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200
  health_check_grace_period_seconds  = 60

  depends_on = [aws_ecs_task_definition.green]
}
