#!/bin/bash
# Deploy the Twilio webhook Lambda function with API Gateway.
#
# Prerequisites:
#   - AWS CLI configured (aws configure)
#   - pip, zip available
#
# Usage:
#   chmod +x deploy_lambda.sh
#   ./deploy_lambda.sh          # first deploy (creates everything)
#   ./deploy_lambda.sh update   # update code + env vars only

set -e

# ── Configuration ──────────────────────────────────────────────
FUNCTION_NAME="voipy-twilio-webhook"
API_NAME="voipy-twilio"
RUNTIME="python3.12"
REGION="${AWS_REGION:-us-east-2}"
TIMEOUT=120        # seconds — transcription can take a moment
MEMORY=512         # MB
ROLE_NAME="voipy-lambda-role"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Source .env for API keys
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
echo "[1/5] Building deployment package..."
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

# ── Helper: get API Gateway URL ────────────────────────────────
get_api_url() {
    local api_id
    api_id=$(aws apigatewayv2 get-apis --region "$REGION" \
        --query "Items[?Name=='${API_NAME}'].ApiId" --output text 2>/dev/null || true)
    if [ -n "$api_id" ] && [ "$api_id" != "None" ]; then
        echo "https://${api_id}.execute-api.${REGION}.amazonaws.com"
    fi
}

# ── If "update" mode, just push code + env vars ───────────────
if [ "$1" = "update" ]; then
    echo ""
    echo "[UPDATE] Updating function code..."
    aws lambda update-function-code \
        --function-name "$FUNCTION_NAME" \
        --zip-file "fileb://lambda_package.zip" \
        --region "$REGION" \
        --no-cli-pager

    API_URL=$(get_api_url)
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
            FUNCTION_URL=${API_URL}
        }" \
        --region "$REGION" \
        --no-cli-pager > /dev/null

    rm -rf "$BUILD_DIR"
    echo ""
    echo "Done. Function updated."
    echo "Endpoint: ${API_URL}/voice/incoming"
    exit 0
fi

# ── Create IAM role ────────────────────────────────────────────
echo "[2/5] Setting up IAM role..."

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

    aws iam attach-role-policy \
        --role-name "$ROLE_NAME" \
        --policy-arn "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"

    aws iam attach-role-policy \
        --role-name "$ROLE_NAME" \
        --policy-arn "arn:aws:iam::aws:policy/AmazonS3FullAccess"

    echo "   Waiting for role to propagate..."
    sleep 10
else
    echo "   Role exists: $ROLE_ARN"
fi

# ── Create Lambda function ─────────────────────────────────────
echo "[3/5] Creating Lambda function..."

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

# ── Create API Gateway (HTTP API) ─────────────────────────────
echo "[4/5] Setting up API Gateway..."

FUNCTION_ARN="arn:aws:lambda:${REGION}:${ACCOUNT_ID}:function:${FUNCTION_NAME}"

# Check if API already exists
API_ID=$(aws apigatewayv2 get-apis --region "$REGION" \
    --query "Items[?Name=='${API_NAME}'].ApiId" --output text 2>/dev/null || true)

if [ -z "$API_ID" ] || [ "$API_ID" = "None" ]; then
    echo "   Creating HTTP API: $API_NAME"

    # Create the API
    API_ID=$(aws apigatewayv2 create-api \
        --name "$API_NAME" \
        --protocol-type HTTP \
        --region "$REGION" \
        --query 'ApiId' --output text)

    # Create Lambda integration
    INTEGRATION_ID=$(aws apigatewayv2 create-integration \
        --api-id "$API_ID" \
        --integration-type AWS_PROXY \
        --integration-uri "$FUNCTION_ARN" \
        --payload-format-version "2.0" \
        --region "$REGION" \
        --query 'IntegrationId' --output text)

    # Create catch-all route
    aws apigatewayv2 create-route \
        --api-id "$API_ID" \
        --route-key 'ANY /{proxy+}' \
        --target "integrations/${INTEGRATION_ID}" \
        --region "$REGION" \
        --no-cli-pager > /dev/null

    # Create auto-deploying default stage
    aws apigatewayv2 create-stage \
        --api-id "$API_ID" \
        --stage-name '$default' \
        --auto-deploy \
        --region "$REGION" \
        --no-cli-pager > /dev/null

    # Grant API Gateway permission to invoke Lambda
    aws lambda add-permission \
        --function-name "$FUNCTION_NAME" \
        --statement-id "ApiGatewayInvoke" \
        --action "lambda:InvokeFunction" \
        --principal "apigateway.amazonaws.com" \
        --source-arn "arn:aws:execute-api:${REGION}:${ACCOUNT_ID}:${API_ID}/*" \
        --region "$REGION" \
        --no-cli-pager > /dev/null 2>&1 || true

    echo "   API Gateway created."
else
    echo "   API Gateway exists: $API_ID"
fi

API_URL="https://${API_ID}.execute-api.${REGION}.amazonaws.com"

# ── Update FUNCTION_URL env var ────────────────────────────────
echo "[5/5] Updating Lambda environment..."

aws lambda update-function-configuration \
    --function-name "$FUNCTION_NAME" \
    --environment "Variables={
        TWILIO_ACCOUNT_SID=$TWILIO_ACCOUNT_SID,
        TWILIO_AUTH_TOKEN=$TWILIO_AUTH_TOKEN,
        ELEVENLABS_API_KEY=$ELEVENLABS_API_KEY,
        S3_BUCKET_NAME=${S3_BUCKET_NAME:-voipy},
        S3_REGION=${S3_REGION:-us-east-2},
        FUNCTION_URL=$API_URL
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
echo "API Gateway URL:"
echo "  $API_URL"
echo ""
echo "Configure in Twilio Console:"
echo "  Phone Numbers -> your number -> Voice Configuration"
echo "  'A Call Comes In' -> Webhook -> POST"
echo "  URL: ${API_URL}/voice/incoming"
echo ""
echo "Test health check:"
echo "  curl ${API_URL}/health"
echo ""
echo "View logs:"
echo "  aws logs tail /aws/lambda/$FUNCTION_NAME --follow --region $REGION"
echo ""
