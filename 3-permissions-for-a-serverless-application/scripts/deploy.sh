#!/bin/bash
# Exercise 3: Implementing Permissions for a Serverless Application
# This script uses imperative AWS CLI commands to build the infrastructure.
# Ensure your AWS CLI is configured with 'aws configure' and you have appropriate permissions.

# Variables
REGION="us-east-1"
S3_BUCKET_NAME="my-serverless-lab-bucket-comunidaddevops-12345"
DYNAMODB_TABLE_NAME="LabTable"
ACCOUNT_ID=$(aws sts get-caller-identity | jq -r ".Account")
LAMBDA_NAME="LabLambdaFunction"
LAMBDA_ROLE_NAME="LabLambdaRole"

# 1. Create Lamba Role and Attach Policies
aws iam create-role --role-name $LAMBDA_ROLE_NAME --assume-role-policy-document '{"Version": "2012-10-17", "Statement": [{ "Effect": "Allow", "Principal": {"Service": "lambda.amazonaws.com"}, "Action": "sts:AssumeRole"}]}'
aws iam attach-role-policy --role-name $LAMBDA_ROLE_NAME --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole

# 2. Create the policy for dynamodb
cat <<EOF > dynamodb-policy.json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": "dynamodb:PutItem",
            "Resource": "arn:aws:dynamodb:${REGION}:${ACCOUNT_ID}:table/${DYNAMODB_TABLE_NAME}"
        }
    ]
}
EOF

# 3. Create the policy and capture the ARN
DYNAMO_POLICY_ARN=$(aws iam create-policy --policy-name CustomDynamoDBPut \
    --policy-document file://dynamodb-policy.json | jq -r .Policy.Arn)

# 4. Create the policy for s3
cat <<EOF > s3-policy.json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": "s3:PutObject",
            "Resource": "arn:aws:s3:::${S3_BUCKET_NAME}/*"
        }
    ]
}
EOF

# 5. Create the policy and capture the ARN
S3_POLICY_ARN=$(aws iam create-policy --policy-name CustomS3Put \
    --policy-document file://s3-policy.json | jq -r .Policy.Arn)


# 6. Attach the policies to the role
aws iam attach-role-policy --role-name $LAMBDA_ROLE_NAME --policy-arn $DYNAMO_POLICY_ARN
aws iam attach-role-policy --role-name $LAMBDA_ROLE_NAME --policy-arn $S3_POLICY_ARN

# 7. Create S3 Bucket
aws s3api create-bucket --bucket $S3_BUCKET_NAME --region $REGION

# 8. Attach bucket policy
cat <<EOF > bucket-policy.json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Deny",
            "Principal": "*",
            "Action": "s3:PutObject",
            "Resource": "arn:aws:s3:::${S3_BUCKET_NAME}/*",
            "Condition": {
                "StringNotEquals": {
                    "aws:PrincipalArn": "arn:aws:iam::${ACCOUNT_ID}:role/$LAMBDA_ROLE_NAME"
                }
            }
        }
    ]
}
EOF

aws s3api put-bucket-policy --bucket $S3_BUCKET_NAME --policy file://bucket-policy.json



# 9. Create DynamoDB Table
aws dynamodb create-table --table-name $DYNAMODB_TABLE_NAME --attribute-definitions AttributeName=ID,AttributeType=S --key-schema AttributeName=ID,KeyType=HASH --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5

# 10. Create Lambda Function
cat <<EOF > main.py 
import os
import boto3
import uuid
s3 = boto3.resource('s3')
dynamodb = boto3.resource('dynamodb')
def lambda_handler(event, context):
   message = "Hello from AWS Lambda!"
   encoded_string = message.encode("utf-8")
   file_name = "hello.txt"
   s3_path = "test/" + file_name
   dynamodb.Table(os.environ['DYNAMODB_TABLE_NAME']).put_item(Item={'ID': '12345','content':message})
   s3.Bucket(os.environ['S3_BUCKET_NAME']).put_object(Key=s3_path, Body=encoded_string)
   response = {
      'statusCode': 200,
      'body': 'success!',
      'headers': {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*'
      },
   }
   return response
EOF

zip function.zip main.py

sleep 10

aws lambda create-function --function-name $LAMBDA_NAME --environment "Variables={DYNAMODB_TABLE_NAME=$DYNAMODB_TABLE_NAME,S3_BUCKET_NAME=$S3_BUCKET_NAME}" --runtime python3.8 --role arn:aws:iam::${ACCOUNT_ID}:role/$LAMBDA_ROLE_NAME --handler main.lambda_handler --zip-file fileb://function.zip --region $REGION
aws lambda wait function-active --function-name $LAMBDA_NAME --region $REGION

# 11. Invoke Lambda Function
aws lambda invoke --function-name $LAMBDA_NAME --region $REGION response.json
cat response.json