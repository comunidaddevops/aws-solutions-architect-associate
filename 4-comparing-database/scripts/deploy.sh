#!/bin/bash

# Pre-requisite: Gather VPC and Subnet details
VPC_ID=$(aws ec2 describe-vpcs --filters Name=is-default,Values=true --query "Vpcs[0].VpcId" --output text)
SUBNET_IDS=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" --query 'Subnets[*].SubnetId' --output text)

# Pre-requisite: Create Security Group for DAX
SG_ID=$(aws ec2 create-security-group \
    --group-name comunidad-devops-dax-sg \
    --description "Security group for DAX cluster" \
    --vpc-id $VPC_ID \
    --query "GroupId" \
    --output text)

# Pre-requisite: Allow Inbound DAX traffic
aws ec2 authorize-security-group-ingress \
    --group-id $SG_ID \
    --protocol tcp \
    --port 8111 \
    --cidr 0.0.0.0/0

# Pre-requisite: Create DAX Trust Policy
cat <<EOF > dax-trust-policy.json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "dax.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

# Pre-requisite: Create DAX IAM Role
ROLE_ARN=$(aws iam create-role \
    --role-name ComunidadDevopsDAXServiceRole \
    --assume-role-policy-document file://dax-trust-policy.json \
    --query "Role.Arn" \
    --output text)

# Pre-requisite: Attach Policy to IAM Role
aws iam attach-role-policy \
    --role-name ComunidadDevopsDAXServiceRole \
    --policy-arn arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess

# Pre-requisite: Create DAX Subnet Group
aws dax create-subnet-group \
    --subnet-group-name comunidad-devops-dax-subnet-group \
    --description "Subnet group for DAX" \
    --subnet-ids $SUBNET_IDS

# Step 1: Create the Amazon Aurora Database
# Create the Aurora DB Cluster
aws rds create-db-cluster \
    --db-cluster-identifier comunidad-devops-aurora-cluster \
    --engine aurora-mysql \
    --master-username dbadmin \
    --master-user-password YourSegurePassord123! \
    --backup-retention-period 7

# Create the Primary DB Instance
aws rds create-db-instance \
    --db-instance-identifier comunidad-devops-primary-instance \
    --db-cluster-identifier comunidad-devops-aurora-cluster \
    --engine aurora-mysql \
    --db-instance-class db.t3.medium

# Step 2: Deploy an Aurora Read Replica
# Create the Read Replica Instance
aws rds create-db-instance \
    --db-instance-identifier comunidad-devops-replica-instance \
    --db-cluster-identifier comunidad-devops-aurora-cluster \
    --engine aurora-mysql \
    --db-instance-class db.t3.medium \
    --promotion-tier 1

# Step 3: Create the Amazon DynamoDB Table
aws dynamodb create-table \
    --table-name MyDynamoDBTable \
    --attribute-definitions AttributeName=ID,AttributeType=S \
    --key-schema AttributeName=ID,KeyType=HASH \
    --billing-mode PROVISIONED \
    --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5

# Step 4: Deploy a DynamoDB Accelerator (DAX) Cluster
aws dax create-cluster \
    --cluster-name comunidad-devops-dax-cluster \
    --node-type dax.t3.small \
    --replication-factor 3 \
    --iam-role-arn $ROLE_ARN \
    --subnet-group-name comunidad-devops-dax-subnet-group \
    --security-group-ids $SG_ID