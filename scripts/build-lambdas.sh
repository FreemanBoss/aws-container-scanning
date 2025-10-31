#!/bin/bash
# Lambda Function Deployment Script
# Packages Lambda functions with dependencies and uploads to AWS

set -e

echo "=== Lambda Function Deployment Script ==="
echo ""

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAMBDA_DIR="${SCRIPT_DIR}/../src/lambda-functions"
BUILD_DIR="${SCRIPT_DIR}/../build"
AWS_REGION="${AWS_REGION:-us-east-1}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Functions to package
FUNCTIONS=("scan-processor" "vulnerability-aggregator" "policy-enforcer" "slack-notifier")

# Create build directory
mkdir -p "${BUILD_DIR}"

echo "Building Lambda deployment packages..."
echo ""

for func in "${FUNCTIONS[@]}"; do
    echo -e "${YELLOW}Processing: ${func}${NC}"
    
    FUNC_DIR="${LAMBDA_DIR}/${func}"
    PACKAGE_DIR="${BUILD_DIR}/${func}"
    ZIP_FILE="${BUILD_DIR}/${func}.zip"
    
    # Clean previous build
    rm -rf "${PACKAGE_DIR}"
    rm -f "${ZIP_FILE}"
    
    # Create package directory
    mkdir -p "${PACKAGE_DIR}"
    
    # Copy handler
    cp "${FUNC_DIR}/handler.py" "${PACKAGE_DIR}/"
    
    # Install dependencies if requirements.txt exists
    if [ -f "${FUNC_DIR}/requirements.txt" ]; then
        if grep -q "boto3" "${FUNC_DIR}/requirements.txt"; then
            echo "  Skipping boto3 (provided by Lambda runtime)"
            # Create temp requirements without boto3
            grep -v "boto3" "${FUNC_DIR}/requirements.txt" > "${PACKAGE_DIR}/requirements_temp.txt" || true
            
            if [ -s "${PACKAGE_DIR}/requirements_temp.txt" ]; then
                pip install -r "${PACKAGE_DIR}/requirements_temp.txt" -t "${PACKAGE_DIR}" --quiet
            fi
            rm -f "${PACKAGE_DIR}/requirements_temp.txt"
        else
            echo "  Installing dependencies..."
            pip install -r "${FUNC_DIR}/requirements.txt" -t "${PACKAGE_DIR}" --quiet
        fi
    fi
    
    # Create ZIP file
    echo "  Creating deployment package..."
    cd "${PACKAGE_DIR}"
    zip -r "${ZIP_FILE}" . -q
    cd - > /dev/null
    
    # Clean up package directory
    rm -rf "${PACKAGE_DIR}"
    
    # Get file size
    SIZE=$(du -h "${ZIP_FILE}" | cut -f1)
    echo -e "  ${GREEN}✓ Created: ${func}.zip (${SIZE})${NC}"
    echo ""
done

echo -e "${GREEN}=== Build Complete ===${NC}"
echo ""
echo "Deployment packages created in: ${BUILD_DIR}/"
echo ""
echo "Next steps:"
echo "1. Update Terraform Lambda modules to use these packages"
echo "2. Run: terraform apply"
echo ""
echo "Or deploy directly with AWS CLI:"
for func in "${FUNCTIONS[@]}"; do
    echo "aws lambda update-function-code --function-name container-scanning-${func}-dev --zip-file fileb://build/${func}.zip --region ${AWS_REGION}"
done
