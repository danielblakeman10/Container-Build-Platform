output "alb_dns_name" {
  description = "Public DNS name of the ALB"
  value       = local.alb_dns_name
}

output "ecr_repository_url" {
  description = "URL of the ECR repository to push the nginx image to"
  value       = aws_ecr_repository.nginx.repository_url
}

output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = aws_ecs_cluster.main.name
}

output "ecs_service_name" {
  description = "Name of the ECS service"
  value       = aws_ecs_service.nginx.name
}

output "waf_web_acl_name" {
  description = "Regional AWS WAF Web ACL associated with the ALB"
  value       = var.web_acl_name == "" ? "not-associated" : var.web_acl_name
}
