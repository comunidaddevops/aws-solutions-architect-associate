#!/bin/bash

# Variables
REGION="us-east-1"
S3_BUCKET_NAME="my-serverless-lab-bucket-comunidaddevops-12345"
DYNAMODB_TABLE_NAME="LabTable"
ACCOUNT_ID=$(aws sts get-caller-identity | jq -r ".Account")
LAMBDA_NAME="LabLambdaFunction"
LAMBDA_ROLE_NAME="LabLambdaRole"

echo "Deleting Lambda Function..."
aws lambda delete-function --function-name $LAMBDA_NAME --region $REGION

echo "Deleting DynamoDB Table..."
aws dynamodb delete-table --table-name $DYNAMODB_TABLE_NAME --region $REGION

echo "Emptying and Deleting S3 Bucket..."
# Remove all files inside the bucket
aws s3 rm s3://$S3_BUCKET_NAME --recursive --region $REGION

# Delete the bucket itself
aws s3api delete-bucket --bucket $S3_BUCKET_NAME --region $REGION

echo "Detaching and Deleting IAM Policies..."
# Define the ARNs for your custom policies
DYNAMO_POLICY_ARN="arn:aws:iam::${ACCOUNT_ID}:policy/CustomDynamoDBPut"
S3_POLICY_ARN="arn:aws:iam::${ACCOUNT_ID}:policy/CustomS3Put"

# 1. Detach custom policies from the role
aws iam detach-role-policy --role-name $LAMBDA_ROLE_NAME --policy-arn $DYNAMO_POLICY_ARN
aws iam detach-role-policy --role-name $LAMBDA_ROLE_NAME --policy-arn $S3_POLICY_ARN

# 2. Detach the AWS Managed policy
aws iam detach-role-policy --role-name $LAMBDA_ROLE_NAME --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole

# 3. Delete the custom policy objects from your account
aws iam delete-policy --policy-arn $DYNAMO_POLICY_ARN
aws iam delete-policy --policy-arn $S3_POLICY_ARN

echo "Deleting IAM Role..."
aws iam delete-role --role-name $LAMBDA_ROLE_NAME

echo "Removing local temporary files..."
rm -r bucket-policy.json dynamodb-policy.json s3-policy.json main.py function.zip response.json