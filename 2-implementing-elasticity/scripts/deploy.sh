#!/bin/bash
# Exercise 2: Implementing Elasticity - Deployment Script
# This script uses imperative AWS CLI commands to build the infrastructure.
# Ensure your AWS CLI is configured with 'aws configure' and you have appropriate permissions.

# Variables
REGION="us-east-1"
AMI_ID="ami-02dfbd4ff395f2a1b" # Amazon Linux 2023 in us-east-1

echo "Starting deployment of Implementing Elasticity Lab..."

# 1. Create the VPC
echo "Creating VPC..."
VPC_ID=$(aws ec2 create-vpc --cidr-block 10.0.0.0/16 --query Vpc.VpcId --output text --region $REGION)
aws ec2 create-tags --resources $VPC_ID --tags Key=Name,Value=Simulearn-Elasticity-VPC
aws ec2 modify-vpc-attribute --vpc-id $VPC_ID --enable-dns-hostnames

# 2. Create 2 Public Subnets in different AZs
echo "Creating Subnets..."
SUBNET_PUB_1=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block 10.0.1.0/24 --availability-zone ${REGION}a --query Subnet.SubnetId --output text --region $REGION)
SUBNET_PUB_2=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block 10.0.2.0/24 --availability-zone ${REGION}b --query Subnet.SubnetId --output text --region $REGION)

aws ec2 create-tags --resources $SUBNET_PUB_1 --tags Key=Name,Value=Simulearn-PubSub-A
aws ec2 create-tags --resources $SUBNET_PUB_2 --tags Key=Name,Value=Simulearn-PubSub-B

# Enable auto-assign public IPs
aws ec2 modify-subnet-attribute --subnet-id $SUBNET_PUB_1 --map-public-ip-on-launch
aws ec2 modify-subnet-attribute --subnet-id $SUBNET_PUB_2 --map-public-ip-on-launch

# 3. Create Internet Gateway and attach to VPC
echo "Configuring Internet Gateway..."
IGW_ID=$(aws ec2 create-internet-gateway --query InternetGateway.InternetGatewayId --output text --region $REGION)
aws ec2 attach-internet-gateway --vpc-id $VPC_ID --internet-gateway-id $IGW_ID
aws ec2 create-tags --resources $IGW_ID --tags Key=Name,Value=Simulearn-Elasticity-IGW

# 4. Create Route Table, default route, and associate subnets
echo "Configuring Routing..."
RT_ID=$(aws ec2 create-route-table --vpc-id $VPC_ID --query RouteTable.RouteTableId --output text --region $REGION)
aws ec2 create-tags --resources $RT_ID --tags Key=Name,Value=Simulearn-Elasticity-RT
aws ec2 create-route --route-table-id $RT_ID --destination-cidr-block 0.0.0.0/0 --gateway-id $IGW_ID > /dev/null
aws ec2 associate-route-table --subnet-id $SUBNET_PUB_1 --route-table-id $RT_ID > /dev/null
aws ec2 associate-route-table --subnet-id $SUBNET_PUB_2 --route-table-id $RT_ID > /dev/null

# 5. Create Security Groups
echo "Creating Security Groups..."
# ALB Security Group
ALB_SG_ID=$(aws ec2 create-security-group --group-name Simulearn-ALB-SG --description "Allow HTTP to ALB" --vpc-id $VPC_ID --query GroupId --output text --region $REGION)
aws ec2 authorize-security-group-ingress --group-id $ALB_SG_ID --protocol tcp --port 80 --cidr 0.0.0.0/0 --region $REGION
aws ec2 create-tags --resources $ALB_SG_ID --tags Key=Name,Value=Simulearn-ALB-SG

# Backend (EC2) Security Group
WEB_SG_ID=$(aws ec2 create-security-group --group-name Simulearn-Backend-SG --description "Allow HTTP from ALB" --vpc-id $VPC_ID --query GroupId --output text --region $REGION)
aws ec2 authorize-security-group-ingress --group-id $WEB_SG_ID --protocol tcp --port 80 --source-group $ALB_SG_ID --region $REGION
aws ec2 create-tags --resources $WEB_SG_ID --tags Key=Name,Value=Simulearn-Backend-SG

# 6. Create Target Group
echo "Creating Target Group..."
TG_ARN=$(aws elbv2 create-target-group --name simulearn-game-tg --protocol HTTP --port 80 --vpc-id $VPC_ID --health-check-path "/" --query "TargetGroups[0].TargetGroupArn" --output text --region $REGION)

# 7. Create Application Load Balancer
echo "Creating Application Load Balancer (this can take a moment)..."
ALB_ARN=$(aws elbv2 create-load-balancer --name simulearn-game-alb --subnets $SUBNET_PUB_1 $SUBNET_PUB_2 --security-groups $ALB_SG_ID --scheme internet-facing --query "LoadBalancers[0].LoadBalancerArn" --output text --region $REGION)
ALB_DNS=$(aws elbv2 describe-load-balancers --load-balancer-arns $ALB_ARN --query "LoadBalancers[0].DNSName" --output text --region $REGION)

# 8. Create Listener
echo "Creating ALB Listener..."
aws elbv2 create-listener --load-balancer-arn $ALB_ARN --protocol HTTP --port 80 --default-actions Type=forward,TargetGroupArn=$TG_ARN > /dev/null

# 9. Create Launch Template
echo "Creating Launch Template..."
USERDATA_B64=$(base64 -i userdata.sh | tr -d '\n')
LT_JSON=$(cat <<EOF
{
  "ImageId": "$AMI_ID",
  "InstanceType": "t2.micro",
  "SecurityGroupIds": ["$WEB_SG_ID"],
  "UserData": "$USERDATA_B64",
  "TagSpecifications": [{
    "ResourceType": "instance",
    "Tags": [{"Key":"Name","Value":"Simulearn-Gaming-Server"}]
  }]
}
EOF
)
LT_ID=$(aws ec2 create-launch-template --launch-template-name Simulearn-Game-LT --version-description "v1" --launch-template-data "$LT_JSON" --query "LaunchTemplate.LaunchTemplateId" --output text --region $REGION)

# 10. Wait for ALB to become active (ASG creation may fail if Target Group isn't ready)
echo "Waiting for ALB to become Active..."
aws elbv2 wait load-balancer-available --load-balancer-arns $ALB_ARN --region $REGION

# 11. Create Auto Scaling Group
echo "Creating Auto Scaling Group..."
aws autoscaling create-auto-scaling-group \
    --auto-scaling-group-name Simulearn-Game-ASG \
    --launch-template LaunchTemplateId=$LT_ID,Version='$Latest' \
    --min-size 2 \
    --max-size 4 \
    --desired-capacity 2 \
    --vpc-zone-identifier "$SUBNET_PUB_1,$SUBNET_PUB_2" \
    --target-group-arns $TG_ARN \
    --health-check-type ELB \
    --health-check-grace-period 300 \
    --region $REGION

# 12. Create Target Tracking Scaling Policy (CPU 50%)
echo "Configuring Scaling Policy..."
POLICY_JSON=$(cat <<EOF
{
  "TargetValue": 50.0,
  "PredefinedMetricSpecification": {
    "PredefinedMetricType": "ASGAverageCPUUtilization"
  }
}
EOF
)
aws autoscaling put-scaling-policy \
    --auto-scaling-group-name Simulearn-Game-ASG \
    --policy-name CPU-Target-Tracking \
    --policy-type TargetTrackingScaling \
    --target-tracking-configuration "$POLICY_JSON" \
    --region $REGION > /dev/null

# 13. Create Scheduled Action
echo "Configuring Scheduled Action..."
aws autoscaling put-scheduled-update-group-action \
    --auto-scaling-group-name Simulearn-Game-ASG \
    --scheduled-action-name Scale-Up-Friday-Evening \
    --recurrence "0 20 * * 5" \
    --desired-capacity 3 \
    --min-size 2 \
    --max-size 4 \
    --region $REGION

echo ""
echo "Deployment successful!"
echo "Your Application Load Balancer DNS Name is:"
echo "http://$ALB_DNS"
echo "Note: It may take 2-4 minutes for the instances to pass health checks and the site to be available."
