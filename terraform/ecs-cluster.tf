# ecs-cluster.tf

resource "aws_ecs_cluster" "medusa_cluster" {
  name = var.cluster_name
}

resource "aws_ecs_task_definition" "medusa_task" {
  family                   = "medusa-task"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"

  container_definitions = jsonencode([{
    name      = "medusa-backend"
    image     = "${aws_ecr_repository.medusa_repo.repository_url}:${var.image_tag}"
    essential = true

    portMappings = [
      {
        containerPort = 9000
        hostPort      = 9000
        protocol      = "tcp"
      }
    ]
  }])
}

resource "aws_ecs_service" "medusa_service" {
  name            = var.service_name
  cluster         = aws_ecs_cluster.medusa_cluster.id
  task_definition = aws_ecs_task_definition.medusa_task.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = var.security_group_ids
    assign_public_ip = true
  }
}
