#!/bin/bash
# Deploy the Twilio webhook Lambda function.
#
# Prerequisites:
#   - AWS CLI configured (aws configure)
#   - pip, zip available
#
# Usage:
#   chmod +x deploy_lambda.sh
#   ./deploy_lambda.sh          # first deploy (creates everything)
#   ./deploy_lambda.sh update   # update code only (skip IAM/function creation)

set -e

# ── Configuration ──────────────────────────────────────────────
FUNCTION_NAME="voipy-twilio-webhook"
RUNTIME="python3.12"
REGION="${AWS_REGION:-us-east-2}"
TIMEOUT=120        # seconds — transcription can take a moment
MEMORY=512         # MB
ROLE_NAME="voipy-lambda-role"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# These come from your .env — source it or export them before running
source .env 2>/dev/null || true

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$PROJECT_DIR/.lambda_build"

echo "========================================"
echo "Deploying $FUNCTION_NAME"
echo "========================================"
echo "Region:  $REGION"
echo "Account: $ACCOUNT_ID"
echo ""

# ── Build the deployment package ───────────────────────────────
echo "[1/4] Building deployment package..."
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# Install dependencies into build dir
pip install --target "$BUILD_DIR" --quiet \
    elevenlabs \
    boto3

# Copy the handler
cp "$PROJECT_DIR/twilio_webhook.py" "$BUILD_DIR/twilio_webhook.py"

# Zip it up
cd "$BUILD_DIR"
zip -r9 -q "$PROJECT_DIR/lambda_package.zip" .
cd "$PROJECT_DIR"

echo "   Package: lambda_package.zip ($(du -h lambda_package.zip | cut -f1))"

# ── If "update" mode, just push the code ───────────────────────
if [ "$1" = "update" ]; then
    echo ""
    echo "[UPDATE] Updating function code..."
    aws lambda update-function-code \
        --function-name "$FUNCTION_NAME" \
        --zip-file "fileb://lambda_package.zip" \
        --region "$REGION" \
        --no-cli-pager

    echo ""
    echo "[UPDATE] Updating environment variables..."
    aws lambda update-function-configuration \
        --function-name "$FUNCTION_NAME" \
        --environment "Variables={
            TWILIO_ACCOUNT_SID=$TWILIO_ACCOUNT_SID,
            TWILIO_AUTH_TOKEN=$TWILIO_AUTH_TOKEN,
            ELEVENLABS_API_KEY=$ELEVENLABS_API_KEY,
            S3_BUCKET_NAME=${S3_BUCKET_NAME:-voipy},
            S3_REGION=${S3_REGION:-us-east-2},
            FUNCTION_URL=$(aws lambda get-function-url-config --function-name $FUNCTION_NAME --region $REGION --query 'FunctionUrl' --output text 2>/dev/null || echo '')
        }" \
        --region "$REGION" \
        --no-cli-pager

    echo ""
    echo "Done. Function updated."
    exit 0
fi

# ── Create IAM role ────────────────────────────────────────────
echo "[2/4] Setting up IAM role..."

TRUST_POLICY='{
    "Version": "2012-10-17",
    "Statement": [{
        "Effect": "Allow",
        "Principal": {"Service": "lambda.amazonaws.com"},
        "Action": "sts:AssumeRole"
    }]
}'

ROLE_ARN=$(aws iam get-role --role-name "$ROLE_NAME" --query 'Role.Arn' --output text 2>/dev/null || true)

if [ -z "$ROLE_ARN" ] || [ "$ROLE_ARN" = "None" ]; then
    echo "   Creating role: $ROLE_NAME"
    ROLE_ARN=$(aws iam create-role \
        --role-name "$ROLE_NAME" \
        --assume-role-policy-document "$TRUST_POLICY" \
        --query 'Role.Arn' --output text)

    # Attach basic Lambda execution (CloudWatch logs)
    aws iam attach-role-policy \
        --role-name "$ROLE_NAME" \
        --policy-arn "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"

    # Attach S3 full access (for uploading recordings + transcripts)
    aws iam attach-role-policy \
        --role-name "$ROLE_NAME" \
        --policy-arn "arn:aws:iam::aws:policy/AmazonS3FullAccess"

    echo "   Waiting for role to propagate..."
    sleep 10
else
    echo "   Role exists: $ROLE_ARN"
fi

# ── Create Lambda function ─────────────────────────────────────
echo "[3/4] Creating Lambda function..."

EXISTING=$(aws lambda get-function --function-name "$FUNCTION_NAME" --region "$REGION" 2>/dev/null || true)

if [ -z "$EXISTING" ]; then
    aws lambda create-function \
        --function-name "$FUNCTION_NAME" \
        --runtime "$RUNTIME" \
        --role "$ROLE_ARN" \
        --handler "twilio_webhook.handler" \
        --zip-file "fileb://lambda_package.zip" \
        --timeout "$TIMEOUT" \
        --memory-size "$MEMORY" \
        --environment "Variables={
            TWILIO_ACCOUNT_SID=$TWILIO_ACCOUNT_SID,
            TWILIO_AUTH_TOKEN=$TWILIO_AUTH_TOKEN,
            ELEVENLABS_API_KEY=$ELEVENLABS_API_KEY,
            S3_BUCKET_NAME=${S3_BUCKET_NAME:-voipy},
            S3_REGION=${S3_REGION:-us-east-2},
            FUNCTION_URL=PLACEHOLDER
        }" \
        --region "$REGION" \
        --no-cli-pager

    echo "   Function created."
    echo "   Waiting for function to be active..."
    aws lambda wait function-active-v2 --function-name "$FUNCTION_NAME" --region "$REGION"
else
    echo "   Function exists, updating code..."
    aws lambda update-function-code \
        --function-name "$FUNCTION_NAME" \
        --zip-file "fileb://lambda_package.zip" \
        --region "$REGION" \
        --no-cli-pager
fi

# ── Create Function URL (public HTTPS endpoint) ───────────────
echo "[4/4] Setting up Function URL..."

FUNC_URL=$(aws lambda get-function-url-config \
    --function-name "$FUNCTION_NAME" \
    --region "$REGION" \
    --query 'FunctionUrl' --output text 2>/dev/null || true)

if [ -z "$FUNC_URL" ] || [ "$FUNC_URL" = "None" ]; then
    FUNC_URL=$(aws lambda create-function-url-config \
        --function-name "$FUNCTION_NAME" \
        --auth-type "NONE" \
        --region "$REGION" \
        --query 'FunctionUrl' --output text)

    # Allow public invocation
    aws lambda add-permission \
        --function-name "$FUNCTION_NAME" \
        --statement-id "AllowPublicAccess" \
        --action "lambda:InvokeFunctionUrl" \
        --principal "*" \
        --function-url-auth-type "NONE" \
        --region "$REGION" \
        --no-cli-pager 2>/dev/null || true

    echo "   Function URL created."
fi

# Remove trailing slash for clean URL joining
FUNC_URL_CLEAN="${FUNC_URL%/}"

# Update the FUNCTION_URL env var so TwiML callbacks work
aws lambda update-function-configuration \
    --function-name "$FUNCTION_NAME" \
    --environment "Variables={
        TWILIO_ACCOUNT_SID=$TWILIO_ACCOUNT_SID,
        TWILIO_AUTH_TOKEN=$TWILIO_AUTH_TOKEN,
        ELEVENLABS_API_KEY=$ELEVENLABS_API_KEY,
        S3_BUCKET_NAME=${S3_BUCKET_NAME:-voipy},
        S3_REGION=${S3_REGION:-us-east-2},
        FUNCTION_URL=$FUNC_URL_CLEAN
    }" \
    --region "$REGION" \
    --no-cli-pager > /dev/null

# ── Cleanup ────────────────────────────────────────────────────
rm -rf "$BUILD_DIR"

# ── Done ───────────────────────────────────────────────────────
echo ""
echo "========================================"
echo "Deployment complete!"
echo "========================================"
echo ""
echo "Lambda Function URL:"
echo "  $FUNC_URL_CLEAN"
echo ""
echo "Configure in Twilio Console:"
echo "  Phone Numbers -> your number -> Voice Configuration"
echo "  'A Call Comes In' -> Webhook -> POST"
echo "  URL: ${FUNC_URL_CLEAN}/voice/incoming"
echo ""
echo "Test health check:"
echo "  curl ${FUNC_URL_CLEAN}/health"
echo ""
echo "View logs:"
echo "  aws logs tail /aws/lambda/$FUNCTION_NAME --follow --region $REGION"
echo ""
