variable "aws_region" {
  description = "AWS region where resources will be deployed"
  type        = string
  default     = "ap-south-1"
}

variable "dockerhub_username" {
  description = "DockerHub username for pulling images"
  type        = string
  default     = "steepan"
}

variable "git_sha" {
  description = "Git commit SHA for Docker image tag"
  type        = string
  default     = "latest"  # fallback
}
variable "subnet_ids" {
  description = "Subnet IDs for ECS tasks and ALB"
  type        = list(string)
  default = "subnet-0e5c0731ddedc24ae"
}
variable "vpc_id" {
  description = "VPC ID where ECS and ALB will run"
  type        = string
  default = "vpc-0520ee24692866295"
}