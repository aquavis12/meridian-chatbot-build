#!/usr/bin/env bash
# Step 0 — create the S3 Vectors bucket + index BEFORE the CFN stack.
# CloudFormation has no resource type for these yet, so they're made here
# and their ARNs are passed into the stack as parameters.
# Usage: ./scripts/00-bootstrap-vectors.sh [region]
set -euo pipefail
REGION="${1:-us-east-1}"
ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
VBUCKET="meridian-vectors-${ACCOUNT}"
INDEX="meridian-kb-index"

echo "==> Creating S3 vector bucket $VBUCKET ..."
aws s3vectors create-vector-bucket --vector-bucket-name "$VBUCKET" --region "$REGION" 2>/dev/null || \
  echo "    (already exists)"

echo "==> Creating index $INDEX (1024-dim, cosine — must match Titan V2) ..."
aws s3vectors create-index \
  --vector-bucket-name "$VBUCKET" \
  --index-name "$INDEX" \
  --dimension 1024 \
  --distance-metric cosine \
  --data-type float32 \
  --region "$REGION" 2>/dev/null || echo "    (already exists)"

VBUCKET_ARN="arn:aws:s3vectors:${REGION}:${ACCOUNT}:bucket/${VBUCKET}"
INDEX_ARN="arn:aws:s3vectors:${REGION}:${ACCOUNT}:bucket/${VBUCKET}/index/${INDEX}"
echo
echo "==> Pass these to the stack:"
echo "    VectorBucketArn=$VBUCKET_ARN"
echo "    VectorIndexArn=$INDEX_ARN"
