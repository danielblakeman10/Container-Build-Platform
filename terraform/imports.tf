import {
  to = aws_ecr_repository.nginx
  id = "man-cbp/nginx"
}

import {
  to = aws_ecs_cluster.main
  id = "man-cbp-cluster"
}

import {
  to = aws_cloudwatch_log_group.nginx
  id = "/ecs/man-cbp-nginx"
}

import {
  to = aws_ecs_service.nginx
  id = "man-cbp-cluster/man-cbp-nginx-service"
}

import {
  to = aws_wafv2_web_acl_association.alb
  id = "arn:aws:wafv2:us-east-1:866934333672:regional/webacl/dcb-container-build-platform-waf/454483ac-e0cf-4ccf-950d-978b492cd69a,arn:aws:elasticloadbalancing:us-east-1:866934333672:loadbalancer/app/man-cbp-alb/9b517443193e7a3d"
}
