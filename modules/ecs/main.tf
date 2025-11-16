resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/ecs/${var.container_name}"
  retention_in_days = 30
}

locals {
  profile           = var.profile_active
  config_server_url = "http://${var.config_server_host}:${var.config_server_port}"
  eureka_host       = var.eureka_host
  eureka_port       = tostring(var.eureka_port)

  secrets_list = [
    for key, arn in var.ssm_parameters :
    {
      name      = key
      valueFrom = arn
    }
  ]

  # BLUE TASK DEF
  container_blue = [
    {
      name      = var.container_name
      image     = "${var.ecr_image}:${var.image_tag_blue}"
      essential = true

      portMappings = [{
        containerPort = var.container_port
        hostPort      = var.container_port
      }]

      environment = [
        { name = "PROFILE_ACTIVE", value = local.profile },
        { name = "CONFIG_SERVER_URL", value = local.config_server_url },
        { name = "EUREKA_HOST", value = local.eureka_host },
        { name = "EUREKA_PORT", value = local.eureka_port }
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

  container_blue_json = jsonencode(local.container_blue)

  # GREEN TASK DEF
  container_green = [
    {
      name      = var.container_name
      image     = "${var.ecr_image}:${var.image_tag_green}"
      essential = true

      portMappings = [{
        containerPort = var.container_port
        hostPort      = var.container_port
      }]

      environment = [
        { name = "PROFILE_ACTIVE", value = local.profile },
        { name = "CONFIG_SERVER_URL", value = local.config_server_url },
        { name = "EUREKA_HOST", value = local.eureka_host },
        { name = "EUREKA_PORT", value = local.eureka_port }
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

  container_green_json = jsonencode(local.container_green)
}

resource "aws_ecs_task_definition" "blue" {
  family                   = "${var.prefix}-task-blue"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "512"
  memory                   = "1024"
  execution_role_arn       = var.execution_role_arn
  task_role_arn            = var.task_role_arn
  container_definitions    = local.container_blue_json
}

resource "aws_ecs_task_definition" "green" {
  family                   = "${var.prefix}-task-green"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "512"
  memory                   = "1024"
  execution_role_arn       = var.execution_role_arn
  task_role_arn            = var.task_role_arn
  container_definitions    = local.container_green_json
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
