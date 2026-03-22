#!/bin/bash

set -e

if [ -z "$1" ]; then
    echo "Usage: $0 <AWS_PROFILE>"
    exit 1
fi

PROFILE="$1"
FUNCTION_NAME="final-identity-udf"

if [ ! -f "config.json" ]; then
    echo "Error: config.json not found"
    exit 1
fi

UDF_ROLE_NAME=$(jq -r '.udf_lambda_role_name' config.json)
REGION=$(jq -r '.lambda_region' config.json)
IDENTITY_ACCOUNT_ID=$(jq -r '.identity_profile.account_id' config.json)
IDENTITY_ROLE_NAME=$(jq -r '.identity_profile.account_role_name' config.json)
IDENTITY_STORE_REGION=$(jq -r '.identity_region' config.json)
IDENTITY_STORE_ID="d-9b67649839"

echo "🔐 Checking IAM role: $UDF_ROLE_NAME"
ROLE_ARN=$(aws iam get-role --role-name "$UDF_ROLE_NAME" --profile "$PROFILE" --query 'Role.Arn' --output text 2>/dev/null || echo "")

if [ -z "$ROLE_ARN" ]; then
    echo "Creating IAM role: $UDF_ROLE_NAME"
    
    TRUST_POLICY=$(cat <<EOF
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {"Service": "lambda.amazonaws.com"},
    "Action": "sts:AssumeRole"
  }]
}
EOF
)
    
    ROLE_ARN=$(aws iam create-role \
        --role-name "$UDF_ROLE_NAME" \
        --assume-role-policy-document "$TRUST_POLICY" \
        --description "IAM role for Athena UDF to access IAM Identity Center" \
        --profile "$PROFILE" \
        --query 'Role.Arn' \
        --output text)
    
    aws iam attach-role-policy --role-name "$UDF_ROLE_NAME" \
        --policy-arn "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole" \
        --profile "$PROFILE"
    
    ASSUME_POLICY=$(cat <<EOF
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": "sts:AssumeRole",
    "Resource": "arn:aws:iam::${IDENTITY_ACCOUNT_ID}:role/${IDENTITY_ROLE_NAME}"
  }]
}
EOF
)
    
    aws iam put-role-policy \
        --role-name "$UDF_ROLE_NAME" \
        --policy-name "AssumeIdentityCenterRole" \
        --policy-document "$ASSUME_POLICY" \
        --profile "$PROFILE"
    
    echo "⏳ Waiting for IAM role propagation..."
    sleep 10
fi

echo "✅ IAM role: $ROLE_ARN"

cd java_udf/identity-center-udf

echo "☕ Building Java UDF..."
mvn clean package -q

JAR_FILE="target/identity-center-udf-1.0-SNAPSHOT.jar"

if [ ! -f "$JAR_FILE" ]; then
    echo "Error: JAR file not found"
    exit 1
fi

echo "⚡ Creating Lambda function..."
echo "  - Function: $FUNCTION_NAME"
echo "  - Region: $REGION"
echo "  - JAR size: $(du -h "$JAR_FILE" | cut -f1)"

LAMBDA_EXISTS=$(aws lambda get-function --function-name "$FUNCTION_NAME" --region "$REGION" --profile "$PROFILE" 2>/dev/null || echo "")

if [ -z "$LAMBDA_EXISTS" ]; then
    aws lambda create-function \
        --function-name "$FUNCTION_NAME" \
        --runtime java11 \
        --role "$ROLE_ARN" \
        --handler com.amazon.q.analytics.IdentityCenterUDF \
        --zip-file fileb://"$JAR_FILE" \
        --timeout 300 \
        --memory-size 512 \
        --region "$REGION" \
        --profile "$PROFILE" \
        --environment "Variables={IDENTITY_STORE_REGION=$IDENTITY_STORE_REGION,IDENTITY_STORE_ID=$IDENTITY_STORE_ID,IDENTITY_CENTER_ACCOUNT_ID=$IDENTITY_ACCOUNT_ID,CROSS_ACCOUNT_ROLE_NAME=$IDENTITY_ROLE_NAME}" \
        --query 'FunctionArn' \
        --output text
else
    aws lambda update-function-code \
        --function-name "$FUNCTION_NAME" \
        --zip-file fileb://"$JAR_FILE" \
        --region "$REGION" \
        --profile "$PROFILE" > /dev/null
    
    echo "⏳ Waiting for code update to complete..."
    aws lambda wait function-updated --function-name "$FUNCTION_NAME" --region "$REGION" --profile "$PROFILE"
    
    aws lambda update-function-configuration \
        --function-name "$FUNCTION_NAME" \
        --handler com.amazon.q.analytics.IdentityCenterUDF \
        --region "$REGION" \
        --profile "$PROFILE" \
        --environment "Variables={IDENTITY_STORE_REGION=$IDENTITY_STORE_REGION,IDENTITY_STORE_ID=$IDENTITY_STORE_ID,IDENTITY_CENTER_ACCOUNT_ID=$IDENTITY_ACCOUNT_ID,CROSS_ACCOUNT_ROLE_NAME=$IDENTITY_ROLE_NAME}" > /dev/null
    
    echo "✅ Lambda function updated"
fi

echo "✅ Deployment completed: $FUNCTION_NAME"
