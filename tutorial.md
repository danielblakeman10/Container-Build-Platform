# Tutorial: Deploy an EC2 Instance with Terraform and GitHub Actions

This is a simple beginner pipeline. You will use GitHub Actions to run Terraform and create one EC2 instance in AWS.

## What You Will Build

```text
GitHub Actions
      |
      v
Terraform
      |
      v
AWS EC2 instance running Nginx
```

## Prerequisites

You need:

- An AWS account
- A GitHub repository
- Terraform knowledge at a beginner level
- AWS credentials that can create EC2, VPC security groups, and read S3 state

## Step 1: Create an S3 Bucket for Terraform State

Terraform state tracks what Terraform created. GitHub Actions runners are temporary, so state must live somewhere permanent.

Create an S3 bucket in AWS:

```bash
aws s3api create-bucket \
  --bucket YOUR_UNIQUE_TERRAFORM_STATE_BUCKET \
  --region us-east-1
```

Turn on versioning:

```bash
aws s3api put-bucket-versioning \
  --bucket YOUR_UNIQUE_TERRAFORM_STATE_BUCKET \
  --versioning-configuration Status=Enabled
```

## Step 2: Add GitHub Secrets

In GitHub, open:

```text
Repo -> Settings -> Secrets and variables -> Actions -> New repository secret
```

Add these secrets:

```text
AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY
TF_STATE_BUCKET
```

Example:

```text
TF_STATE_BUCKET = my-terraform-state-bucket-12345
```

## Step 3: Review the Terraform Files

The Terraform code lives in:

```text
terraform/
```

Important files:

```text
backend.tf              S3 backend configuration placeholder
main.tf                 EC2 instance, security group, AMI lookup, Nginx user data
variables.tf            Input variables
outputs.tf              EC2 public IP and URL
terraform.tfvars.example Example local values
```

## Step 4: Run the Pipeline

Open GitHub:

```text
Repo -> Actions -> Terraform EC2 Pipeline -> Run workflow
```

Choose:

```text
action = plan
```

This checks what Terraform will create.

Then run it again with:

```text
action = apply
```

This creates the EC2 instance.

## Step 5: Open the EC2 Website

After the workflow finishes, open the workflow logs and look for:

```text
instance_url
```

Open that URL in your browser. You should see a simple Nginx page.

## Step 6: Destroy the EC2 Instance

When you are done, run the workflow again:

```text
action = destroy
```

This deletes the EC2 instance and security group.

## Local Test Commands

You can test locally if your AWS CLI is configured:

```bash
cd terraform

terraform init \
  -backend-config="bucket=YOUR_UNIQUE_TERRAFORM_STATE_BUCKET" \
  -backend-config="key=container-build-platform/ec2-demo.tfstate" \
  -backend-config="region=us-east-1"

terraform fmt
terraform validate
terraform plan
```

## Files to Edit First

Start with:

```text
terraform/variables.tf
terraform/terraform.tfvars.example
.github/workflows/terraform-ec2.yml
```

## Simple Project Extension Ideas

After this works, try one small improvement:

- Add an EC2 key pair for SSH access.
- Restrict HTTP access to your IP address.
- Add a second EC2 instance.
- Add an Application Load Balancer.
- Replace user data with a small Ansible playbook.
- Convert the EC2 code into a reusable Terraform module.

## Cleanup Reminder

Always destroy test infrastructure:

```text
Actions -> Terraform EC2 Pipeline -> Run workflow -> action = destroy
```

Leaving EC2 instances running can create AWS charges.
