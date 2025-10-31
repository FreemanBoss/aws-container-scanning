#!/bin/bash
# Build and push vulnerable sample app to ECR for testing

set -e

echo "Building and pushing vulnerable sample app..."

# Get AWS account and region
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION=$(aws configure get region || echo "us-east-1")
REPOSITORY_NAME="sample-app"
IMAGE_TAG="v1.0-vulnerable"

ECR_URI="${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${REPOSITORY_NAME}"

echo "Account: $ACCOUNT_ID"
echo "Region: $AWS_REGION"
echo "Repository: $REPOSITORY_NAME"
echo "Tag: $IMAGE_TAG"
echo ""

# Login to ECR
echo "Logging in to ECR..."
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com

# Build image
echo "Building Docker image..."
docker build -t $REPOSITORY_NAME:$IMAGE_TAG .

# Tag for ECR
echo "Tagging image..."
docker tag $REPOSITORY_NAME:$IMAGE_TAG $ECR_URI:$IMAGE_TAG

# Push to ECR
echo "Pushing to ECR..."
docker push $ECR_URI:$IMAGE_TAG

echo ""
echo "✅ Image pushed successfully!"
echo "Image: $ECR_URI:$IMAGE_TAG"
echo ""
echo "Scanning will start automatically..."
echo "Check scan results in AWS Console or CloudWatch"
