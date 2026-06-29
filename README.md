# Container Build Platform

<p align="center">
  <img src="https://img.shields.io/badge/Status-Production%20Ready-brightgreen" alt="Status">
  <img src="https://img.shields.io/badge/Infrastructure-AWS%20ECR-blue" alt="AWS ECR">
  <img src="https://img.shields.io/badge/CI/CD-GitHub%20Actions-orange" alt="CI/CD">
  <img src="https://img.shields.io/badge/Security-Trivy%20Scan-red" alt="Security Scan">
  <img src="https://img.shields.io/badge/License-MIT-lightgrey" alt="License">
</p>

## 🏭 Enterprise Container Factory

A centralized, secure, and automated container build platform that turns source code into production-ready container images with integrated vulnerability scanning, automated tagging, and secure registry publishing.

## 🚀 Features

| Feature | Description |
|---------|-------------|
| **Multi-Arch Builds** | Build for `arm64`, and more from a single pipeline |
| **Vulnerability Scanning** | Trivy integration scans every image before promotion to prod |
| **ECR Publishing** | Automated push to Amazon ECR with lifecycle policies |
| **Automated Tagging** | Semantic versioning + git SHA + build timestamp strategy |
| **Security Gates** | Block deployment on critical/high CVEs |
| **Docker Standards** | Multi-stage builds, .dockerignore, distroless base images |
| **Build Caching** | Layer caching for faster rebuilds |

## 🏗 Architecture

```
┌──────────────┐     ┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│   GitHub     │────▶│  GitHub      │────▶│   Trivy      │────▶│   Amazon     │
│   (Source)   │     │  Actions     │     │  (Scan)      │     │   ECR        │
│              │     │  (Build)     │     │              │     │  (Registry)  │
└──────────────┘     └──────────────┘     └──────────────┘     └──────────────┘
                                                    │
                                                    ▼
                                             ┌──────────────┐
                                             │  Security    │
                                             │  Gate        │
                                             │  (Pass/Fail) │
                                             └──────────────┘
```

## 📁 Project Structure

```
├── .github/
│   └── workflows/
│       ├── build.yml            # Main build pipeline
│       ├── scan.yml             # Vulnerability scanning
│       └── release.yml          # Release tagging + ECR push
├── dockerfiles/
│   ├── Dockerfile               # Multi-stage production build
│   ├── Dockerfile.alpine        # Alpine variant
│   └── .dockerignore            # Build context rules
├── scripts/
│   ├── tag-image.sh             # Semantic versioning + SHA tags
│   ├── scan-image.sh            # Trivy scan + severity check
│   └── push-to-ecr.sh           # ECR authentication + push
├── policies/
│   ├── ecr-lifecycle.json       # Image lifecycle policy
│   └── ecr-repo-policy.json     # Repository access policy
├── README.md
├── .gitignore
└── LICENSE
```

## 🛠 Tech Stack

| Technology | Purpose |
|-----------|---------|
| **Docker** | Container image builds |
| **GitHub Actions** | CI/CD pipeline orchestration |
| **Amazon ECR** | Secure container registry |
| **Trivy** | Vulnerability scanning |
| **AWS IAM** | Least-privilege build permissions |
| **AWS S3** | Build artifact storage |
| **AWS Secrets Manager** | Secure credential management |

## 🚦 Quick Start

### 1. Configure Secrets

```bash
# GitHub Repository Settings > Secrets
AWS_ACCESS_KEY_ID        # ECR access
AWS_SECRET_ACCESS_KEY    # ECR secret
ECR_REPOSITORY           # e.g., platform-api
ECR_REGION               # e.g., us-east-2
```

### 2. Build an Image

```bash
# Local build
docker build -t myapp:latest -f dockerfiles/Dockerfile .

# Multi-arch build
docker buildx build --platform linux/amd64,linux/arm64 \
  -t myapp:latest -t myapp:v1.2.3 \
  --push -f dockerfiles/Dockerfile .
```

### 3. Scan & Push

```bash
# Scan for vulnerabilities
./scripts/scan-image.sh myapp:latest

# Push to ECR
./scripts/push-to-ecr.sh myapp latest
```

### 4. Automate with CI/CD

```yaml
# .github/workflows/build.yml
name: Build & Push

on:
  push:
    branches: [main]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Build image
        run: docker build -t myapp:${{ github.sha }} .
      - name: Scan
        run: ./scripts/scan-image.sh myapp:${{ github.sha }}
      - name: Push to ECR
        run: ./scripts/push-to-ecr.sh myapp ${{ github.sha }}
```

## 📊 Tagging Strategy

| Tag Format | Example | Usage |
|-----------|---------|-------|
| `v1.2.3` | `myapp:v1.2.3` | Semantic version (release) |
| `sha256:abc...` | `myapp:sha256:abc123` | Git commit SHA (immutable) |
| `latest` | `myapp:latest` | Dev/staging only (never prod) |
| `build-42` | `myapp:build-42` | CI build number (ephemeral) |

## 🔒 Security

- **Multi-stage builds** — no build tools in final image
- **Non-root user** in containers
- **Distroless/alpine base images** — minimal attack surface
- **Trivy scan** — blocks critical/high CVEs
- **ECR policies** — least-privilege access
- **Secrets Manager** — no hardcoded credentials
- **IAM roles** — CI/CD assumes scoped permissions

## 📦 Deliverables

- ✅ **Build scripts** — Automated multi-stage builds with tag management
- ✅ **Dockerfile standards** — Production-ready, multi-arch Dockerfiles
- ✅ **Security scanning** — Trivy integration with severity gates
- ✅ **ECR publishing** — Automated push with lifecycle policies
- ✅ **GitHub Actions CI/CD** — End-to-end build pipeline

## 🏢 Enterprise Value

This platform is **essential for**:
- **Platform Engineering** — Centralized container factory for all teams
- **DevSecOps** — Security scanning built into every build
- **Kubernetes Teams** — Reliable image registry for cluster deployments
- **Compliance** — Audit trail of all images, scans, and deployments

## 📄 License

MIT License — see `LICENSE` for details.
