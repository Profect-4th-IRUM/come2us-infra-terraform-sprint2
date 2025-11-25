resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/ecs/${var.service_name}"
  retention_in_days = 7
}

locals {
  container_def_base = jsonencode([
    {
      name      = var.service_name
      image     = "__IMAGE__"
      essential = true

      portMappings = [{
        containerPort = var.container_port
        hostPort      = var.container_port
        protocol      = "tcp"
      }]

      environment = [
        for k, v in var.environment :
        {
          name  = k
          value = v
        }
      ]

      secrets = [
        for key, arn in var.ssm_parameters :
        {
          name      = key
          valueFrom = arn
        }
      ]

      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:${var.container_port}/actuator/health || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 30
      }

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.ecs.name
          awslogs-region        = var.region
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  ])
}

resource "aws_ecs_task_definition" "blue" {
  family                   = "${var.service_name}-blue"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.cpu
  memory                   = var.memory

  task_role_arn            = var.task_role_arn
  execution_role_arn       = var.execution_role_arn

  container_definitions    = replace(
    local.container_def_base,
    "__IMAGE__",
    "${var.ecr_image}:${var.image_tag_blue}"
  )
}

resource "aws_ecs_task_definition" "green" {
  family                   = "${var.service_name}-green"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.cpu
  memory                   = var.memory

  task_role_arn            = var.task_role_arn
  execution_role_arn       = var.execution_role_arn

  container_definitions    = replace(
    local.container_def_base,
    "__IMAGE__",
    "${var.ecr_image}:${var.image_tag_green}"
  )
}

# Blue Service
resource "aws_ecs_service" "blue" {
  name            = "${var.service_name}-blue"
  cluster         = var.cluster_name
  task_definition = aws_ecs_task_definition.blue.arn
  launch_type     = "FARGATE"

  desired_count = (
    var.active_color == "blue" || var.warmup_color == "blue"
  ) ? 2 : 0

  network_configuration {
    subnets          = var.subnets
    security_groups  = [var.security_group_id]
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
  name            = "${var.service_name}-green"
  cluster         = var.cluster_name
  task_definition = aws_ecs_task_definition.green.arn
  launch_type     = "FARGATE"

  desired_count = (
    var.active_color == "green" || var.warmup_color == "green"
  ) ? 2 : 0

  network_configuration {
    subnets          = var.subnets
    security_groups  = [var.security_group_id]
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
