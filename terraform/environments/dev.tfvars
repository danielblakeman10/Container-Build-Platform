environment = "dev"

project_name = "man-cbp-dev"
aws_region   = "us-east-1"

use_existing_network = false
vpc_cidr             = "10.10.0.0/16"
availability_zones   = ["us-east-1a", "us-east-1b"]
create_nat_gateway   = true

vpc_name                 = "man-cbp-dev-vpc"
alb_name                 = "man-cbp-dev-alb"
target_group_name        = "man-cbp-dev-tg"
alb_security_group_name  = "man-cbp-dev-alb-sg"
task_security_group_name = "man-cbp-dev-task-sg"

ecr_repository_name = "man-cbp/dev/nginx"
ecs_cluster_name    = "man-cbp-dev-cluster"
ecs_service_name    = "man-cbp-dev-nginx-service"
task_family         = "man-cbp-dev-nginx"
log_group_name      = "/ecs/man-cbp-dev-nginx"

desired_count    = 1
assign_public_ip = false
