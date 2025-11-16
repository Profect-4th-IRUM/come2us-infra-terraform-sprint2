# CloudWatch
resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/ecs/${var.container_name}"
  retention_in_days = 30
}

locals {
  profile           = var.profile_active
  config_server_url = var.config_server_host != "" ? "http://${var.config_server_host}:${var.config_server_port}" : ""

  task_def = templatefile("${path.module}/task-definition.json", {
    container_name    = var.container_name
    ecr_image         = var.ecr_image
    image_tag         = var.image_tag
    log_group         = aws_cloudwatch_log_group.ecs.name
    region            = var.region
    container_port    = var.container_port

    profile           = local.profile
    config_server_url = local.config_server_url
  })
}

resource "aws_ecs_task_definition" "this" {
  family                   = "${var.prefix}-task"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "512"
  memory                   = "1024"
  execution_role_arn       = var.execution_role_arn
  task_role_arn            = var.task_role_arn
  container_definitions    = local.task_def
}

resource "aws_ecs_service" "this" {
  name            = "${var.prefix}-svc"
  cluster         = var.cluster_name
  task_definition = aws_ecs_task_definition.this.arn
  launch_type     = "FARGATE"
  desired_count   = var.desired_count

  network_configuration {
    subnets          = var.subnets
    security_groups  = [var.backend_sg_id]
    assign_public_ip = var.assign_public_ip
  }

  # Cloud Map
  dynamic "service_registries" {
    for_each = var.service_discovery_arn != "" ? [1] : []
    content {
      registry_arn = var.service_discovery_arn
    }
  }

  deployment_controller {
    type = "ECS"
  }

  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200
  health_check_grace_period_seconds  = 60

  depends_on = [aws_ecs_task_definition.this]
}