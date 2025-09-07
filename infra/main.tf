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

##########################
# ECS Cluster
##########################
resource "aws_ecs_cluster" "this" {
  name = "flask-cluster"
}

##########################
# ECS Task Execution Role
##########################
data "aws_iam_role" "ecs_task_execution_role" {
  name = "ecsTaskExecutionRole"
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_policy" {
  role       = data.aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

##########################
# Security Group (ALB)
##########################
data "aws_security_group" "existing_alb_sg" {
  count  = length(try([for sg in aws_security_groups : sg if sg.name == "alb-sg"], []))
  name   = "alb-sg"
  vpc_id = "vpc-0520ee24692866295"
}

resource "aws_security_group" "alb_sg" {
  count       = length(data.aws_security_group.existing_alb_sg) == 0 ? 1 : 0
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

locals {
  alb_sg_id = length(data.aws_security_group.existing_alb_sg) > 0 ? data.aws_security_group.existing_alb_sg[0].id : aws_security_group.alb_sg[0].id
}

##########################
# Target Group
##########################
data "aws_lb_target_group" "existing_flask_tg" {
  count = length(try([for tg in aws_lb_target_groups : tg if tg.name == "flask-tg"], []))
  name  = "flask-tg"
}

resource "aws_lb_target_group" "flask_tg" {
  count       = length(data.aws_lb_target_group.existing_flask_tg) == 0 ? 1 : 0
  name        = "flask-tg"
  port        = 5000
  protocol    = "HTTP"
  vpc_id      = "vpc-0520ee24692866295"
  target_type = "ip"
}

locals {
  flask_tg_arn = length(data.aws_lb_target_group.existing_flask_tg) > 0 ? data.aws_lb_target_group.existing_flask_tg[0].arn : aws_lb_target_group.flask_tg[0].arn
}

##########################
# ALB
##########################
resource "aws_lb" "flask_alb" {
  name               = "flask-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [local.alb_sg_id]
  subnets            = ["subnet-0e5c0731ddedc24ae","subnet-0002fdfcb821db040"]
}

##########################
# Listener
##########################
data "aws_lb_listener" "existing_listener" {
  count = length(try([for l in aws_lb_listeners : l if l.load_balancer_arn == aws_lb.flask_alb.arn], []))
  load_balancer_arn = aws_lb.flask_alb.arn
  port              = 80
}

resource "aws_lb_listener" "flask_listener" {
  count             = length(data.aws_lb_listener.existing_listener) == 0 ? 1 : 0
  load_balancer_arn = aws_lb.flask_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = local.flask_tg_arn
  }
}

##########################
# ECS Task Definition
##########################
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

##########################
# ECS Service
##########################
resource "aws_ecs_service" "flask_service" {
  name            = "flask-service"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.flask_app.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = ["subnet-0e5c0731ddedc24ae","subnet-0002fdfcb821db040"]
    security_groups = [local.alb_sg_id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = local.flask_tg_arn
    container_name   = "flask-container"
    container_port   = 5000
  }

  force_new_deployment = true
  depends_on           = [aws_lb_listener.flask_listener]
}
