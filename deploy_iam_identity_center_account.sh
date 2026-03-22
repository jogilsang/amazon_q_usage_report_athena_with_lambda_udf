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
echo -e "${BLUE}Amazon Q - Deploy IAM Identity Center Role${NC}"
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
IDENTITY_ROLE_NAME=$(jq -r '.identity_profile.account_role_name' config.json)
UDF_LAMBDA_ROLE_NAME=$(jq -r '.udf_lambda_role_name' config.json)
EXTERNAL_ID=$(jq -r '.identity_profile.external_id' config.json)

# Get Q Account ID
read -p "Enter Q Account ID (where Lambda will run): " Q_ACCOUNT_ID

LAMBDA_ROLE_ARN="arn:aws:iam::${Q_ACCOUNT_ID}:role/${UDF_LAMBDA_ROLE_NAME}"
echo -e "${BLUE}Lambda Role ARN: $LAMBDA_ROLE_ARN${NC}"

# Create IAM role
echo -e "\n${BLUE}🔐 Creating Identity Center access role...${NC}"

# Trust policy with optional external ID
if [ -n "$EXTERNAL_ID" ] && [ "$EXTERNAL_ID" != "null" ] && [ "$EXTERNAL_ID" != "" ]; then
    TRUST_POLICY=$(cat <<EOF
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {"AWS": "$LAMBDA_ROLE_ARN"},
    "Action": "sts:AssumeRole",
    "Condition": {
      "StringEquals": {"sts:ExternalId": "$EXTERNAL_ID"}
    }
  }]
}
EOF
)
else
    TRUST_POLICY=$(cat <<EOF
{
  "Version": "2012-10-17",
)
else
    TRUST_POLICY=$(cat <<EOF
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {"AWS": "$LAMBDA_ROLE_ARN"},
    "Action": "sts:AssumeRole"
  }]
}
EOF
)
fi

# Permissions policy
PERMISSIONS_POLICY=$(cat <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "identitystore:ListUsers",
        "identitystore:DescribeUser"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "sso:ListInstances",
        "sso-admin:ListInstances"
      ],
      "Resource": "*"
    }
  ]
}
EOF
)

ROLE_ARN=$(aws iam get-role --role-name "$IDENTITY_ROLE_NAME" --profile "$AWS_PROFILE" --query 'Role.Arn' --output text 2>/dev/null || echo "")

if [ -z "$ROLE_ARN" ]; then
    ROLE_ARN=$(aws iam create-role \
        --role-name "$IDENTITY_ROLE_NAME" \
        --assume-role-policy-document "$TRUST_POLICY" \
        --description "Cross-account role for Amazon Q analytics to access Identity Center" \
        --profile "$AWS_PROFILE" \
        --query 'Role.Arn' \
        --output text)
    echo -e "${GREEN}✅ Role created: $ROLE_ARN${NC}"
    
    # Attach inline policy
    aws iam put-role-policy \
        --role-name "$IDENTITY_ROLE_NAME" \
        --policy-name "IdentityCenterReadAccess" \
        --policy-document "$PERMISSIONS_POLICY" \
        --profile "$AWS_PROFILE"
    
    echo -e "${GREEN}✅ Permissions attached${NC}"
else
    echo -e "${YELLOW}⚠️  Role already exists, updating trust policy...${NC}"
    
    # Update trust policy
    aws iam update-assume-role-policy \
        --role-name "$IDENTITY_ROLE_NAME" \
        --policy-document "$TRUST_POLICY" \
        --profile "$AWS_PROFILE"
    
    # Update permissions
    aws iam put-role-policy \
        --role-name "$IDENTITY_ROLE_NAME" \
        --policy-name "IdentityCenterReadAccess" \
        --policy-document "$PERMISSIONS_POLICY" \
        --profile "$AWS_PROFILE"
    
    echo -e "${GREEN}✅ Role updated: $ROLE_ARN${NC}"
fi

IDENTITY_ACCOUNT_ID=$(jq -r '.identity_profile.account_id' config.json)

echo -e "\n${GREEN}============================================================${NC}"
echo -e "${GREEN}✅ Deployment completed successfully!${NC}"
echo -e "${GREEN}============================================================${NC}"
echo -e "${BLUE}Identity Center Role ARN: $ROLE_ARN${NC}"
echo -e "\n${YELLOW}Use this role in Q account config:${NC}"
echo -e "${YELLOW}  identity_profile.account_id: $IDENTITY_ACCOUNT_ID${NC}"
echo -e "${YELLOW}  identity_profile.account_role_name: $IDENTITY_ROLE_NAME${NC}"
echo -e "\n${BLUE}Note: This role can be in the same account as Q Account or separate${NC}"

