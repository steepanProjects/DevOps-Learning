terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  required_version = ">= 1.3.0"
}

provider "aws" {
  region = var.aws_region
}



# ECS Cluster
resource "aws_ecs_cluster" "this" {
  name = "flask-cluster"
}

# ECS Task Execution IAM Role (existing)
data "aws_iam_role" "ecs_task_execution_role" {
  name = "ecsTaskExecutionRole"
}

# Attach policy (optional)
resource "aws_iam_role_policy_attachment" "ecs_task_execution_policy" {
  role       = data.aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# ECS Task Definition
resource "aws_ecs_task_definition" "flask_app" {
  family                   = "flask-task"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = data.aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([{
    name      = "flask-container"
    image     = "${var.dockerhub_username}/devops-learning:${var.git_sha}"
    essential = true
    portMappings = [{
      containerPort = 5000
      hostPort      = 5000
    }]
  }])
}

# Security group for ALB
resource "aws_security_group" "alb_sg" {
  name        = "alb-sg"
  description = "Allow HTTP"
  vpc_id      = "vpc-0520ee24692866295" 

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ALB
resource "aws_lb" "flask_alb" {
  name               = "flask-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = ["subnet-0e5c0731ddedc24ae","subnet-0002fdfcb821db040"]
}

# Target Group
resource "aws_lb_target_group" "flask_tg" {
  name        = "flask-tg"
  port        = 5000
  protocol    = "HTTP"
  vpc_id      = "vpc-0520ee24692866295"
  target_type = "ip"
}

# Listener
resource "aws_lb_listener" "flask_listener" {
  load_balancer_arn = aws_lb.flask_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.flask_tg.arn
  }
}

# ECS Service with ALB integration
resource "aws_ecs_service" "flask_service" {
  name            = "flask-service"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.flask_app.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = ["subnet-0e5c0731ddedc24ae","subnet-0002fdfcb821db040"]
    security_groups = ["sg-07c108c9c401c1db5"]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.flask_tg.arn
    container_name   = "flask-container"
    container_port   = 5000
  }

  force_new_deployment = true
  depends_on           = [aws_lb_listener.flask_listener]
}
