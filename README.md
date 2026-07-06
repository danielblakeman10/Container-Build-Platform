# Container Build Platform

Container Build Platform is a reference DevSecOps deployment pattern for building a container image from GitHub, publishing it to Amazon ECR, and deploying it to Amazon ECS on AWS Fargate behind a public Application Load Balancer.

The repository demonstrates a production-shaped control plane: GitHub Actions uses AWS OIDC federation instead of long-lived access keys, Docker builds an NGINX workload, Terraform provisions AWS networking and compute, and ECS runs the container in private subnets with ingress constrained through the ALB.

## What This Demonstrates

- Keyless GitHub Actions authentication to AWS using OpenID Connect.
- Container build, tag, and push workflow into Amazon ECR.
- Terraform-managed AWS infrastructure using an S3 remote backend.
- ECS Fargate service deployment with an ALB target group.
- Custom VPC with public and private subnets across multiple Availability Zones.
- Public ingress through ALB only; ECS tasks remain private.
- CloudWatch Logs integration for container runtime logs.

## Repository Layout

```text
.
|-- .github/workflows/
|   |-- deploy.yml        # Build, push, and Terraform deploy workflow
|   `-- oidc-debug.yml    # Manual workflow to validate AWS OIDC federation
|-- nginx/
|   |-- Dockerfile        # NGINX container image definition
|   `-- app/index.html    # Static demo workload
`-- terraform/
    |-- backend.tf        # Terraform version, provider, and S3 backend
    |-- main.tf           # VPC, ALB, ECR, ECS, IAM, and CloudWatch resources
    |-- outputs.tf        # ALB, ECR, ECS service, and cluster outputs
    |-- provider.tf       # AWS provider configuration
    |-- terraform.tfvars  # Runtime container image value
    `-- variables.tf      # Configurable deployment inputs
```

## Technologies Used

| Layer | Technology | Purpose |
| --- | --- | --- |
| Source Control | GitHub | Hosts application, Terraform, and CI/CD workflow definitions. |
| CI/CD | GitHub Actions | Builds the container image and executes Terraform deployment. |
| Authentication | GitHub OIDC + AWS IAM | Federates GitHub Actions to AWS without static AWS keys. |
| Container Runtime | Docker | Builds the NGINX application image. |
| Registry | Amazon ECR | Stores versioned container images. |
| Infrastructure as Code | Terraform | Provisions and updates AWS infrastructure. |
| Terraform State | Amazon S3 backend | Stores remote Terraform state for repeatable deployments. |
| Networking | Amazon VPC | Provides public/private subnet isolation and routing. |
| Ingress | Application Load Balancer | Exposes HTTP traffic to the service. |
| Compute | Amazon ECS on Fargate | Runs the container without managing EC2 instances. |
| Logging | Amazon CloudWatch Logs | Captures ECS task logs. |
| Web Server | NGINX Alpine | Lightweight demo container workload. |

## Application Flow Diagram

```mermaid
flowchart TD
    Dev[Developer pushes to main or runs workflow_dispatch] --> GH[GitHub Repository]
    GH --> GHA[GitHub Actions deploy workflow]
    GHA --> OIDC[GitHub OIDC token]
    OIDC --> IAM[AWS IAM role assumption]
    IAM --> ECRLogin[Authenticate to Amazon ECR]
    ECRLogin --> Build[Docker build nginx image]
    Build --> Tag[Tag image with Git SHA]
    Tag --> Push[Push image to Amazon ECR]
    Push --> TFInit[Terraform init using S3 backend]
    TFInit --> TFApply[Terraform apply with container_image override]
    TFApply --> ECSUpdate[ECS task definition and service update]
    ECSUpdate --> Fargate[ECS Fargate task launches in private subnet]
    User[End user] --> ALB[Public Application Load Balancer]
    ALB --> TG[ALB target group]
    TG --> Fargate
    Fargate --> Logs[CloudWatch Logs]
```

## Solution Architecture Diagram

```mermaid
flowchart LR
    subgraph GitHub["GitHub"]
        Repo[Container-Build-Platform repository]
        Actions[GitHub Actions]
    end

    subgraph AWS["AWS Account"]
        IAMRole[IAM OIDC deployment role]
        S3[S3 Terraform state backend]
        ECR[Amazon ECR repository]

        subgraph VPC["VPC: tf-container-build-platform-vpc"]
            IGW[Internet Gateway]

            subgraph Public["Public subnets"]
                ALB[Application Load Balancer]
                NAT[NAT Gateway]
            end

            subgraph Private["Private subnets"]
                ECS[ECS Fargate service]
                Task[NGINX task definition]
            end

            ALBSG[ALB security group<br/>Ingress: 80 from 0.0.0.0/0]
            TaskSG[Task security group<br/>Ingress: container port from ALB SG]
            Logs[CloudWatch log group]
        end
    end

    Repo --> Actions
    Actions -->|OIDC federation| IAMRole
    Actions -->|docker push| ECR
    Actions -->|terraform init/apply| S3
    Actions -->|provision/update| VPC
    IGW --> ALB
    ALB --> ALBSG
    ALBSG --> TaskSG
    TaskSG --> ECS
    ECR --> Task
    Task --> ECS
    ECS --> Logs
    ECS -->|egress for image pulls and AWS APIs| NAT
```

## AWS VPC Diagram

```mermaid
flowchart TB
    Internet((Internet)) --> IGW[Internet Gateway]

    subgraph VPC["VPC 10.0.0.0/16"]
        subgraph AZA["Availability Zone us-east-1a"]
            PubA[Public subnet<br/>10.0.0.0/20]
            PrivA[Private subnet<br/>10.0.32.0/20]
        end

        subgraph AZB["Availability Zone us-east-1b"]
            PubB[Public subnet<br/>10.0.16.0/20]
            PrivB[Private subnet<br/>10.0.48.0/20]
        end

        PublicRT[Public route table<br/>0.0.0.0/0 to IGW]
        PrivateRT[Private route table<br/>0.0.0.0/0 to NAT]
        NAT[NAT Gateway<br/>in first public subnet]
        ALB[Public ALB<br/>spans public subnets]
        ECS[ECS Fargate tasks<br/>private subnets only]
    end

    IGW --> PublicRT
    PublicRT --> PubA
    PublicRT --> PubB
    PubA --> NAT
    NAT --> PrivateRT
    PrivateRT --> PrivA
    PrivateRT --> PrivB
    Internet --> ALB
    ALB --> ECS
```

## Deployment Flow

1. A commit is pushed to `main`, or the `Deploy nginx to Fargate` workflow is manually triggered.
2. GitHub Actions requests an OIDC token and assumes the AWS deployment role.
3. The workflow logs in to Amazon ECR.
4. Docker builds the image from `nginx/Dockerfile`.
5. The image is tagged with the Git commit SHA and pushed to ECR.
6. Terraform initializes against the S3 backend.
7. Terraform applies infrastructure changes and injects the new image URI into the ECS task definition.
8. ECS launches the updated NGINX task on Fargate in private subnets.
9. Public users reach the service through the ALB DNS name.

## CI/CD Operating Model

This operating model follows the same production-style structure used in larger GitHub Actions and Terraform AWS projects: establish trust first, bootstrap shared deployment primitives, then let application workflows build immutable artifacts and deploy infrastructure through controlled environment paths.

### Operating Principles

| Principle | Implementation in this project | Production extension |
| --- | --- | --- |
| Keyless AWS access | GitHub Actions assumes AWS IAM roles through OIDC. | Scope trust policies by repository, branch, environment, and workflow. |
| Immutable deploy artifact | Images are tagged with the Git commit SHA. | Promote the same digest across dev, UAT, and production instead of rebuilding. |
| Infrastructure as code | Terraform owns VPC, ALB, ECR, ECS, IAM, and CloudWatch resources. | Split networking, platform, and application stacks into separate state files or modules. |
| Remote state | Terraform uses an S3 backend. | Centralize state in a tooling account with encryption, versioning, least-privilege access, and locking. |
| Environment control | `main` deploys the current stack. | Map `develop`, `uat`, and `main` to separate AWS accounts or isolated environments. |
| Approval control | Manual `workflow_dispatch` is available. | Require protected GitHub Environments and approval gates before production apply. |
| Runtime isolation | ECS tasks run in private subnets behind a public ALB. | Add VPC endpoints, private image pulls, HTTPS-only ingress, and environment-specific CIDRs. |

### Pipeline Stages

```mermaid
flowchart LR
    Commit[Commit or manual dispatch] --> Validate[Static validation]
    Validate --> Auth[Assume AWS role through OIDC]
    Auth --> Build[Build Docker image]
    Build --> Publish[Push image to ECR with Git SHA tag]
    Publish --> Plan[Terraform init and plan]
    Plan --> Gate{Approval required?}
    Gate -->|Non-production| Apply[Terraform apply]
    Gate -->|Production| Approval[Protected environment approval]
    Approval --> Apply
    Apply --> Deploy[ECS service deployment]
    Deploy --> Verify[ALB, ECS, and CloudWatch verification]
```

### Current Workflow Responsibilities

| Workflow | Trigger | Responsibility | AWS role target |
| --- | --- | --- | --- |
| `.github/workflows/oidc-debug.yml` | Manual only | Validates GitHub-to-AWS OIDC trust by running `aws sts get-caller-identity`. | `GitHubActionsOIDCRole` |
| `.github/workflows/deploy.yml` | Push to `main` or manual dispatch | Builds the NGINX image, pushes to ECR, initializes Terraform, and applies the ECS/Fargate stack. | `container-build-platform-gha-role` |

### Recommended Environment Promotion Model

The current repository deploys from `main`. For a stronger demonstration, extend it to this branch-to-environment model:

| Branch | Environment | AWS account or isolation boundary | Terraform state key | Deployment control |
| --- | --- | --- | --- | --- |
| `develop` | Dev | Dev account or dev VPC | `container-build-platform/dev/terraform.tfstate` | Automatic apply after validation. |
| `uat` | UAT | UAT account or UAT VPC | `container-build-platform/uat/terraform.tfstate` | Manual approval or release-manager approval. |
| `main` | Production | Production account or production VPC | `container-build-platform/production/terraform.tfstate` | Protected GitHub Environment with required approval. |

### Recommended Workflow Separation

For a production-grade version, split the current deployment flow into three workflows:

| Workflow | Purpose | Execution order |
| --- | --- | --- |
| `tooling-foundation.yml` | Creates or validates shared CI/CD primitives: Terraform state bucket, state encryption, OIDC provider, and bootstrap role. | Run first during platform bootstrap. |
| `account-bootstrap.yml` | Creates target-account deploy roles, ECR repositories, and environment-specific deployment parameters. | Run after tooling foundation. |
| `app-deploy.yml` | Builds the application image, pushes to ECR, runs Terraform plan/apply, and updates ECS. | Runs continuously from branch or manual deployment events. |

### Governance and Control Points

- Pull requests should run `terraform fmt -check`, `terraform validate`, Docker build validation, and IaC/container security scans before merge.
- `main` should be protected with required reviews and passing checks before the deployment workflow can run from trusted code.
- Production applies should use GitHub Environments with required reviewers.
- The AWS deployment role should be scoped to the repository subject claim and should avoid wildcarding all repositories in the GitHub organization.
- ECR pushes should use Git SHA tags; production should deploy by immutable image digest where possible.
- Terraform state access should be separate from application runtime permissions.
- ECS deployment verification should check service stability, target group health, ALB response, and CloudWatch log ingestion.

### Operational Verification

After each deployment, validate the platform with:

```bash
aws sts get-caller-identity
aws ecr describe-images --repository-name tf-container-build-platform/nginx
aws ecs describe-services --cluster tf-container-build-platform-cluster --services tf-container-build-platform-nginx-service
aws elbv2 describe-target-health --target-group-arn <target-group-arn>
curl -I http://<alb_dns_name>
```

## AWS Resources Provisioned

| Resource | Description |
| --- | --- |
| VPC | DNS-enabled VPC using `10.0.0.0/16` by default. |
| Public subnets | One public subnet per configured Availability Zone with public IP assignment enabled. |
| Private subnets | One private subnet per configured Availability Zone for ECS tasks. |
| Internet Gateway | Provides public internet routing for the ALB and NAT Gateway. |
| NAT Gateway | Allows private ECS tasks to reach AWS APIs and external endpoints without public IPs. |
| Route tables | Separate public and private routing domains. |
| ALB security group | Allows inbound HTTP on port 80 from the public internet. |
| Task security group | Allows inbound container traffic only from the ALB security group. |
| Application Load Balancer | Public HTTP entry point for the NGINX service. |
| Target group | IP-based target group for Fargate tasks. |
| ECR repository | Stores the NGINX container image. |
| ECS cluster | Fargate cluster with Container Insights enabled. |
| ECS task definition | Runs the NGINX image with CloudWatch log configuration. |
| ECS service | Maintains the desired task count and registers tasks with the ALB. |
| CloudWatch log group | Stores NGINX container logs with 14-day retention. |
| IAM task execution role | Allows ECS to pull images and write logs. |

## Security Model

- GitHub Actions uses OIDC role assumption, avoiding long-lived AWS access keys in repository secrets.
- ECS tasks are deployed to private subnets with `assign_public_ip = false`.
- The task security group accepts inbound traffic only from the ALB security group.
- ALB ingress is intentionally public on HTTP port 80 for demonstration.
- ECR encryption uses AWS-managed AES-256 encryption.
- ECS task logs are centralized in CloudWatch Logs.
- Terraform state is remote in S3; production deployments should also enforce bucket versioning, encryption, least-privilege state access, and state locking behavior appropriate for the Terraform version in use.

## Prerequisites

- AWS account with permission to provision VPC, ALB, ECR, ECS, IAM, CloudWatch, S3 backend access, and related networking resources.
- GitHub repository OIDC trust configured in AWS IAM for the deployment workflow.
- S3 bucket created for the Terraform backend before `terraform init`.
- Terraform CLI compatible with `required_version` in `terraform/backend.tf`.
- Docker available for local image build testing.
- GitHub Actions workflow role allowed to push ECR images and run Terraform against the target account.

## Required GitHub Actions Configuration

The deployment workflow expects an AWS IAM role that GitHub Actions can assume with:

```yaml
permissions:
  id-token: write
  contents: read
```

For a locked-down trust policy, scope the role to this repository and branch:

```json
{
  "Condition": {
    "StringEquals": {
      "token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
      "token.actions.githubusercontent.com:sub": "repo:danielblakeman10/Container-Build-Platform:ref:refs/heads/main"
    }
  }
}
```

Use the broader `repo:danielblakeman10/Container-Build-Platform:*` subject only when you intentionally want multiple branches, tags, or environments to assume the role.

## Local Validation Commands

Run these commands from the repository root.

```bash
docker build -t container-build-platform-nginx:local ./nginx
docker run --rm -p 8080:80 container-build-platform-nginx:local
```

Validate Terraform without touching the remote backend:

```bash
cd terraform
terraform init -backend=false
terraform fmt -check
terraform validate
```

Inspect planned AWS changes when backend and credentials are configured:

```bash
cd terraform
terraform init
terraform plan -var="container_image=<account-id>.dkr.ecr.us-east-1.amazonaws.com/tf-container-build-platform/nginx:<tag>"
```

## Demo Script

1. Show the repository structure and highlight that application code, IaC, and CI/CD are version controlled together.
2. Open `.github/workflows/deploy.yml` and explain the OIDC role assumption, ECR login, image build, and Terraform apply stages.
3. Open `terraform/main.tf` and walk through the VPC, ALB, ECR, ECS, IAM, and CloudWatch resources.
4. Trigger the `oidc-debug.yml` workflow to prove AWS federation with `aws sts get-caller-identity`.
5. Trigger the deployment workflow or push to `main`.
6. Confirm the ECR image was pushed using the Git SHA tag.
7. Confirm the ECS service deployment stabilized.
8. Open the Terraform `alb_dns_name` output in a browser and verify the NGINX page responds.
9. Show CloudWatch Logs for the ECS task.

## Terraform Outputs

| Output | Purpose |
| --- | --- |
| `alb_dns_name` | Public URL target for testing the deployed application. |
| `ecr_repository_url` | Registry URL used by the build pipeline. |
| `ecs_cluster_name` | ECS cluster hosting the service. |
| `ecs_service_name` | ECS service managing the Fargate tasks. |

## Production Hardening Opportunities

- Add HTTPS listener, ACM certificate, and HTTP-to-HTTPS redirect on the ALB.
- Restrict ALB ingress CIDRs if the service is not intended to be public.
- Add ECR image scanning, lifecycle policies, and immutable tags.
- Replace single NAT Gateway with one NAT Gateway per AZ if higher availability is required.
- Add VPC endpoints for ECR, CloudWatch Logs, and S3 to reduce NAT dependency and egress cost.
- Split Terraform into modules when the project grows beyond a single service.
- Add Terraform plan review gates for pull requests before `main` deployment.
- Add container vulnerability scanning and IaC scanning in CI.
- Add ECS deployment circuit breaker and health-check tuned rollback behavior.
- Parameterize environment names for dev/stage/prod isolation.
