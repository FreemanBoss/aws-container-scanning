#!/bin/bash
# Complete Deployment Script for Container Scanning System

set -e

echo "=========================================="
echo "Container Scanning System Deployment"
echo "=========================================="
echo ""

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Check prerequisites
echo -e "${YELLOW}Step 1: Checking Prerequisites${NC}"
echo "-------------------------------------------"

# Check AWS CLI
if ! command -v aws &> /dev/null; then
    echo -e "${RED}❌ AWS CLI not found${NC}"
    exit 1
fi
echo -e "${GREEN}✓ AWS CLI installed${NC}"

# Check Terraform
if ! command -v terraform &> /dev/null; then
    echo -e "${RED}❌ Terraform not found${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Terraform installed${NC}"

# Check AWS credentials
if ! aws sts get-caller-identity &> /dev/null; then
    echo -e "${RED}❌ AWS credentials not configured${NC}"
    exit 1
fi

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION=$(aws configure get region || echo "us-east-1")
echo -e "${GREEN}✓ AWS credentials configured${NC}"
echo "  Account ID: $ACCOUNT_ID"
echo "  Region: $AWS_REGION"
echo ""

# Package Lambda functions
echo -e "${YELLOW}Step 2: Packaging Lambda Functions${NC}"
echo "-------------------------------------------"
python3 scripts/package-lambdas.py
echo ""

# Initialize Terraform
echo -e "${YELLOW}Step 3: Initializing Terraform${NC}"
echo "-------------------------------------------"
cd terraform/environments/dev
terraform init
echo ""

# Validate Terraform
echo -e "${YELLOW}Step 4: Validating Terraform Configuration${NC}"
echo "-------------------------------------------"
terraform validate
echo ""

# Create terraform.tfvars if it doesn't exist
if [ ! -f terraform.tfvars ]; then
    echo -e "${YELLOW}Creating terraform.tfvars from example${NC}"
    cp terraform.tfvars.example terraform.tfvars
    echo -e "${RED}⚠️  Please edit terraform.tfvars and add your email/settings${NC}"
    echo "   Then run this script again"
    exit 0
fi

# Plan Terraform
echo -e "${YELLOW}Step 5: Planning Terraform Deployment${NC}"
echo "-------------------------------------------"
terraform plan -out=tfplan
echo ""

# Prompt for deployment
echo -e "${YELLOW}Ready to deploy infrastructure?${NC}"
read -p "Type 'yes' to continue: " confirm

if [ "$confirm" != "yes" ]; then
    echo "Deployment cancelled"
    exit 0
fi

# Apply Terraform
echo -e "${YELLOW}Step 6: Deploying Infrastructure${NC}"
echo "-------------------------------------------"
terraform apply tfplan
echo ""

# Enable Inspector v2
echo -e "${YELLOW}Step 7: Enabling Amazon Inspector v2${NC}"
echo "-------------------------------------------"
aws inspector2 enable --resource-types ECR --region $AWS_REGION 2>/dev/null || echo "Inspector already enabled or not available"
echo ""

# Get outputs
echo -e "${YELLOW}Step 8: Deployment Summary${NC}"
echo "-------------------------------------------"
terraform output
echo ""

echo -e "${GREEN}=========================================="
echo "✅ Deployment Complete!"
echo "==========================================${NC}"
echo ""
echo "Next steps:"
echo "1. Confirm SNS email subscription (check your email)"
echo "2. Build and push the sample vulnerable app:"
echo "   cd ../../sample-apps/vulnerable-app"
echo "   ./build-and-push.sh"
echo ""
echo "3. Monitor scan results in:"
echo "   - CloudWatch Dashboard"
echo "   - DynamoDB tables"
echo "   - SNS/Slack notifications"
echo ""
