#!/bin/bash
set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Default AWS profile
AWS_PROFILE="${AWS_PROFILE:-default}"

# Usage
usage() {
    echo "Usage: $0 [--profile PROFILE_NAME]"
    echo ""
    echo "Options:"
    echo "  --profile            - AWS CLI profile name (default: default)"
    echo ""
    echo "Examples:"
    echo "  $0 --profile my-profile"
    echo "  $0"
    echo ""
    exit 1
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --profile)
            AWS_PROFILE="$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            usage
            ;;
    esac
done

echo -e "${BLUE}============================================================${NC}"
echo -e "${BLUE}Amazon Q - Setup Athena Database and Table${NC}"
echo -e "${BLUE}============================================================${NC}"
echo -e "${GREEN}🔑 Using AWS Profile: $AWS_PROFILE${NC}"

# Check config.json
if [ ! -f "config.json" ]; then
    echo -e "${RED}❌ config.json not found${NC}"
    echo "Please copy config.json.example to config.json and configure it."
    exit 1
fi

# Load config
echo -e "${GREEN}✅ Configuration loaded${NC}"
LAMBDA_REGION=$(jq -r '.lambda_region' config.json)
ATHENA_DATABASE=$(jq -r '.athena_database' config.json)
ATHENA_TABLE=$(jq -r '.athena_table' config.json)
S3_DATA_BUCKET=$(jq -r '.s3_data_bucket' config.json)
S3_RESULTS_BUCKET=$(jq -r '.s3_results_bucket' config.json)

# Use lambda_region for all Athena operations
ATHENA_REGION="$LAMBDA_REGION"
echo -e "${BLUE}📍 Using region: $ATHENA_REGION${NC}"
echo -e "${BLUE}📦 Data bucket: $S3_DATA_BUCKET${NC}"
echo -e "${BLUE}📊 Results bucket: $S3_RESULTS_BUCKET${NC}"

# Setup Athena workgroup
echo -e "\n${BLUE}🔧 Setting up Athena workgroup...${NC}"

WORKGROUP_NAME="AmazonQ"

# Check if workgroup exists
WORKGROUP_EXISTS=$(aws athena get-work-group --work-group "$WORKGROUP_NAME" --region "$ATHENA_REGION" --profile "$AWS_PROFILE" 2>/dev/null || echo "")

if [ -n "$WORKGROUP_EXISTS" ]; then
    OUTPUT_LOCATION=$(echo "$WORKGROUP_EXISTS" | jq -r '.WorkGroup.Configuration.ResultConfiguration.OutputLocation')
    echo -e "${GREEN}✅ Athena workgroup already exists: $WORKGROUP_NAME${NC}"
    echo -e "${GREEN}   Output location: $OUTPUT_LOCATION${NC}"
else
    # Create S3 bucket for Athena results
    echo -e "${BLUE}📦 Creating Athena results bucket: $S3_RESULTS_BUCKET (region: $ATHENA_REGION)${NC}"
    
    if [ "$ATHENA_REGION" == "us-east-1" ]; then
        aws s3 mb "s3://${S3_RESULTS_BUCKET}" --profile "$AWS_PROFILE" 2>/dev/null || echo "Bucket may already exist"
    else
        aws s3 mb "s3://${S3_RESULTS_BUCKET}" --region "$ATHENA_REGION" --profile "$AWS_PROFILE" 2>/dev/null || echo "Bucket may already exist"
    fi
    
    echo -e "${GREEN}✅ Bucket ready: $S3_RESULTS_BUCKET${NC}"
    
    # Create new workgroup
    OUTPUT_LOCATION="s3://${S3_RESULTS_BUCKET}/"
    
    aws athena create-work-group \
        --name "$WORKGROUP_NAME" \
        --region "$ATHENA_REGION" \
        --profile "$AWS_PROFILE" \
        --configuration "ResultConfiguration={OutputLocation=$OUTPUT_LOCATION},EnforceWorkGroupConfiguration=true" \
        --description "Workgroup for Amazon Q usage analytics"
    
    echo -e "${GREEN}✅ Athena workgroup created: $WORKGROUP_NAME${NC}"
    echo -e "${GREEN}   Output location: $OUTPUT_LOCATION${NC}"
fi

# Ensure OUTPUT_LOCATION is set
if [ -z "$OUTPUT_LOCATION" ] || [ "$OUTPUT_LOCATION" == "null" ]; then
    echo -e "${RED}❌ Failed to get output location from workgroup${NC}"
    exit 1
fi

# Wait for workgroup to be ready
echo -e "${YELLOW}⏳ Waiting for workgroup and S3 bucket to be ready (10 seconds)...${NC}"
sleep 10

# Create database
echo -e "\n${BLUE}🗄️  Setting up Athena database and table...${NC}"

QUERY_ID=$(aws athena start-query-execution \
    --query-string "CREATE DATABASE IF NOT EXISTS ${ATHENA_DATABASE}" \
    --work-group "$WORKGROUP_NAME" \
    --result-configuration "OutputLocation=$OUTPUT_LOCATION" \
    --region "$ATHENA_REGION" \
    --profile "$AWS_PROFILE" \
    --query 'QueryExecutionId' \
    --output text)

# Wait for query completion
while true; do
    STATUS=$(aws athena get-query-execution --query-execution-id "$QUERY_ID" --region "$ATHENA_REGION" --profile "$AWS_PROFILE" --query 'QueryExecution.Status.State' --output text)
    if [ "$STATUS" == "SUCCEEDED" ] || [ "$STATUS" == "FAILED" ] || [ "$STATUS" == "CANCELLED" ]; then
        break
    fi
    sleep 1
done

if [ "$STATUS" == "SUCCEEDED" ]; then
    echo -e "${GREEN}✅ Database created/verified: $ATHENA_DATABASE${NC}"
else
    ERROR_MSG=$(aws athena get-query-execution --query-execution-id "$QUERY_ID" --region "$ATHENA_REGION" --profile "$AWS_PROFILE" --query 'QueryExecution.Status.StateChangeReason' --output text)
    echo -e "${RED}❌ Database creation failed: $ERROR_MSG${NC}"
    echo -e "${YELLOW}💡 KMS Permission Issue: Add kms:GenerateDataKey permission to your IAM user/role${NC}"
    echo -e "${YELLOW}   KMS Key: arn:aws:kms:ap-northeast-2:247553399539:key/0636f57b-4782-450b-ba60-c856d4dca4bc${NC}"
    exit 1
fi

# Create table from SQL template
if [ ! -f "sample_athena_create_table.sql" ]; then
    echo -e "${YELLOW}⚠️  SQL template not found: sample_athena_create_table.sql${NC}"
    exit 0
fi

# Replace placeholders in SQL
CREATE_TABLE_SQL=$(cat sample_athena_create_table.sql | \
    sed "s/YOUR_BUCKET_NAME/${S3_DATA_BUCKET}/g" | \
    sed "s/q_user_analytics/${ATHENA_DATABASE}/g" | \
    sed "s/user_reports/${ATHENA_TABLE}/g")

QUERY_ID=$(aws athena start-query-execution \
    --query-string "$CREATE_TABLE_SQL" \
    --query-execution-context "Database=$ATHENA_DATABASE" \
    --work-group "$WORKGROUP_NAME" \
    --result-configuration "OutputLocation=$OUTPUT_LOCATION" \
    --region "$ATHENA_REGION" \
    --profile "$AWS_PROFILE" \
    --query 'QueryExecutionId' \
    --output text)

# Wait for query completion
while true; do
    STATUS=$(aws athena get-query-execution --query-execution-id "$QUERY_ID" --region "$ATHENA_REGION" --profile "$AWS_PROFILE" --query 'QueryExecution.Status.State' --output text)
    if [ "$STATUS" == "SUCCEEDED" ] || [ "$STATUS" == "FAILED" ] || [ "$STATUS" == "CANCELLED" ]; then
        break
    fi
    sleep 1
done

if [ "$STATUS" == "SUCCEEDED" ]; then
    echo -e "${GREEN}✅ Table created/verified: ${ATHENA_DATABASE}.${ATHENA_TABLE}${NC}"
    echo -e "${BLUE}   Location: s3://${S3_DATA_BUCKET}/daily-report/${NC}"
else
    ERROR_MSG=$(aws athena get-query-execution --query-execution-id "$QUERY_ID" --region "$ATHENA_REGION" --profile "$AWS_PROFILE" --query 'QueryExecution.Status.StateChangeReason' --output text)
    echo -e "${RED}❌ Table creation failed: $ERROR_MSG${NC}"
    echo -e "${YELLOW}💡 Check if S3 bucket exists and you have permissions${NC}"
    exit 1
fi

echo -e "\n${GREEN}============================================================${NC}"
echo -e "${GREEN}✅ Athena setup completed successfully!${NC}"
echo -e "${GREEN}============================================================${NC}"
echo -e "${BLUE}Athena WorkGroup: $WORKGROUP_NAME${NC}"
echo -e "${BLUE}Athena Database: $ATHENA_DATABASE${NC}"
echo -e "${BLUE}Athena Table: ${ATHENA_DATABASE}.${ATHENA_TABLE}${NC}"
echo -e "${BLUE}Query Results: $OUTPUT_LOCATION${NC}"
echo -e "${BLUE}Data Location: s3://${S3_DATA_BUCKET}/daily-report/${NC}"

