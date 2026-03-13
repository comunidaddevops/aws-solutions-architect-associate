#!/bin/bash
# Exercise 2: Implementing Elasticity - Destruction Script
# This script reverts the resources created by deploy.sh.

REGION="us-east-1"
echo "Starting destruction of Implementing Elasticity Lab..."

# 1. Delete Scheduled Action
echo "Deleting Scheduled Action..."
aws autoscaling delete-scheduled-action \
    --auto-scaling-group-name Simulearn-Game-ASG \
    --scheduled-action-name Scale-Up-Friday-Evening \
    --region $REGION 2>/dev/null || true

# 2. Delete Auto Scaling Group
echo "Deleting Auto Scaling Group (and terminating instances)..."
aws autoscaling delete-auto-scaling-group \
    --auto-scaling-group-name Simulearn-Game-ASG \
    --force-delete \
    --region $REGION 2>/dev/null || true

# Wait for ASG instances to terminate completely before deleting SG or Target Group
echo "Waiting for ASG and instances to disappear... (this can take a few minutes)"
sleep 15
while aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names Simulearn-Game-ASG --query "AutoScalingGroups[].AutoScalingGroupName" --output text | grep -q "Simulearn-Game-ASG"; do
    echo "Still waiting for ASG deletion..."
    sleep 15
done

# 3. Delete Launch Template
echo "Deleting Launch Template..."
aws ec2 delete-launch-template --launch-template-name Simulearn-Game-LT --region $REGION 2>/dev/null || true

# 4. Delete ALB and Target Group
ALB_ARN=$(aws elbv2 describe-load-balancers --names simulearn-game-alb --query "LoadBalancers[0].LoadBalancerArn" --output text --region $REGION 2>/dev/null)
if [ -n "$ALB_ARN" ]; then
    echo "Deleting Application Load Balancer..."
    aws elbv2 delete-load-balancer --load-balancer-arn $ALB_ARN --region $REGION
    echo "Waiting for ALB deletion to complete..."
    aws elbv2 wait load-balancers-deleted --load-balancer-arns $ALB_ARN --region $REGION
fi

TG_ARN=$(aws elbv2 describe-target-groups --names simulearn-game-tg --query "TargetGroups[0].TargetGroupArn" --output text --region $REGION 2>/dev/null)
if [ -n "$TG_ARN" ]; then
    echo "Deleting Target Group..."
    aws elbv2 delete-target-group --target-group-arn $TG_ARN --region $REGION
fi

# 5. Delete Security Groups
echo "Deleting Security Groups..."
WEB_SG_ID=$(aws ec2 describe-security-groups --filters "Name=group-name,Values=Simulearn-Backend-SG" --query "SecurityGroups[0].GroupId" --output text --region $REGION 2>/dev/null)
ALB_SG_ID=$(aws ec2 describe-security-groups --filters "Name=group-name,Values=Simulearn-ALB-SG" --query "SecurityGroups[0].GroupId" --output text --region $REGION 2>/dev/null)

# Wait a moment for network interfaces to detach fully
sleep 10 

if [ -n "$WEB_SG_ID" ] && [ "$WEB_SG_ID" != "None" ]; then
    aws ec2 delete-security-group --group-id $WEB_SG_ID --region $REGION || echo "Failed to delete Backend SG, it might still have attached ENIs."
fi

if [ -n "$ALB_SG_ID" ] && [ "$ALB_SG_ID" != "None" ]; then
    aws ec2 delete-security-group --group-id $ALB_SG_ID --region $REGION || echo "Failed to delete ALB SG."
fi

# 6. Delete Subnets
echo "Deleting Subnets..."
for SUBNET in $(aws ec2 describe-subnets --filters "Name=tag:Name,Values=Simulearn-PubSub-A,Simulearn-PubSub-B" --query "Subnets[].SubnetId" --output text --region $REGION); do
    if [ -n "$SUBNET" ]; then
        aws ec2 delete-subnet --subnet-id $SUBNET --region $REGION
    fi
done

# 7. Detach and delete IGW
IGW_ID=$(aws ec2 describe-internet-gateways --filters "Name=tag:Name,Values=Simulearn-Elasticity-IGW" --query "InternetGateways[0].InternetGatewayId" --output text --region $REGION 2>/dev/null)
VPC_ID=$(aws ec2 describe-vpcs --filters "Name=tag:Name,Values=Simulearn-Elasticity-VPC" --query "Vpcs[0].VpcId" --output text --region $REGION 2>/dev/null)

if [ -n "$IGW_ID" ] && [ -n "$VPC_ID" ] && [ "$IGW_ID" != "None" ]; then
    echo "Detaching and Deleting IGW..."
    aws ec2 detach-internet-gateway --internet-gateway-id $IGW_ID --vpc-id $VPC_ID --region $REGION
    aws ec2 delete-internet-gateway --internet-gateway-id $IGW_ID --region $REGION
fi

# 8. Route Table
RT_ID=$(aws ec2 describe-route-tables --filters "Name=tag:Name,Values=Simulearn-Elasticity-RT" --query "RouteTables[0].RouteTableId" --output text --region $REGION 2>/dev/null)
if [ -n "$RT_ID" ] && [ "$RT_ID" != "None" ]; then
    echo "Deleting Route Table..."
    for ASSOC in $(aws ec2 describe-route-tables --route-table-ids $RT_ID --query "RouteTables[0].Associations[].RouteTableAssociationId" --output text --region $REGION); do
        if [ -n "$ASSOC" ] && [ "$ASSOC" != "None" ]; then
            aws ec2 disassociate-route-table --association-id $ASSOC --region $REGION
        fi
    done
    aws ec2 delete-route-table --route-table-id $RT_ID --region $REGION
fi

# 9. Delete VPC
if [ -n "$VPC_ID" ] && [ "$VPC_ID" != "None" ]; then
    echo "Deleting VPC..."
    aws ec2 delete-vpc --vpc-id $VPC_ID --region $REGION
fi

echo "Infrastructure destruction complete."
