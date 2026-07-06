variable "project_name" {
  description = "Canonical project prefix for the target environment"
  type        = string
}

variable "environment" {
  description = "Deployment environment name"
  type        = string
  validation {
    condition     = contains(["dev", "uat", "prod"], var.environment)
    error_message = "Environment must be one of: dev, uat, prod."
  }
}

variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "use_existing_network" {
  description = "Use pre-existing VPC, subnets, security groups, ALB, and target group instead of creating them"
  type        = bool
  default     = false
}

variable "vpc_cidr" {
  description = "CIDR block for newly created non-production VPCs"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Availability zones for newly created non-production subnets. Leave empty to use the first two available AZs."
  type        = list(string)
  default     = []
}

variable "create_nat_gateway" {
  description = "Create a single NAT Gateway for private subnet egress in newly created environments"
  type        = bool
  default     = true
}

variable "allowed_http_cidr_blocks" {
  description = "CIDR blocks allowed to reach newly created ALBs over HTTP"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "alb_deletion_protection" {
  description = "Enable deletion protection on newly created ALBs"
  type        = bool
  default     = false
}

variable "vpc_name" {
  description = "VPC name for the target environment"
  type        = string
}

variable "alb_name" {
  description = "Public ALB name for the target environment"
  type        = string
}

variable "target_group_name" {
  description = "ALB target group name for the ECS service"
  type        = string
}

variable "alb_security_group_name" {
  description = "ALB security group name"
  type        = string
}

variable "task_security_group_name" {
  description = "ECS task security group name"
  type        = string
}

variable "ecr_repository_name" {
  description = "ECR repository that stores the NGINX image"
  type        = string
}

variable "ecs_cluster_name" {
  description = "ECS cluster hosting the service"
  type        = string
}

variable "ecs_service_name" {
  description = "ECS service managing the NGINX Fargate task"
  type        = string
}

variable "task_family" {
  description = "ECS task definition family"
  type        = string
}

variable "log_group_name" {
  description = "CloudWatch Logs group used by the NGINX task"
  type        = string
}

variable "log_retention_in_days" {
  description = "CloudWatch Logs retention period"
  type        = number
  default     = 30
}

variable "web_acl_name" {
  description = "Regional AWS WAF Web ACL associated with the ALB"
  type        = string
  default     = ""
}

variable "web_acl_arn" {
  description = "Regional AWS WAF Web ACL ARN associated with the ALB. Leave empty when WAF is not attached."
  type        = string
  default     = ""
}

variable "ecs_task_execution_role_arn" {
  description = "IAM role ARN used by the ECS task for image pulls and logging"
  type        = string
  default     = "arn:aws:iam::866934333672:role/ecsTaskExecutionRole"
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

variable "assign_public_ip" {
  description = "Assign public IP addresses to ECS tasks"
  type        = bool
  default     = false
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
