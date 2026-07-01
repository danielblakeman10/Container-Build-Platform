# Tutorial: Create a Pipeline to Deploy an EC2 Instance with Terraform

This tutorial starts from an empty repository. You will create every file yourself so you understand what each piece does.

Goal:

```text
GitHub Actions -> Terraform -> AWS EC2 instance
```

## 1. What You Need

You need:

- A GitHub repository
- An AWS account
- AWS credentials for GitHub Actions
- An S3 bucket for Terraform state

Terraform state is important. It records what Terraform created. Because GitHub Actions runners are temporary, the state file needs to live in S3.

## 2. Create the Folder Structure

From the root of your repo, create this:

```text
.
├── .github/
│   └── workflows/
│       └── terraform-ec2.yml
└── terraform/
    ├── backend.tf
    ├── main.tf
    ├── outputs.tf
    └── variables.tf
```

## 3. Create an S3 Bucket for Terraform State

Pick a unique bucket name. S3 bucket names are globally unique.

```bash
aws s3api create-bucket \
  --bucket YOUR_UNIQUE_TERRAFORM_STATE_BUCKET \
  --region us-east-1
```

Enable versioning:

```bash
aws s3api put-bucket-versioning \
  --bucket YOUR_UNIQUE_TERRAFORM_STATE_BUCKET \
  --versioning-configuration Status=Enabled
```

## 4. Add GitHub Secrets

In GitHub, go to:

```text
Settings -> Secrets and variables -> Actions -> New repository secret
```

Add:

```text
AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY
TF_STATE_BUCKET
```

`TF_STATE_BUCKET` is the S3 bucket name you created.

## 5. Create `terraform/backend.tf`

```hcl
terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {}
}
```

Why this exists:

- Defines the AWS provider.
- Tells Terraform to use an S3 backend.
- The bucket name is passed from the GitHub Actions pipeline.

## 6. Create `terraform/variables.tf`

```hcl
variable "aws_region" {
  description = "AWS region used by Terraform."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Name prefix for AWS resources."
  type        = string
  default     = "terraform-ec2-demo"
}

variable "instance_type" {
  description = "EC2 instance size."
  type        = string
  default     = "t3.micro"
}
```

Why this exists:

- Keeps values reusable.
- Makes it easy to change region, name, or instance size later.

## 7. Create `terraform/main.tf`

```hcl
provider "aws" {
  region = var.aws_region
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_security_group" "web" {
  name        = "${var.project_name}-web-sg"
  description = "Allow HTTP access to the demo EC2 instance"

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "${var.project_name}-web-sg"
    Project = var.project_name
  }
}

resource "aws_instance" "web" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type
  vpc_security_group_ids = [aws_security_group.web.id]

  user_data = <<-EOF
    #!/bin/bash
    dnf update -y
    dnf install -y nginx
    systemctl enable nginx
    systemctl start nginx
    echo "<h1>Hello from Terraform on EC2</h1>" > /usr/share/nginx/html/index.html
  EOF

  tags = {
    Name    = "${var.project_name}-web"
    Project = var.project_name
  }
}
```

What this creates:

- A security group that allows HTTP on port `80`
- One Amazon Linux EC2 instance
- Nginx installed through EC2 user data

## 8. Create `terraform/outputs.tf`

```hcl
output "instance_id" {
  description = "EC2 instance ID."
  value       = aws_instance.web.id
}

output "public_ip" {
  description = "Public IP address for the EC2 instance."
  value       = aws_instance.web.public_ip
}

output "instance_url" {
  description = "HTTP URL for the demo Nginx page."
  value       = "http://${aws_instance.web.public_ip}"
}
```

Why this exists:

- Shows the EC2 instance ID.
- Shows the public IP.
- Shows the website URL after deployment.

## 9. Create `.github/workflows/terraform-ec2.yml`

```yaml
name: Terraform EC2 Pipeline

on:
  workflow_dispatch:
    inputs:
      action:
        description: "Terraform action to run"
        required: true
        default: "plan"
        type: choice
        options:
          - plan
          - apply
          - destroy

jobs:
  terraform:
    name: terraform-${{ inputs.action }}
    runs-on: ubuntu-latest

    defaults:
      run:
        working-directory: terraform

    env:
      AWS_REGION: us-east-1

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ env.AWS_REGION }}

      - name: Install Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: 1.9.8

      - name: Terraform fmt
        run: terraform fmt -check

      - name: Terraform init
        run: |
          terraform init \
            -backend-config="bucket=${{ secrets.TF_STATE_BUCKET }}" \
            -backend-config="key=terraform-ec2-demo/terraform.tfstate" \
            -backend-config="region=${{ env.AWS_REGION }}"

      - name: Terraform validate
        run: terraform validate

      - name: Terraform plan
        if: inputs.action == 'plan'
        run: terraform plan

      - name: Terraform apply
        if: inputs.action == 'apply'
        run: terraform apply -auto-approve

      - name: Show Terraform outputs
        if: inputs.action == 'apply'
        run: terraform output

      - name: Terraform destroy
        if: inputs.action == 'destroy'
        run: terraform destroy -auto-approve
```

What this pipeline does:

- Installs Terraform
- Connects to AWS
- Initializes Terraform state from S3
- Runs `plan`, `apply`, or `destroy`

## 10. Commit and Push

```bash
git add .
git commit -m "Add Terraform EC2 deployment tutorial"
git push
```

## 11. Run the Pipeline

In GitHub, go to:

```text
Actions -> Terraform EC2 Pipeline -> Run workflow
```

First run:

```text
action = plan
```

If the plan looks good, run:

```text
action = apply
```

After apply finishes, open the workflow logs and find:

```text
instance_url
```

Open that URL in your browser.

## 12. Destroy the Instance

When you are done learning, destroy the EC2 instance:

```text
Actions -> Terraform EC2 Pipeline -> Run workflow -> action = destroy
```

Do this every time. Running EC2 instances can create AWS charges.

## What to Learn From This

Focus on these concepts:

- Terraform provider
- Terraform resource
- Terraform data source
- Terraform output
- S3 remote state
- GitHub Actions workflow
- GitHub repository secrets
- EC2 user data
- Security group ingress and egress

## Small Improvements to Try Later

After the basic version works, try one improvement:

- Restrict HTTP access to your public IP.
- Add SSH access with an EC2 key pair.
- Add a second EC2 instance.
- Add an Application Load Balancer.
- Convert the Terraform into a reusable module.
- Replace user data with Ansible.
