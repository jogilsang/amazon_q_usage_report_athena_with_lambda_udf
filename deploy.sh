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
    echo "Usage: $0 [command] [--profile PROFILE_NAME]"
    echo ""
    echo "Commands:"
    echo "  all                  - Deploy all (Lambda + Athena + IAM Role)"
    echo "  lambda               - Deploy Lambda function only"
    echo "  athena               - Setup Athena database and table only"
    echo "  iam                  - Deploy IAM Identity Center role only"
    echo ""
    echo "Options:"
    echo "  --profile            - AWS CLI profile name (default: default)"
    echo ""
    echo "Examples:"
    echo "  $0 all --profile my-profile"
    echo "  $0 lambda --profile my-profile"
    echo "  $0 athena --profile my-profile"
    echo "  $0 iam --profile my-profile"
    echo ""
    exit 1
}

# Parse arguments
COMMAND=""
while [[ $# -gt 0 ]]; do
    case $1 in
        all|lambda|athena|iam)
            COMMAND="$1"
            shift
            ;;
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

if [ -z "$COMMAND" ]; then
    echo -e "${RED}❌ No command specified${NC}"
    usage
fi

echo -e "${BLUE}============================================================${NC}"
echo -e "${BLUE}Amazon Q - Deployment Script${NC}"
echo -e "${BLUE}============================================================${NC}"
echo -e "${GREEN}🔑 Using AWS Profile: $AWS_PROFILE${NC}"

# Check config.json
if [ ! -f "config.json" ]; then
    echo -e "${RED}❌ config.json not found${NC}"
    echo "Please copy config.json.example to config.json and configure it."
    exit 1
fi

export AWS_PROFILE

case $COMMAND in
    all)
        echo -e "${YELLOW}📦 Step 1/3: Deploying Lambda function...${NC}"
        ./deploy_q_account.sh --profile "$AWS_PROFILE"
        
        echo -e "${YELLOW}📦 Step 2/3: Setting up Athena...${NC}"
        ./deploy_q_account_athena.sh --profile "$AWS_PROFILE"
        
        echo -e "${YELLOW}📦 Step 3/3: Deploying IAM Identity Center role...${NC}"
        ./deploy_iam_identity_center_account.sh --profile "$AWS_PROFILE"
        
        echo -e "${GREEN}✅ All deployments completed!${NC}"
        ;;
    lambda)
        ./deploy_q_account.sh --profile "$AWS_PROFILE"
        ;;
    athena)
        ./deploy_q_account_athena.sh --profile "$AWS_PROFILE"
        ;;
    iam)
        ./deploy_iam_identity_center_account.sh --profile "$AWS_PROFILE"
        ;;
esac
