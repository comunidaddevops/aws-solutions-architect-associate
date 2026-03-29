#!/bin/bash

echo "========================================================="
echo " DESTROYING AWS RESOURCES (Safe & Ordered)"
echo "========================================================="

# 1. DAX Cluster Deletion
# ---------------------------------------------------------
# AWS doesn't allow deleting a DAX cluster if it's "creating". 
# We must wait for it to be fully created or available before deleting.
# Then, we must wait for it to be fully deleted before deleting the Subnet and Security Group.

echo "1. Checking status of DAX Cluster 'comunidad-devops-dax-cluster'..."
DAX_STATUS=$(aws dax describe-clusters --cluster-names comunidad-devops-dax-cluster --query "Clusters[0].Status" --output text 2>/dev/null || echo "not-found")

if [ "$DAX_STATUS" == "creating" ]; then
    echo "   [!] DAX cluster is currently 'creating'. We must wait until it finishes to delete it."
    while [ "$DAX_STATUS" == "creating" ]; do
        sleep 30
        echo -n "."
        DAX_STATUS=$(aws dax describe-clusters --cluster-names comunidad-devops-dax-cluster --query "Clusters[0].Status" --output text 2>/dev/null || echo "not-found")
    done
    echo "   DAX cluster is now out of 'creating' state."
fi

if [ "$DAX_STATUS" != "not-found" ] && [ "$DAX_STATUS" != "deleting" ]; then
    echo "   Deleting DAX Cluster..."
    aws dax delete-cluster --cluster-name comunidad-devops-dax-cluster > /dev/null 2>&1 || true
fi

echo "   Waiting for DAX Cluster to be fully deleted (this takes a few minutes)..."
while aws dax describe-clusters --cluster-names comunidad-devops-dax-cluster 2>/dev/null | grep -q "comunidad-devops-dax-cluster"; do
    sleep 30
    echo -n "."
done
echo "   Done!"

# 2. DynamoDB Table Deletion
# ---------------------------------------------------------
echo "2. Deleting DynamoDB Table 'MyDynamoDBTable'..."
aws dynamodb delete-table --table-name MyDynamoDBTable > /dev/null 2>&1 || true

# 3. Aurora DB Deletion
# ---------------------------------------------------------
echo "3. Deleting Aurora Database Instances..."
aws rds delete-db-instance --db-instance-identifier comunidad-devops-replica-instance --skip-final-snapshot > /dev/null 2>&1 || true
aws rds delete-db-instance --db-instance-identifier comunidad-devops-primary-instance --skip-final-snapshot > /dev/null 2>&1 || true

echo "   Waiting for DB Instances to terminate fully..."
aws rds wait db-instance-deleted --db-instance-identifier comunidad-devops-replica-instance 2>/dev/null || true
aws rds wait db-instance-deleted --db-instance-identifier comunidad-devops-primary-instance 2>/dev/null || true
echo "   Done!"

echo "   Deleting Aurora Database Cluster..."
aws rds delete-db-cluster --db-cluster-identifier comunidad-devops-aurora-cluster --skip-final-snapshot > /dev/null 2>&1 || true
echo "   Waiting for Cluster to terminate..."
aws rds wait db-cluster-deleted --db-cluster-identifier comunidad-devops-aurora-cluster 2>/dev/null || true
echo "   Done!"

# 4. Cleanup Infrastructure (Subnets, IAM, Security Groups) 
# ---------------------------------------------------------
# This can only run successfully when DAX is completely wiped.

echo "4. Deleting DAX Subnet Group..."
aws dax delete-subnet-group --subnet-group-name comunidad-devops-dax-subnet-group > /dev/null 2>&1 || true

echo "5. Detaching Policy and Deleting IAM Role..."
aws iam detach-role-policy --role-name ComunidadDevopsDAXServiceRole --policy-arn arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess > /dev/null 2>&1 || true
aws iam delete-role --role-name ComunidadDevopsDAXServiceRole > /dev/null 2>&1 || true

echo "6. Deleting Security Group..."
SG_ID=$(aws ec2 describe-security-groups --filters Name=group-name,Values=comunidad-devops-dax-sg --query "SecurityGroups[0].GroupId" --output text 2>/dev/null)
if [ "$SG_ID" != "None" ] && [ -n "$SG_ID" ]; then
    # Retry loop because attached Network Interfaces might take a moment to be released by AWS internally
    for i in {1..6}; do
        if aws ec2 delete-security-group --group-id $SG_ID > /dev/null 2>&1; then
            echo "   Done!"
            break
        fi
        sleep 10
    done
fi

echo "========================================================="
echo " ENVIRONMENT HAS BEEN COMPLETELY RESET"
echo "========================================================="
