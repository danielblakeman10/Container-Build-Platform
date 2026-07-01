# Container Build Platform

This repo has been simplified into a beginner AWS DevOps project:

**Create a GitHub Actions pipeline that deploys one EC2 instance with Terraform.**

The goal is to learn the basic workflow:

1. Write Terraform.
2. Store Terraform state in S3.
3. Configure GitHub repository secrets.
4. Run a GitHub Actions pipeline.
5. Deploy and destroy an EC2 instance.

## Start Here

Read the tutorial:

[tutorial.md](tutorial.md)

## Repository Layout

```text
.
├── .github/
│   └── workflows/
│       └── terraform-ec2.yml
├── terraform/
│   ├── backend.tf
│   ├── main.tf
│   ├── outputs.tf
│   ├── terraform.tfvars.example
│   └── variables.tf
├── tutorial.md
├── .gitignore
├── LICENSE
└── README.md
```

## What This Builds

Terraform creates:

- One security group
- One EC2 instance
- A small Nginx web server installed through user data

The workflow supports:

- `plan`
- `apply`
- `destroy`

Use this as a learning project only. The Terraform defaults are intentionally small and simple.
