# Container Build Platform

> 🐳 Production-grade container build and registry platform with CI/CD pipeline, multi-stage Dockerfiles, vulnerability scanning, image signing, and ECR integration.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Docker](https://img.shields.io/badge/Docker-Best%20Practices-blue)](https://docs.docker.com/build/building/best-practices/)
[![GitHub Actions](https://github.com/danielblakeman10/Container-Build-Platform/actions/workflows/ci.yml/badge.svg)](https://github.com/danielblakeman10/Container-Build-Platform/actions)
[![Trivy](https://img.shields.io/badge/Security-Trivy-green)](https://github.com/aquasecurity/trivy)
[![AWS ECR](https://img.shields.io/badge/Registry-AWS%20ECR-orange)](https://aws.amazon.com/ecr/)
![Tag Strategy](https://img.shields.io/badge/Tags-SemVer%20%2B%20SHA-brightgreen)

## 🏗 Architecture


```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌──────────────┐
│   Git Push  │───▶│  CI Pipeline│───▶│  Build &   │───▶│   Scan &   │
│             │    │  (GitHub    │    │  Test      │    │   Sign     │
│             │    │   Actions)  │    │             │    │            │
└─────────────┘    └─────────────┘    └─────────────┘    └──────┬───────┘
                                                                │
                                              ┌─────────────────▼──────────┐
                                              │     AWS ECR Registry       │
                                              │   ┌─────────┐  ┌───────┐  │
                                              │   │  Latest │  │ SHA  │  │
                                              │   │  Tag    │  │Tag   │  │
                                              │   └─────────┘  └───────┘  │
                                              └────────────────────────────┘
┌─────────────┐    ┌─────────────┐    ┌─────────────┐              │
│Notary Sign │◀───│  Trivy Scan │◀───│  Docker    │◀───────────────┘
│  (Cosign)  │    │  (CVE/      │    │  Build     │
│             │    │   Config)   │    │             │    ┌───────────┴──────────┐
└─────────────┘    └─────────────┘    └─────────────┘    │  Cleanup Jobs        │
                                                         │  - Unused images     │
                                                         │  - Expired tags      │
                                                         │  - Old artifacts     │
                                                         └────────────────────────┘
```

## Pipeline Stages

| Stage | Description | Tools | Gate |
|-------|-------------|-------|------|
| 1 | **Build** | Multi-stage Dockerfile | ✅ Required |
| 2 | **Test** | Unit/integration tests | ✅ Required |
| 3 | **Scan** | Trivy (CVE + misconfig) | ⚠️ WARN on High, FAIL on Critical |
| 4 | **Push** | AWS ECR | ✅ Required |
| 5 | **Sign** | Cosign/Notary | ⚠️ Recommended |
| 6 | **Cleanup** | Image lifecycle management | 📋 Scheduled |

## Features

- ✅ **Multi-Stage Docker Builds**: Optimized image size and reduced attack surface
- ✅ **CI/CD Pipeline**: GitHub Actions with build → test → scan → push workflow
- ✅ **Vulnerability Scanning**: Trivy for CVE detection and image misconfigurations
- ✅ **Image Tagging**: Semantic versioning + commit SHA strategy
- ✅ **AWS ECR Integration**: Secure image storage with lifecycle policies
- ✅ **AWS CodeBuild Alternative**: Parallel build configuration for AWS-native CI
- ✅ **Image Signing**: Cosign for SBOM generation and signature verification
- ✅ **Image Cleanup**: Automated lifecycle management for unused/expired images
- ✅ **Multi-Architecture**: Build for amd64 and arm64

## Folder Structure

```
Container-Build-Platform/
├── dockerfiles/
│   ├── Dockerfile                     # Multi-stage Dockerfile template
│   ├── .dockerignore                  # Docker ignore patterns
│   └── docker-compose.dev.yml         # Development compose
├── .github/
│   └── workflows/
│       ├── ci.yml                     # Main CI pipeline
│       ├── ecr.yml                    # ECR lifecycle management
│       └── signing.yml                # Image signing workflow
│   └── scripts/
│       ├── parse-version.sh           # Parse semver from tags
│       ├── image-tagging.sh           # Generate image tags
│       └── cleanup-ecr.sh             # ECR image cleanup
├── terraform/
│   └── modules/
│       └── ecs-builder/               # ECR + ECR lifecycle module
│           ├── main.tf
│           ├── variables.tf
│           └── outputs.tf
├── examples/
│   ├── python-app/
│   │   ├── Dockerfile
│   │   ├── main.py
│   │   └── requirements.txt
│   └── node-app/
│       ├── Dockerfile
│       ├── index.js
│       └── package.json
├── registry/
│   └── lifecycle-policy.json          # ECR lifecycle policy
├── README.md
├── .gitignore
└── LICENSE
```

## Quickstart

### Prerequisites

- Docker 24.0+
- AWS CLI configured
- `cosign` installed (optional, for signing)
- `trivy` installed (optional, for local scanning)

### Build and Push

```bash
# Clone the repo
git clone https://github.com/danielblakeman10/Container-Build-Platform.git
cd Container-Build-Platform

# Build locally (multi-stage)
docker build -t myapp:latest -f dockerfiles/Dockerfile .

# Run tests
docker run --rm myapp:latest npm test

# Scan for vulnerabilities
trivy image myapp:latest

# Tag with semantic version
docker tag myapp:latest myapp:1.2.3
docker tag myapp:latest myapp:abc1234

# Push to ECR
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin <account>.dkr.ecr.us-east-1.amazonaws.com
docker push <account>.dkr.ecr.us-east-1.amazonaws.com/myapp:1.2.3
```

### Using the CI Pipeline

```yaml
# .github/workflows/ci.yml
name: Container Build Pipeline
on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  build-and-push:
    uses: danielblakeman10/Container-Build-Platform/.github/workflows/ci.yml@main
```

## Security Best Practices

### Dockerfile Best Practices

```dockerfile
# ✅ GOOD: Multi-stage build with non-root user
FROM golang:1.21-alpine AS builder
WORKDIR /app
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -o /server .

FROM alpine:3.19
RUN addgroup -S appgroup && adduser -S appuser -G appgroup
USER appuser
COPY --from=builder /server /server
ENTRYPOINT ["/server"]
```

```dockerfile
# ❌ BAD: Running as root, single-stage, cached credentials
FROM ubuntu:latest
RUN apt-get update && apt-get install -y curl
COPY . .
# No USER instruction = runs as root
```

### Image Tagging Strategy

| Tag Type | Example | Use Case |
|----------|---------|----------|
| Latest | `myapp:latest` | Development, always points to newest |
| Semantic Version | `myapp:1.2.3` | Production releases |
| SemVer + Range | `myapp:1.2`, `myapp:1` | Staging, latest patch |
| Commit SHA | `myapp:abc1234` | Reproducible builds |
| Timestamp | `myapp:20240115-abc1234` | Audit trail |

### Trivy Scan Configuration

```yaml
# .github/workflows/trivy.yml
- name: Run Trivy vulnerability scanner
  uses: aquasecurity/trivy-action@master
  with:
    image-ref: '${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:${{ github.sha }}'
    format: 'table'
    severity: 'CRITICAL,HIGH'
    exit-code: '1'
    ignore-unfixed: true
```

## Image Lifecycle Management

### ECR Lifecycle Policy

```json
{
  "rules": [
    {
      "rulePriority": 1,
      "description": "Keep last 30 images and 90 days of latest tags",
      "selection": {
        "tagStatus": "any",
        "countType": "imageCountMoreThan",
        "countNumber": 30
      },
      "action": {
        "type": "expire"
      }
    },
    {
      "rulePriority": 2,
      "description": "Keep images tagged with 'latest' for 90 days",
      "selection": {
        "tagStatus": "tagged",
        "tagPrefixList": ["latest"],
        "countType": "olderThan",
        "countNumber": 90
      },
      "action": {
        "type": "expire"
      }
    },
    {
      "rulePriority": 3,
      "description": "Delete untagged images older than 7 days",
      "selection": {
        "tagStatus": "untagged",
        "countType": "olderThan",
        "countNumber": 7
      },
      "action": {
        "type": "expire"
      }
    }
  ]
}
```

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/add-python-dockerfile`)
3. Commit your changes (`git commit -m 'feat: add Python multi-stage Dockerfile'`)
4. Push to the branch (`git push origin feature/add-python-dockerfile`)
5. Open a Pull Request

## License

MIT License - see [LICENSE](LICENSE) file for details.
