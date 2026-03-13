#!/bin/bash
echo "Destroying infrastructure..."

# Wait a moment to ensure eventual consistency if recently created
sleep 5

# 1. Terminate EC2 Instance
INSTANCE_ID=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=Simulearn-WebServer" "Name=instance-state-name,Values=running,pending,stopped" --query "Reservations[].Instances[].InstanceId" --output text)
if [ -n "$INSTANCE_ID" ]; then
    echo "Terminating instance $INSTANCE_ID..."
    aws ec2 terminate-instances --instance-ids $INSTANCE_ID
    echo "Waiting for instance to terminate..."
    aws ec2 wait instance-terminated --instance-ids $INSTANCE_ID
fi

# 2. Delete Security Group
SG_ID=$(aws ec2 describe-security-groups --filters "Name=group-name,Values=SimulearnWebSG" --query "SecurityGroups[].GroupId" --output text)
if [ -n "$SG_ID" ]; then
    echo "Deleting Security Group $SG_ID..."
    aws ec2 delete-security-group --group-id $SG_ID
fi

# 3. Delete Subnets
for SUBNET in $(aws ec2 describe-subnets --filters "Name=tag:Name,Values=Simulearn-Public-Subnet,Simulearn-Private-Subnet" --query "Subnets[].SubnetId" --output text); do
    if [ -n "$SUBNET" ]; then
        echo "Deleting Subnet $SUBNET..."
        aws ec2 delete-subnet --subnet-id $SUBNET
    fi
done

# 4. Detach and delete IGW
IGW_ID=$(aws ec2 describe-internet-gateways --filters "Name=tag:Name,Values=Simulearn-IGW" --query "InternetGateways[].InternetGatewayId" --output text)
VPC_ID=$(aws ec2 describe-vpcs --filters "Name=tag:Name,Values=Simulearn-VPC" --query "Vpcs[].VpcId" --output text)

if [ -n "$IGW_ID" ] && [ -n "$VPC_ID" ]; then
    echo "Detaching IGW $IGW_ID from VPC $VPC_ID..."
    aws ec2 detach-internet-gateway --internet-gateway-id $IGW_ID --vpc-id $VPC_ID
    echo "Deleting IGW $IGW_ID..."
    aws ec2 delete-internet-gateway --internet-gateway-id $IGW_ID
fi

# 5. Route Table
RT_ID=$(aws ec2 describe-route-tables --filters "Name=tag:Name,Values=Simulearn-Public-RT" --query "RouteTables[].RouteTableId" --output text)
if [ -n "$RT_ID" ]; then
    # Delete associations first if any remain
    for ASSOC in $(aws ec2 describe-route-tables --route-table-ids $RT_ID --query "RouteTables[].Associations[].RouteTableAssociationId" --output text); do
        if [ -n "$ASSOC" ] && [ "$ASSOC" != "None" ]; then
            echo "Disassociating Route Table $ASSOC..."
            aws ec2 disassociate-route-table --association-id $ASSOC
        fi
    done
    echo "Deleting Route Table $RT_ID..."
    aws ec2 delete-route-table --route-table-id $RT_ID
fi

# 6. Delete VPC
if [ -n "$VPC_ID" ]; then
    echo "Deleting VPC $VPC_ID..."
    aws ec2 delete-vpc --vpc-id $VPC_ID
fi

echo "Infrastructure destroyed successfully."
