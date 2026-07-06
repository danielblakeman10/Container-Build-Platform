data "aws_vpc" "main" {
  filter {
    name   = "tag:Name"
    values = [var.vpc_name]
  }
}

data "aws_subnet" "public_1" {
  filter {
    name   = "tag:Name"
    values = ["${var.project_name}-subnet-public1-us-east-1a"]
  }
}

data "aws_subnet" "public_2" {
  filter {
    name   = "tag:Name"
    values = ["${var.project_name}-subnet-public2-us-east-1b"]
  }
}

data "aws_subnet" "private_1" {
  filter {
    name   = "tag:Name"
    values = ["${var.project_name}-subnet-private1-us-east-1a"]
  }
}

data "aws_subnet" "private_2" {
  filter {
    name   = "tag:Name"
    values = ["${var.project_name}-subnet-private2-us-east-1b"]
  }
}

data "aws_security_group" "alb" {
  name   = var.alb_security_group_name
  vpc_id = data.aws_vpc.main.id
}

data "aws_security_group" "task" {
  name   = var.task_security_group_name
  vpc_id = data.aws_vpc.main.id
}

data "aws_lb" "main" {
  name = var.alb_name
}

data "aws_lb_target_group" "main" {
  name = var.target_group_name
}

data "aws_iam_role" "ecs_task_execution" {
  name = var.ecs_task_execution_role_name
}

data "aws_wafv2_web_acl" "alb" {
  name  = var.web_acl_name
  scope = "REGIONAL"
}

resource "aws_ecr_repository" "nginx" {
  name                 = var.ecr_repository_name
  image_tag_mutability = var.ecr_image_tag_mutability

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = local.common_tags
}

resource "aws_ecs_cluster" "main" {
  name = var.ecs_cluster_name

  configuration {
    execute_command_configuration {
      logging = "DEFAULT"
    }
  }

  setting {
    name  = "containerInsights"
    value = var.container_insights
  }

  tags = local.common_tags
}

resource "aws_cloudwatch_log_group" "nginx" {
  name              = var.log_group_name
  retention_in_days = var.log_retention_in_days

  tags = local.common_tags
}

resource "aws_ecs_task_definition" "nginx" {
  family                   = var.task_family
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  task_role_arn            = data.aws_iam_role.ecs_task_execution.arn
  execution_role_arn       = data.aws_iam_role.ecs_task_execution.arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  container_definitions = jsonencode([
    {
      name      = "nginx"
      image     = var.container_image
      essential = true

      portMappings = [
        {
          name          = "nginx-80-tcp"
          containerPort = var.container_port
          hostPort      = var.container_port
          protocol      = "tcp"
          appProtocol   = "http"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-create-group"  = "true"
          "awslogs-group"         = aws_cloudwatch_log_group.nginx.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])

  tags = local.common_tags
}

resource "aws_ecs_service" "nginx" {
  name            = var.ecs_service_name
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.nginx.arn
  desired_count   = var.desired_count

  capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = 1
    base              = 0
  }

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 100
  availability_zone_rebalancing      = "ENABLED"
  enable_ecs_managed_tags            = true
  enable_execute_command             = true
  health_check_grace_period_seconds  = 0

  network_configuration {
    subnets = [
      data.aws_subnet.private_1.id,
      data.aws_subnet.private_2.id
    ]
    security_groups  = [data.aws_security_group.task.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = data.aws_lb_target_group.main.arn
    container_name   = "nginx"
    container_port   = var.container_port
  }

  tags = local.common_tags
}

resource "aws_wafv2_web_acl_association" "alb" {
  resource_arn = data.aws_lb.main.arn
  web_acl_arn  = data.aws_wafv2_web_acl.alb.arn
}
