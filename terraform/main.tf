data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_vpc" "existing" {
  count = var.use_existing_network ? 1 : 0

  filter {
    name   = "tag:Name"
    values = [var.vpc_name]
  }
}

data "aws_subnet" "existing_public_1" {
  count = var.use_existing_network ? 1 : 0

  filter {
    name   = "tag:Name"
    values = [var.existing_public_subnet_1_name]
  }
}

data "aws_subnet" "existing_public_2" {
  count = var.use_existing_network ? 1 : 0

  filter {
    name   = "tag:Name"
    values = [var.existing_public_subnet_2_name]
  }
}

data "aws_subnet" "existing_private_1" {
  count = var.use_existing_network ? 1 : 0

  filter {
    name   = "tag:Name"
    values = [var.existing_private_subnet_1_name]
  }
}

data "aws_subnet" "existing_private_2" {
  count = var.use_existing_network ? 1 : 0

  filter {
    name   = "tag:Name"
    values = [var.existing_private_subnet_2_name]
  }
}

data "aws_security_group" "existing_alb" {
  count = var.use_existing_network ? 1 : 0

  name   = var.alb_security_group_name
  vpc_id = data.aws_vpc.existing[0].id
}

data "aws_security_group" "existing_task" {
  count = var.use_existing_network ? 1 : 0

  name   = var.task_security_group_name
  vpc_id = data.aws_vpc.existing[0].id
}

data "aws_lb" "existing" {
  count = var.use_existing_network ? 1 : 0

  name = var.alb_name
}

data "aws_lb_target_group" "existing" {
  count = var.use_existing_network ? 1 : 0

  name = var.target_group_name
}

resource "aws_vpc" "main" {
  count = var.use_existing_network ? 0 : 1

  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(local.common_tags, {
    Name = var.vpc_name
  })
}

resource "aws_internet_gateway" "main" {
  count = var.use_existing_network ? 0 : 1

  vpc_id = aws_vpc.main[0].id

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-igw"
  })
}

resource "aws_subnet" "public" {
  count = var.use_existing_network ? 0 : length(local.availability_zones)

  vpc_id                  = aws_vpc.main[0].id
  cidr_block              = cidrsubnet(var.vpc_cidr, 4, count.index)
  availability_zone       = local.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-public-${count.index + 1}"
    Tier = "public"
  })
}

resource "aws_subnet" "private" {
  count = var.use_existing_network ? 0 : length(local.availability_zones)

  vpc_id            = aws_vpc.main[0].id
  cidr_block        = cidrsubnet(var.vpc_cidr, 4, count.index + 8)
  availability_zone = local.availability_zones[count.index]

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-private-${count.index + 1}"
    Tier = "private"
  })
}

resource "aws_eip" "nat" {
  count = var.use_existing_network || !var.create_nat_gateway ? 0 : 1

  domain = "vpc"

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-nat-eip"
  })
}

resource "aws_nat_gateway" "main" {
  count = var.use_existing_network || !var.create_nat_gateway ? 0 : 1

  allocation_id = aws_eip.nat[0].id
  subnet_id     = aws_subnet.public[0].id

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-nat"
  })

  depends_on = [aws_internet_gateway.main]
}

resource "aws_route_table" "public" {
  count = var.use_existing_network ? 0 : 1

  vpc_id = aws_vpc.main[0].id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main[0].id
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-public-rt"
  })
}

resource "aws_route_table_association" "public" {
  count = var.use_existing_network ? 0 : length(aws_subnet.public)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public[0].id
}

resource "aws_route_table" "private" {
  count = var.use_existing_network ? 0 : 1

  vpc_id = aws_vpc.main[0].id

  dynamic "route" {
    for_each = var.create_nat_gateway ? [1] : []

    content {
      cidr_block     = "0.0.0.0/0"
      nat_gateway_id = aws_nat_gateway.main[0].id
    }
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-private-rt"
  })
}

resource "aws_route_table_association" "private" {
  count = var.use_existing_network ? 0 : length(aws_subnet.private)

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[0].id
}

resource "aws_security_group" "alb" {
  count = var.use_existing_network ? 0 : 1

  name        = var.alb_security_group_name
  description = "Allow public HTTP access to the ALB"
  vpc_id      = aws_vpc.main[0].id

  ingress {
    description = "HTTP from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.allowed_http_cidr_blocks
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = var.alb_security_group_name
  })
}

resource "aws_security_group" "task" {
  count = var.use_existing_network ? 0 : 1

  name        = var.task_security_group_name
  description = "Allow ALB traffic to ECS tasks"
  vpc_id      = aws_vpc.main[0].id

  ingress {
    description     = "HTTP from ALB"
    from_port       = var.container_port
    to_port         = var.container_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb[0].id]
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = var.task_security_group_name
  })
}

resource "aws_lb" "main" {
  count = var.use_existing_network ? 0 : 1

  name               = var.alb_name
  internal           = false
  load_balancer_type = "application"
  security_groups    = [local.alb_security_group_id]
  subnets            = local.public_subnet_ids

  enable_deletion_protection = var.alb_deletion_protection

  tags = merge(local.common_tags, {
    Name = var.alb_name
  })
}

resource "aws_lb_target_group" "main" {
  count = var.use_existing_network ? 0 : 1

  name        = var.target_group_name
  port        = var.container_port
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = local.vpc_id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200-399"
    path                = "/"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 2
  }

  tags = merge(local.common_tags, {
    Name = var.target_group_name
  })
}

resource "aws_lb_listener" "http" {
  count = var.use_existing_network ? 0 : 1

  load_balancer_arn = aws_lb.main[0].arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main[0].arn
  }
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
  task_role_arn            = var.ecs_task_execution_role_arn
  execution_role_arn       = var.ecs_task_execution_role_arn

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
    subnets          = local.private_subnet_ids
    security_groups  = [local.task_security_group_id]
    assign_public_ip = var.assign_public_ip
  }

  load_balancer {
    target_group_arn = local.target_group_arn
    container_name   = "nginx"
    container_port   = var.container_port
  }

  depends_on = [aws_lb_listener.http]

  tags = local.common_tags
}

resource "aws_wafv2_web_acl_association" "alb" {
  count = var.web_acl_arn == "" ? 0 : 1

  resource_arn = local.alb_arn
  web_acl_arn  = var.web_acl_arn
}
