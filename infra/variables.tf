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
