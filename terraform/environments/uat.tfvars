environment = "uat"

project_name = "man-cbp-uat"
aws_region   = "us-east-1"

use_existing_network = false
vpc_cidr             = "10.20.0.0/16"
availability_zones   = ["us-east-1a", "us-east-1b"]
create_nat_gateway   = true

vpc_name                 = "man-cbp-uat-vpc"
alb_name                 = "man-cbp-uat-alb"
target_group_name        = "man-cbp-uat-tg"
alb_security_group_name  = "man-cbp-uat-alb-sg"
task_security_group_name = "man-cbp-uat-task-sg"

ecr_repository_name = "man-cbp/uat/nginx"
ecs_cluster_name    = "man-cbp-uat-cluster"
ecs_service_name    = "man-cbp-uat-nginx-service"
task_family         = "man-cbp-uat-nginx"
log_group_name      = "/ecs/man-cbp-uat-nginx"

desired_count    = 1
assign_public_ip = false
