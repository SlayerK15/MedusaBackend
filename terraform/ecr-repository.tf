# ecr-repository.tf

resource "aws_ecr_repository" "medusa_repo" {
  name = var.repository_name

  image_tag_mutability = "MUTABLE"
  image_scanning_configuration {
    scan_on_push = true
  }
}
