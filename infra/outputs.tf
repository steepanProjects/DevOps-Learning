output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.flask_alb.dns_name
}

output "alb_zone_id" {
  description = "Zone ID of the Application Load Balancer"
  value       = aws_lb.flask_alb.zone_id
}

output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = aws_ecs_cluster.this.name
}

output "ecs_service_name" {
  description = "Name of the ECS service"
  value       = aws_ecs_service.flask_service.name
}

output "application_url" {
  description = "URL to access the application"
  value       = "http://${aws_lb.flask_alb.dns_name}"
}
