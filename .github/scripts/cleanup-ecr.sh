#!/bin/bash
# cleanup-ecr.sh - Clean up unused/expired images from ECR
# Usage: ./scripts/cleanup-ecr.sh <repository-uri> [days-to-keep] [max-images-to-keep]
#
# This script removes images that don't match:
# - Images older than N days (default: 30)
# - Images beyond max count (default: 50)
# - Untagged images (configurable)

set -euo pipefail

ECR_REPO="${1:-myapp}"
DAYS_TO_KEEP="${2:-30}"
MAX_IMAGES="${3:-50}"
DRY_RUN="${4:-false}"

# Get AWS region from environment or default
AWS_REGION="${AWS_REGION:-us-east-1}"

# Get AWS account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo "unknown")

ECR_URI="${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO}"

echo "🧹 ECR Cleanup Script"
echo "   Repository: $ECR_URI"
echo "   Region: $AWS_REGION"
echo "   Keep images younger than: ${DAYS_TO_KEEP} days"
echo "   Keep maximum: $MAX_IMAGES images"
echo "   Mode: $([ "$DRY_RUN" = "true" ] && echo 'DRY RUN' || echo 'ACTUAL')"
echo ""

# Get all images with their push dates
echo "Scanning images..."
images=$(aws ecr list-images \
    --repository-name "$ECR_REPO" \
    --region "$AWS_REGION" \
    --query 'images[*] | sort_by(@, &imagePushTime) | [*]' \
    --output json 2>/dev/null || echo "[]")

total=$(echo "$images" | jq 'length')
echo "Total images in repository: $total"
echo ""

# Images to delete
delete_tags=()

# Strategy 1: Remove untagged images older than 7 days
if [ "$DRY_RUN" != "true" ]; then
    while IFS= read -r image; do
        if [ -z "$image" ] || [ "$image" = "null" ]; then
            continue
        fi
        
        image_digest=$(echo "$image" | jq -r '.imageDigest // empty')
        image_tags=$(echo "$image" | jq -r '.imageTags // [] | length')
        image_push_time=$(echo "$image" | jq -r '.imagePushTime // "2000-01-01T00:00:00Z"')
        
        if [ "$image_tags" -eq 0 ]; then
            # Check if older than 7 days
            cutoff_epoch=$(date -d "-7 days" +%s 2>/dev/null || date -v-7d +%s 2>/dev/null || echo 0)
            push_epoch=$(date -d "$image_push_time" +%s 2>/dev/null || echo 0)
            
            if [ "$push_epoch" -lt "$cutoff_epoch" ]; then
                delete_tags+=("$image_digest")
                echo "   🗑️  Will remove untagged: $image_digest (pushed: $image_push_time)"
            fi
        fi
    done < <(echo "$images" | jq -c '.[]')
fi

# Strategy 2: If we have more than MAX_IMAGES, remove oldest
if [ "$DRY_RUN" != "true" ] && [ "$total" -gt "$MAX_IMAGES" ]; then
    overflow=$((total - MAX_IMAGES))
    echo "   ⚠️  Total ($total) exceeds limit ($MAX_IMAGES). Will remove $overflow oldest images."
    
    while IFS= read -r image; do
        if [ -z "$image" ] || [ "$image" = "null" ]; then
            continue
        fi
        
        image_digest=$(echo "$image" | jq -r '.imageDigest // empty')
        
        if [ -n "$image_digest" ] && [ ${#delete_tags[@]} -lt "$overflow" ]; then
            delete_tags+=("$image_digest")
        fi
    done < <(echo "$images" | jq -c '.[]')
fi

# Execute deletion
if [ "$DRY_RUN" = "true" ]; then
    echo ""
    echo "🔍 DRY RUN complete. $(( ${#delete_tags[@]} )) images would be deleted."
else
    if [ ${#delete_tags[@]} -eq 0 ]; then
        echo "✅ No images to delete."
        exit 0
    fi
    
    echo ""
    echo "Deleting $(( ${#delete_tags[@]} )) images..."
    
    # Remove duplicates
    unique_tags=($(printf '%s\n' "${delete_tags[@]}" | sort -u))
    
    for digest in "${unique_tags[@]}"; do
        echo "   Deleting: $digest"
        aws ecr batch-delete-image \
            --repository-name "$ECR_REPO" \
            --region "$AWS_REGION" \
            --image-ids imageDigest="$digest" \
            --query 'images[].imageDigest' \
            --output text 2>/dev/null || echo "   ⚠️  Failed to delete: $digest"
    done
    
    echo ""
    echo "✅ Cleanup complete."
fi
