locals {
  availability_zones = length(var.availability_zones) > 0 ? var.availability_zones : slice(data.aws_availability_zones.available.names, 0, 2)

  vpc_id = var.use_existing_network ? data.aws_vpc.existing[0].id : aws_vpc.main[0].id

  public_subnet_ids = var.use_existing_network ? [
    data.aws_subnet.existing_public_1[0].id,
    data.aws_subnet.existing_public_2[0].id
  ] : aws_subnet.public[*].id

  private_subnet_ids = var.use_existing_network ? [
    data.aws_subnet.existing_private_1[0].id,
    data.aws_subnet.existing_private_2[0].id
  ] : aws_subnet.private[*].id

  alb_security_group_id  = var.use_existing_network ? data.aws_security_group.existing_alb[0].id : aws_security_group.alb[0].id
  task_security_group_id = var.use_existing_network ? data.aws_security_group.existing_task[0].id : aws_security_group.task[0].id
  alb_arn                = var.use_existing_network ? data.aws_lb.existing[0].arn : aws_lb.main[0].arn
  alb_dns_name           = var.use_existing_network ? data.aws_lb.existing[0].dns_name : aws_lb.main[0].dns_name
  target_group_arn       = var.use_existing_network ? data.aws_lb_target_group.existing[0].arn : aws_lb_target_group.main[0].arn

  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    Owner       = "Daniel Blakeman"
    ManagedBy   = "Terraform"
    CostCenter  = "container-build-platform"
  }
}
