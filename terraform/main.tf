provider "aws" {
  region = var.aws_region
}

# VPC and Networking
resource "aws_vpc" "medusa_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "medusa-vpc"
  }
}

resource "aws_subnet" "medusa_subnet" {
  vpc_id                  = aws_vpc.medusa_vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "${var.aws_region}a"

  tags = {
    Name = "medusa-subnet"
  }
}

resource "aws_internet_gateway" "medusa_igw" {
  vpc_id = aws_vpc.medusa_vpc.id

  tags = {
    Name = "medusa-igw"
  }
}

resource "aws_route_table" "medusa_rt" {
  vpc_id = aws_vpc.medusa_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.medusa_igw.id
  }

  tags = {
    Name = "medusa-route-table"
  }
}

resource "aws_route_table_association" "medusa_rt_assoc" {
  subnet_id      = aws_subnet.medusa_subnet.id
  route_table_id = aws_route_table.medusa_rt.id
}

resource "aws_security_group" "medusa_sg" {
  name        = "medusa-security-group"
  description = "Allow traffic for Medusa application"
  vpc_id      = aws_vpc.medusa_vpc.id

  ingress {
    from_port   = 9000
    to_port     = 9000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "medusa-sg"
  }
}

# Using existing ECR repository
data "aws_ecr_repository" "medusa_repo" {
  name = "medusa-backend"
}

# ECS Cluster
resource "aws_ecs_cluster" "medusa_cluster" {
  name = "medusa-cluster"
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "medusa_logs" {
  name              = "/ecs/medusa-app"
  retention_in_days = 30
}

# IAM Roles
resource "aws_iam_role" "ecs_execution_role" {
  name = "medusa-ecs-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_execution_role_policy" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role" "ecs_task_role" {
  name = "medusa-ecs-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

# ECS Task Definition
resource "aws_ecs_task_definition" "medusa_task" {
  family                   = "medusa-task"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "2048"
  memory                   = "4096"
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name      = "postgres"
      image     = "postgres:13"
      essential = true
      environment = [
        { name = "POSTGRES_USER", value = "postgres" },
        { name = "POSTGRES_PASSWORD", value = "postgres" },
        { name = "POSTGRES_DB", value = "postgres" }
      ]
      portMappings = [
        {
          containerPort = 5432
          hostPort      = 5432
          protocol      = "tcp"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.medusa_logs.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "postgres"
        }
      }
      healthCheck = {
        command     = ["CMD-SHELL", "pg_isready -U postgres"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 10
      }
    },
    {
      name      = "redis"
      image     = "redis:6"
      essential = true
      portMappings = [
        {
          containerPort = 6379
          hostPort      = 6379
          protocol      = "tcp"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.medusa_logs.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "redis"
        }
      }
      healthCheck = {
        command     = ["CMD", "redis-cli", "ping"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 10
      }
    },
    {
      name      = "medusa-backend"
      image     = "${data.aws_ecr_repository.medusa_repo.repository_url}:latest"
      essential = true
      dependsOn = [
        {
          containerName = "postgres"
          condition     = "HEALTHY"
        },
        {
          containerName = "redis"
          condition     = "HEALTHY"
        }
      ]
      environment = [
        { name = "NODE_ENV", value = "production" },
        { name = "PORT", value = "9000" },
        { name = "JWT_SECRET", value = var.jwt_secret },
        { name = "COOKIE_SECRET", value = var.cookie_secret },
        { name = "STORE_CORS", value = var.store_cors },
        { name = "ADMIN_CORS", value = var.admin_cors },
        { name = "AUTH_CORS", value = var.auth_cors },
        { name = "ECS_CONTAINER_METADATA_URI_V4", value = "true" }
      ]
      portMappings = [
        {
          containerPort = 9000
          hostPort      = 9000
          protocol      = "tcp"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.medusa_logs.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "medusa-backend"
        }
      }
    }
  ])
}

# ECS Service
resource "aws_ecs_service" "medusa_service" {
  name            = "medusa-service"
  cluster         = aws_ecs_cluster.medusa_cluster.id
  task_definition = aws_ecs_task_definition.medusa_task.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [aws_subnet.medusa_subnet.id]
    security_groups  = [aws_security_group.medusa_sg.id]
    assign_public_ip = true
  }
}

variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "jwt_secret" {
  description = "Secret key for JWT tokens"
  type        = string
  default     = "supersecret"
  sensitive   = true
}

variable "cookie_secret" {
  description = "Secret key for cookies"
  type        = string
  default     = "supersecret"
  sensitive   = true
}

variable "store_cors" {
  description = "CORS settings for store"
  type        = string
  default     = "http://localhost:8000,https://docs.medusajs.com"
}

variable "admin_cors" {
  description = "CORS settings for admin"
  type        = string
  default     = "http://localhost:5173,http://localhost:9000,https://docs.medusajs.com"
}

variable "auth_cors" {
  description = "CORS settings for auth"
  type        = string
  default     = "http://localhost:5173,http://localhost:9000,https://docs.medusajs.com"
}

output "ecr_repository_url" {
  description = "URL of the ECR repository"
  value       = data.aws_ecr_repository.medusa_repo.repository_url
}

output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = aws_ecs_cluster.medusa_cluster.name
}

output "ecs_service_name" {
  description = "Name of the ECS service"
  value       = aws_ecs_service.medusa_service.name
}