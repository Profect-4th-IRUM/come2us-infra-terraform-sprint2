# CloudWatch
resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/ecs/${var.container_name}"
  retention_in_days = 30
}

locals {
  config_server_url = var.config_server_host != "" ? "http://${var.config_server_host}:${var.config_server_port}" : ""

  secrets_list = [
    for key, arn in var.ssm_parameters :
    {
      name      = key
      valueFrom = arn
    }
  ]

  container_def = [
    {
      name      = var.container_name
      image     = "${var.ecr_image}:${var.image_tag}"
      essential = true

      portMappings = [{
        containerPort = var.container_port
        hostPort      = var.container_port
      }]

      environment = [
        { name = "PROFILE_ACTIVE",    value = var.profile_active },
        { name = "CONFIG_SERVER_URL", value = local.config_server_url },
        { name = "EUREKA_HOST",       value = var.eureka_host },
        { name = "EUREKA_PORT",       value = tostring(var.eureka_port) }
      ]

      secrets = local.secrets_list

      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:${var.container_port}/actuator/health || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 20
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
  ]

  container_def_json = jsonencode(local.container_def)
}

resource "aws_ecs_task_definition" "this" {
  family                   = "${var.prefix}-task"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "512"
  memory                   = "1024"
  execution_role_arn       = var.execution_role_arn
  task_role_arn            = var.task_role_arn
  container_definitions    = local.container_def_json
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