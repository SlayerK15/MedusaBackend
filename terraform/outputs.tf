output "ecs_cluster_id" {
  value = aws_ecs_cluster.medusa_cluster.id
}

output "ecs_service_arn" {
  value = aws_ecs_service.medusa_service.arn
}

output "ecr_repository_url" {
  value = aws_ecr_repository.medusa_repo.repository_url
}