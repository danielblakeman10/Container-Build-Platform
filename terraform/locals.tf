locals {
  common_tags = {
    Project     = var.project_name
    Environment = "demo"
    Owner       = "Daniel Blakeman"
    ManagedBy   = "Terraform"
  }
}
