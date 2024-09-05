variable "cluster_name" {
  description = "Name of the ECS cluster"
  default     = "medusa-cluster"
}

variable "service_name" {
  description = "Name of the ECS service"
  default     = "medusa-service"
}

variable "repository_name" {
  description = "Name of the ECR repository"
  default     = "my-ecr-repo"
}

variable "desired_count" {
  description = "Number of tasks to run"
  default     = 1
}

variable "subnet_ids" {
  description = "List of subnet IDs for ECS tasks"
  type        = list(string)
}

variable "security_group_ids" {
  description = "List of security group IDs for ECS tasks"
  type        = list(string)
}

variable "image_tag" {
  description = "Docker image tag"
  type        = string
}
