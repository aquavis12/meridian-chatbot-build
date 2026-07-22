#!/usr/bin/env bash
# Step 1 — deploy the stack (KB + data source + guardrail + fulfillment Lambda),
# then upload the docs and trigger ingestion.
# Usage: ./scripts/01-deploy.sh <VectorBucketArn> <VectorIndexArn> [region]
set -euo pipefail
VBUCKET_ARN="${1:?pass VectorBucketArn from step 0}"
INDEX_ARN="${2:?pass VectorIndexArn from step 0}"
REGION="${3:-us-east-1}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STACK="meridian-chatbot"

echo "==> Deploying stack ..."
aws cloudformation deploy \
  --template-file "$ROOT/infra/template.yaml" \
  --stack-name "$STACK" \
  --capabilities CAPABILITY_NAMED_IAM \
  --region "$REGION" \
  --parameter-overrides VectorBucketArn="$VBUCKET_ARN" VectorIndexArn="$INDEX_ARN"

BUCKET=$(aws cloudformation describe-stacks --stack-name "$STACK" --region "$REGION" \
  --query "Stacks[0].Outputs[?OutputKey=='SourceBucket'].OutputValue" --output text)
KB_ID=$(aws cloudformation describe-stacks --stack-name "$STACK" --region "$REGION" \
  --query "Stacks[0].Outputs[?OutputKey=='KnowledgeBaseId'].OutputValue" --output text)
DS_ID=$(aws cloudformation describe-stacks --stack-name "$STACK" --region "$REGION" \
  --query "Stacks[0].Outputs[?OutputKey=='DataSourceId'].OutputValue" --output text)

echo "==> Uploading docs to s3://$BUCKET ..."
aws s3 sync "$ROOT/docs/" "s3://$BUCKET/" --exclude "*" --include "*.pdf"

echo "==> Starting ingestion (sync) ..."
aws bedrock-agent start-ingestion-job \
  --knowledge-base-id "$KB_ID" --data-source-id "$DS_ID" --region "$REGION"

echo
echo "==> Stack up. KB_ID=$KB_ID  SOURCE_BUCKET=$BUCKET"
echo "    Next: build the Lex bot + QnAIntent manually (runbook/BUILD.md),"
echo "    wiring the fulfillment Lambda from the stack output."
