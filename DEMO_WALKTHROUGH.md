# Container Build Platform Demo Walkthrough

Use this walkthrough to demonstrate the project as a complete DevSecOps platform story: source control, container build, AWS OIDC federation, Terraform-managed ECS delivery, existing VPC/ALB integration, runtime verification, AWS WAF, and FinOps controls.

## Demo Objective

Show that this repository is not just an application. It is a small container delivery platform that keeps application code, infrastructure as code, CI/CD automation, security controls, and cost governance in one version-controlled workflow.

Expected demo duration:

```text
15-25 minutes
```

## Before You Start

Have these pages ready in browser tabs:

| Area | Link or location |
| --- | --- |
| GitHub repository | `https://github.com/danielblakeman10/Container-Build-Platform` |
| GitHub Actions | Repository -> Actions |
| AWS ECR | AWS Console -> ECR -> Private repositories -> `man-cbp/nginx` |
| AWS ECS | AWS Console -> ECS -> Clusters -> `man-cbp-cluster` |
| AWS CloudWatch Logs | AWS Console -> CloudWatch -> Logs -> Log groups -> `/ecs/man-cbp-nginx` |
| Live demo app | `http://man-cbp-alb-1019119768.us-east-1.elb.amazonaws.com` |
| Demo ALB | AWS Console -> EC2 -> Load Balancers -> `man-cbp-alb` |
| WAF check | AWS Console -> WAF & Shield -> Web ACLs |

Local repo path:

```powershell
C:\Users\Daniel Blakeman\Documents\GitHub Repos\Projects\Container-Build-Platform
```

## 1. Open With The Platform Summary

Start on the repository `README.md`.

Presenter explanation:

```text
This project demonstrates a container build and deployment platform on AWS. GitHub Actions builds an NGINX container image, authenticates to AWS through OIDC, pushes the image to ECR, and uses Terraform to adopt and update the live `man-cbp` ECS Fargate service behind an Application Load Balancer protected by AWS WAF.
```

Point out the major README sections:

- Application Flow Diagram
- Solution Architecture Diagram
- AWS VPC Diagram
- CI/CD Operating Model
- Estimated Cost and FinOps Budget
- Production Hardening Opportunities

Why this matters:

```text
The README is written as an operator-facing architecture document, not just a code note. It explains how the platform works, how it is deployed, how it is verified, and where the main security and cost tradeoffs are.
```

## 2. Show The Repository Structure

Open the repo root and explain the folders:

```text
.github/workflows/   CI/CD automation
nginx/               Application code and Dockerfile
terraform/           Infrastructure as Code
README.md            Architecture, diagrams, CI/CD model, and FinOps budget
DEMO_WALKTHROUGH.md  Presenter walkthrough
.gitignore           Prevents local Terraform state and tfvars from being committed
```

Presenter explanation:

```text
The application code, infrastructure, and delivery automation are version controlled together. That gives us repeatability, reviewability, and a clear audit trail for platform changes.
```

Key files to mention:

| File | Why it matters |
| --- | --- |
| `.github/workflows/deploy.yml` | Main deployment workflow. Builds, pushes, and deploys. |
| `.github/workflows/oidc-debug.yml` | Manual workflow to verify GitHub-to-AWS OIDC federation. |
| `nginx/Dockerfile` | Defines the container image. |
| `nginx/app/index.html` | Simple demo workload served by NGINX. |
| `terraform/main.tf` | Creates isolated dev/uat stacks, uses existing prod `man-cbp` network and ALB resources, then manages the ECS delivery path, ECR, logs, and WAF association. |
| `terraform/backend.tf` | Configures Terraform version, AWS provider, and S3 remote backend. |
| `terraform/terraform.tfvars.example` | Safe placeholder showing expected runtime variable format. |

## 3. Explain The Application Container

Open:

```text
nginx/Dockerfile
nginx/app/index.html
```

Presenter explanation:

```text
The workload is intentionally simple: an NGINX Alpine image serving static HTML. That keeps the focus on the delivery platform rather than application complexity. The container image is built by GitHub Actions and pushed to ECR with the Git commit SHA as the image tag.
```

Highlight:

```dockerfile
FROM nginx:1.27-alpine
COPY app/ /usr/share/nginx/html/
EXPOSE 80
```

Why this matters:

```text
This is the artifact that moves through the pipeline. The platform pattern would work the same way for a more complex backend or frontend container.
```

## 4. Walk Through The CI/CD Workflow

Open:

```text
.github/workflows/deploy.yml
```

Explain the workflow in order:

| Stage | What happens | Why it matters |
| --- | --- | --- |
| Trigger | Runs on push to `dev` or manual `workflow_dispatch`. | Supports automated and operator-triggered promotion through dev, uat, and prod. |
| Permissions | Grants `id-token: write` and `contents: read`. | Enables OIDC federation without static AWS keys. |
| AWS credentials | Uses `aws-actions/configure-aws-credentials@v4`. | Exchanges GitHub identity for short-lived AWS credentials. |
| ECR login | Uses `aws-actions/amazon-ecr-login@v2`. | Authenticates Docker to push into private ECR. |
| Docker build | Builds the image from `./nginx`. | Creates the deployable container artifact. |
| Image tag | Tags the image with `${{ github.sha }}`. | Creates immutable traceability from running image to source commit. |
| Terraform init | Initializes backend with `TF_STATE_KEY` from the active GitHub Environment. | Keeps dev, uat, and prod state isolated. |
| Terraform apply | Applies with the environment tfvars file and `container_image=<new-image-uri>`. | Updates AWS infra and the ECS task definition. |
| Promotion | Runs dev first, then uat, then prod. | Promotes the same image URI instead of rebuilding for each environment. |

Presenter explanation:

```text
The deployment pipeline builds a new image on every dev branch push, pushes it to ECR with the commit SHA, and passes that exact image URI into Terraform. Dev, uat, and prod receive the same artifact, which gives us traceability from Git commit to deployed ECS task definition.
```

## 5. Explain OIDC Role Assumption

Still in `deploy.yml`, point to:

```yaml
permissions:
  id-token: write
  contents: read
```

And:

```yaml
role-to-assume: ${{ vars.AWS_ROLE_ARN }}
```

Presenter explanation:

```text
OIDC role assumption means GitHub Actions does not need long-lived AWS access keys. The workflow requests a signed OIDC token from GitHub. AWS IAM validates that token against the role trust policy, then AWS STS issues short-lived credentials to the workflow. This is cleaner and safer than storing static cloud keys as repository secrets.
```

Security value:

- No long-lived AWS access keys in GitHub Secrets.
- Trust can be scoped to repository, branch, and workflow.
- AWS CloudTrail can record the assumed role activity.
- Credential lifetime is short and managed by AWS STS.

## 6. Show The OIDC Debug Workflow

Open:

```text
.github/workflows/oidc-debug.yml
```

Presenter explanation:

```text
This workflow is a federation test. It is not where OIDC is created; the OIDC provider and IAM trust policy live in AWS. This workflow proves the trust path by assuming an AWS role and running `aws sts get-caller-identity`.
```

What to show:

```yaml
aws sts get-caller-identity
```

Expected proof:

```text
If this command succeeds, GitHub Actions successfully federated into AWS and received temporary AWS credentials.
```

## 7. Walk Through Terraform Infrastructure

Open:

```text
terraform/main.tf
```

Walk through the resources in this order:

| Area | Terraform resources | Explanation |
| --- | --- | --- |
| VPC foundation | `aws_vpc.main` or `data.aws_vpc.existing` | Creates dev/uat VPCs and looks up the existing prod `man-cbp-vpc`. |
| Subnets | `aws_subnet.*` or `data.aws_subnet.*` | Creates dev/uat public/private subnets and uses existing prod subnets. |
| Security groups | `aws_security_group.*` or `data.aws_security_group.*` | Creates dev/uat ALB/task security groups and uses existing prod groups. |
| Load balancing | `aws_lb.*` or `data.aws_lb.existing` | Creates dev/uat ALBs and target groups; prod uses `man-cbp-alb`. |
| Registry | `aws_ecr_repository.nginx` | Stores the container image pushed by CI/CD. |
| Compute | `aws_ecs_cluster`, `aws_ecs_task_definition`, `aws_ecs_service` | Runs the NGINX container on Fargate. |
| IAM | `ecs_task_execution_role_arn` variable | Uses the existing ECS task execution role. |
| Observability | `aws_cloudwatch_log_group.nginx` | Centralizes task logs with retention. |
| Edge security | `aws_wafv2_web_acl_association.alb` | Keeps the regional Web ACL associated with the prod ALB when `web_acl_arn` is set. |

Presenter explanation:

```text
The public layer is the ALB. The workload layer is ECS Fargate in the `man-cbp` private subnets. The task security group only accepts traffic from the ALB security group, which is the core network control for this demo.
```

## 8. Show The AWS VPC Design

Open the `AWS VPC Diagram` section in `README.md`.

Presenter explanation:

```text
The VPC uses a public/private subnet pattern across two Availability Zones. The ALB is public and spans public subnets. ECS task ingress is controlled by the task security group, which only allows traffic from the ALB security group. NAT Gateway provides outbound routing for private route tables.
```

Call out:

- VPC CIDR: `10.0.0.0/16`
- Public subnets:
  - `10.0.0.0/20`
  - `10.0.16.0/20`
- Private subnets:
  - `10.0.128.0/20`
  - `10.0.144.0/20`
- ALB accepts inbound HTTP.
- ECS tasks are not directly internet-accessible.

## 9. Trigger Or Show The Deployment

In GitHub:

```text
Repository -> Actions -> Deploy nginx to Fargate -> Run workflow
```

Or explain that a push to `dev` triggers the promotion pipeline automatically.

Presenter explanation:

```text
This workflow represents the deployment control plane. A push to dev creates a new image, pushes it to ECR, deploys dev, waits at the uat/prod GitHub Environment gates if configured, and updates each ECS service using Terraform.
```

If you do not want to trigger a fresh deployment during the demo, open the latest successful run and walk through the completed steps.

## 10. Confirm The Demo ALB Target

For the live demo, use:

```text
man-cbp-alb
```

Live URL:

```text
http://man-cbp-alb-1019119768.us-east-1.elb.amazonaws.com
```

Presenter explanation:

```text
This is the Application Load Balancer I am using as the live demo endpoint. The ALB receives public HTTP traffic and forwards it to the backend target group on port 80.
```

Current verified response:

```text
HTTP/1.1 200 OK
Server: nginx/1.27.5
```

CLI verification:

```bash
curl -I http://man-cbp-alb-1019119768.us-east-1.elb.amazonaws.com
```

The verified target group for this ALB is:

```text
man-cbp-vpc
```

## 11. Verify The ECR Image

In AWS Console:

```text
ECR -> Private repositories -> man-cbp/nginx -> Images
```

What to show:

- Image tag is a Git commit SHA.
- Latest image should align with the latest commit that triggered the workflow.

Presenter explanation:

```text
Using the Git SHA as the image tag gives build provenance. If an ECS task is running a specific image tag, we can trace it directly back to the source commit and pipeline run.
```

CLI verification:

```bash
aws ecr describe-images \
  --repository-name man-cbp/nginx \
  --region us-east-1 \
  --query "reverse(sort_by(imageDetails,& imagePushedAt))[0]"
```

## 12. Verify ECS Service Health

In AWS Console:

```text
ECS -> Clusters -> man-cbp-cluster
-> Services -> man-cbp-nginx-service
```

What to show:

- Service status: `ACTIVE`
- Desired tasks: `1`
- Running tasks: `1`
- Pending tasks: `0`
- Latest task definition revision

Presenter explanation:

```text
The ECS service is the runtime reconciliation loop. It keeps the desired count running and registers healthy tasks into the ALB target group.
```

CLI verification:

```bash
aws ecs describe-services \
  --cluster man-cbp-cluster \
  --services man-cbp-nginx-service \
  --region us-east-1 \
  --query "services[0].{Status:status,Desired:desiredCount,Running:runningCount,Pending:pendingCount,TaskDef:taskDefinition}"
```

## 13. Open The Live Application

Open:

```text
http://man-cbp-alb-1019119768.us-east-1.elb.amazonaws.com
```

Expected result:

```text
Hello from Container-Build-Platform
```

Presenter explanation:

```text
This request enters through the public ALB, is forwarded to the target group, and lands on the private ECS Fargate task running the NGINX container.
```

CLI verification:

```bash
curl -I http://man-cbp-alb-1019119768.us-east-1.elb.amazonaws.com
```

Expected:

```text
HTTP/1.1 200 OK
Server: nginx
```

## 14. Show CloudWatch Logs

In AWS Console:

```text
CloudWatch -> Logs -> Log groups -> /ecs/man-cbp-nginx
```

Open a recent log stream similar to:

```text
nginx/nginx/<task-id>
```

Presenter explanation:

```text
The ECS task definition configures the `awslogs` log driver, so container logs are centralized into CloudWatch. That gives operators a standard place to inspect runtime behavior without SSH or direct host access.
```

CLI verification:

```bash
aws logs describe-log-streams \
  --log-group-name /ecs/man-cbp-nginx \
  --region us-east-1 \
  --order-by LastEventTime \
  --descending \
  --max-items 5
```

## 15. Show The WAF Security Control Status

Open:

```text
AWS Console -> WAF & Shield -> Web ACLs
```

Known WAF found in the account:

```text
dcb-container-build-platform-waf
```

Current demo association:

```text
The regional Web ACL `dcb-container-build-platform-waf` is associated with the live demo ALB `man-cbp-alb`.
```

Presenter explanation:

```text
AWS WAF sits at the ALB edge and evaluates inbound HTTP requests before they reach the ECS workload. The Web ACL can use AWS managed rules, IP allow/block lists, rate-based rules, geo controls, SQL injection protections, common exploit protections, bot controls, and CloudWatch metrics with sampled requests.
```

Active rule coverage to mention:

- AWS managed Anti-DDoS rule set.
- IPv4 and IPv6 allow/block controls.
- Geo rule.
- Global and method-specific rate-based rules.
- Body size restriction rule.
- Amazon IP reputation list.
- Anonymous IP list.
- Common rule set.
- SQL injection rule set.
- Admin protection rule set.
- Bot Control rule set.

CLI verification for the live demo ALB:

```bash
aws wafv2 get-web-acl-for-resource \
  --resource-arn arn:aws:elasticloadbalancing:us-east-1:866934333672:loadbalancer/app/man-cbp-alb/9b517443193e7a3d \
  --region us-east-1
```

Expected result:

```text
The command returns `dcb-container-build-platform-waf` with the associated Web ACL ARN and rules.
```

## 16. Explain The CI/CD Operating Model

Open the `CI/CD Operating Model` section in `README.md`.

Presenter explanation:

```text
The current repo is a compact single-account implementation, but the operating model describes how this pattern scales: tooling foundation, account bootstrap, and app deployment. That mirrors how mature AWS delivery platforms separate trust setup, environment setup, and application release workflows.
```

Talk through:

- Keyless AWS access through OIDC.
- Git SHA image tagging.
- Terraform remote state.
- Branch-to-environment promotion model.
- Approval gates for production.
- Governance controls before production apply.

Why this matters:

```text
The project demonstrates the current implementation and also documents the growth path toward a multi-environment production operating model.
```

## 17. Explain The FinOps Budget

Open the `Estimated Cost and FinOps Budget` section in `README.md`.

Presenter explanation:

```text
This stack is small, but it still has real always-on costs. The estimated always-on budget is roughly $85-$100 per month. The important FinOps insight is that Fargate is not the largest cost driver at this size. The persistent network edge components, especially NAT Gateway and ALB, create most of the baseline cost.
```

Call out the cost drivers:

| Cost driver | Why it matters |
| --- | --- |
| NAT Gateway | Hourly charge plus per-GB processing. |
| ALB | Hourly charge plus LCU usage. |
| Public IPv4 | Hourly charge for public IPv4 addresses. |
| Fargate | Scales with CPU, memory, desired count, and running hours. |
| CloudWatch | Scales with log ingestion, retention, and metrics. |

FinOps controls to mention:

- AWS Budgets at `$25`, `$50`, and `$100`.
- Consistent cost allocation tags.
- ECR lifecycle policies.
- Teardown of non-production demo environments.
- VPC endpoints for ECR, S3, and CloudWatch Logs if NAT traffic becomes material.
- Cost Explorer grouped by project and service tags.

## 18. Explain The New Terraform Hygiene Additions

Open:

```text
.gitignore
terraform/terraform.tfvars.example
```

Presenter explanation:

```text
The repo now ignores local Terraform variable files and state artifacts. That prevents machine-specific or sensitive configuration from being accidentally committed. The committed `terraform.tfvars.example` shows the expected variable format without exposing environment-specific values.
```

Show `.gitignore` rules:

```gitignore
terraform/.terraform/
terraform/*.tfstate
terraform/*.tfstate.backup
terraform/*.tfvars
terraform/*.tfvars.json
```

Show example file:

```hcl
container_image = "<account-id>.dkr.ecr.us-east-1.amazonaws.com/man-cbp/nginx:<tag>"
```

Why this matters:

```text
This is basic Terraform repository hygiene: state and local variable values should not be committed. The example file keeps the project understandable without leaking real deployment configuration.
```

## 19. Close With Production Hardening

Open the `Production Hardening Opportunities` section in `README.md`.

Presenter explanation:

```text
The current implementation is demo-ready and intentionally compact. The documented hardening path is HTTPS with ACM, tighter ingress controls, ECR scanning and lifecycle policies, VPC endpoints, Terraform module boundaries, PR-based plan review, deployment rollback controls, and environment isolation.
```

Strong closing line:

```text
This project demonstrates the core control loops of a production container platform: source-controlled infrastructure, keyless cloud authentication, immutable container artifacts, private runtime networking, observable ECS workloads, and explicit FinOps controls.
```

## Quick Demo Checklist

Use this checklist during the actual presentation:

- [ ] Open GitHub repo and README.
- [ ] Explain app, IaC, and CI/CD are version controlled together.
- [ ] Show `nginx/Dockerfile` and `index.html`.
- [ ] Show `.github/workflows/deploy.yml`.
- [ ] Explain OIDC role assumption.
- [ ] Show `.github/workflows/oidc-debug.yml`.
- [ ] Walk through `terraform/main.tf`.
- [ ] Show README architecture and VPC diagrams.
- [ ] Open latest GitHub Actions deployment run.
- [ ] Verify ECR image tag uses Git SHA.
- [ ] Verify ECS service is active with 1 running task.
- [ ] Open ALB URL and show NGINX response.
- [ ] Show CloudWatch log group and log stream.
- [ ] Show WAF Web ACL status and explain whether it is associated with the live demo ALB.
- [ ] Explain CI/CD operating model.
- [ ] Explain FinOps budget and cost drivers.
- [ ] Explain `.gitignore` and `terraform.tfvars.example`.
- [ ] Close with production hardening roadmap.

## Useful Commands

```bash
aws sts get-caller-identity
```

```bash
aws ecr describe-images \
  --repository-name man-cbp/nginx \
  --region us-east-1 \
  --query "reverse(sort_by(imageDetails,& imagePushedAt))[0]"
```

```bash
aws ecs describe-services \
  --cluster man-cbp-cluster \
  --services man-cbp-nginx-service \
  --region us-east-1 \
  --query "services[0].{Status:status,Desired:desiredCount,Running:runningCount,Pending:pendingCount,TaskDef:taskDefinition}"
```

```bash
aws logs describe-log-streams \
  --log-group-name /ecs/man-cbp-nginx \
  --region us-east-1 \
  --order-by LastEventTime \
  --descending \
  --max-items 5
```

```bash
curl -I http://man-cbp-alb-1019119768.us-east-1.elb.amazonaws.com
```
