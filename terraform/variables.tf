variable "project_name" {
  description = "Canonical project prefix for the live demo resources"
  type        = string
  default     = "man-cbp"
}

variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "vpc_name" {
  description = "Existing VPC name used by the live demo stack"
  type        = string
  default     = "man-cbp-vpc"
}

variable "alb_name" {
  description = "Existing public ALB name used by the live demo"
  type        = string
  default     = "man-cbp-alb"
}

variable "target_group_name" {
  description = "Existing ALB target group used by the ECS service"
  type        = string
  default     = "man-cbp-vpc"
}

variable "alb_security_group_name" {
  description = "Existing ALB security group name"
  type        = string
  default     = "man-cbpo-alb-sg"
}

variable "task_security_group_name" {
  description = "Existing ECS task security group name"
  type        = string
  default     = "man-cbp-task-sg"
}

variable "ecr_repository_name" {
  description = "ECR repository that stores the NGINX image"
  type        = string
  default     = "man-cbp/nginx"
}

variable "ecs_cluster_name" {
  description = "ECS cluster hosting the live demo service"
  type        = string
  default     = "man-cbp-cluster"
}

variable "ecs_service_name" {
  description = "ECS service managing the NGINX Fargate task"
  type        = string
  default     = "man-cbp-nginx-service"
}

variable "task_family" {
  description = "ECS task definition family"
  type        = string
  default     = "man-cbp-nginx"
}

variable "log_group_name" {
  description = "CloudWatch Logs group used by the NGINX task"
  type        = string
  default     = "/ecs/man-cbp-nginx"
}

variable "log_retention_in_days" {
  description = "CloudWatch Logs retention period"
  type        = number
  default     = 30
}

variable "web_acl_name" {
  description = "Regional AWS WAF Web ACL associated with the demo ALB"
  type        = string
  default     = "dcb-container-build-platform-waf"
}

variable "ecs_task_execution_role_name" {
  description = "IAM role used by the ECS task for image pulls and logging"
  type        = string
  default     = "ecsTaskExecutionRole"
}

variable "container_image" {
  description = "Full ECR image URI including tag to deploy"
  type        = string
}

variable "container_port" {
  description = "Port the nginx container listens on"
  type        = number
  default     = 80
}

variable "task_cpu" {
  description = "Fargate task CPU units (256 = .25 vCPU, 512 = .5 vCPU, etc.)"
  type        = string
  default     = "512"
}

variable "task_memory" {
  description = "Fargate task memory in MiB"
  type        = string
  default     = "1024"
}

variable "desired_count" {
  description = "Number of task replicas the service should run"
  type        = number
  default     = 1
}

variable "container_insights" {
  description = "ECS Container Insights setting"
  type        = string
  default     = "enhanced"
}

variable "ecr_image_tag_mutability" {
  description = "ECR image tag mutability setting"
  type        = string
  default     = "MUTABLE"
}
