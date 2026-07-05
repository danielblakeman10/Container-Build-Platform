variable "project_name" {
  description = "Name prefix used across all resources"
  type        = string
  default     = "tf-container-build-platform"
}

variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Availability zones to spread subnets across"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "container_image" {
  description = "Full ECR image URI (including tag) to deploy"
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