environment = "prod"

project_name = "man-cbp-prod"
aws_region   = "us-east-1"

use_existing_network = true

vpc_name                 = "man-cbp-vpc"
alb_name                 = "man-cbp-alb"
target_group_name        = "man-cbp-vpc"
alb_security_group_name  = "man-cbpo-alb-sg"
task_security_group_name = "man-cbp-task-sg"

ecr_repository_name = "man-cbp/prod/nginx"
ecs_cluster_name    = "man-cbp-prod-cluster"
ecs_service_name    = "man-cbp-prod-nginx-service"
task_family         = "man-cbp-prod-nginx"
log_group_name      = "/ecs/man-cbp-prod-nginx"

web_acl_name = "dcb-container-build-platform-waf"
web_acl_arn  = "arn:aws:wafv2:us-east-1:866934333672:regional/webacl/dcb-container-build-platform-waf/454483ac-e0cf-4ccf-950d-978b492cd69a"

desired_count    = 1
assign_public_ip = true
