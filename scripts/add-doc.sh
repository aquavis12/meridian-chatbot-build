#!/usr/bin/env bash
# Manually add ONE more document to the KB and re-sync.
# Usage: ./scripts/add-doc.sh path/to/newfile.pdf [region]
set -euo pipefail
FILE="${1:?path to a .pdf/.txt/.md/.html to add}"
REGION="${2:-us-east-1}"
STACK="meridian-chatbot"
BUCKET=$(aws cloudformation describe-stacks --stack-name "$STACK" --region "$REGION" \
  --query "Stacks[0].Outputs[?OutputKey=='SourceBucket'].OutputValue" --output text)
KB_ID=$(aws cloudformation describe-stacks --stack-name "$STACK" --region "$REGION" \
  --query "Stacks[0].Outputs[?OutputKey=='KnowledgeBaseId'].OutputValue" --output text)
DS_ID=$(aws cloudformation describe-stacks --stack-name "$STACK" --region "$REGION" \
  --query "Stacks[0].Outputs[?OutputKey=='DataSourceId'].OutputValue" --output text)

echo "==> Uploading $(basename "$FILE") ..."
aws s3 cp "$FILE" "s3://$BUCKET/$(basename "$FILE")"
echo "==> Re-syncing the knowledge base ..."
aws bedrock-agent start-ingestion-job \
  --knowledge-base-id "$KB_ID" --data-source-id "$DS_ID" --region "$REGION"
echo "==> Done. New content is searchable once the ingestion job completes."
