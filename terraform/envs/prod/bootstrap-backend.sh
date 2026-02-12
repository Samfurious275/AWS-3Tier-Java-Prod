#!/bin/bash
# bootstrap-backend.sh
ENV=prod
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
BUCKET="company-terraform-state-${ACCOUNT_ID}-${ENV}"
REGION=us-east-1

# Create encrypted, versioned, private S3 bucket
aws s3api create-bucket --bucket $BUCKET --region $REGION \
  --create-bucket-configuration LocationConstraint=$REGION

aws s3api put-bucket-versioning --bucket $BUCKET \
  --versioning-configuration Status=Enabled

aws s3api put-bucket-encryption --bucket $BUCKET \
  --server-side-encryption-configuration '{
    "Rules": [{"ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "AES256"}}]
  }'

aws s3api put-public-access-block --bucket $BUCKET \
  --public-access-block-configuration BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

# Create DynamoDB lock table
aws dynamodb create-table --table-name terraform-locks-${ENV} \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST --region $REGION

echo "✅ Backend ready:"
echo "   Bucket: $BUCKET"
echo "   Table:  terraform-locks-${ENV}"
