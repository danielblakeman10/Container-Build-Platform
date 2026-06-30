#!/bin/bash
set -e

echo "=========================================="
echo " 🚀 AWS Connection Health Check Script"
echo "=========================================="

echo "1. Checking AWS Caller Identity..."
aws sts get-caller-identity
echo "Caller identity verified."
echo ""

echo "2. Checking deployment target ECR Repository ($ECR_REPO)..."
if [ -n "$ECR_REPO" ]; then
    echo "Retrieving latest image tags:"
    aws ecr describe-images \
        --repository-name "$ECR_REPO" \
        --max-items 5 \
        --query 'imageDetails[*].imageTags' \
        --output text || echo "Failed to fetch images, or repository is currently empty."
else
    echo "ECR_REPO environment variable not set. Skipping ECR check."
fi
echo ""

echo "✅ AWS script completed successfully. Pipeline connection is healthy!"