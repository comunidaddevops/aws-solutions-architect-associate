#!/bin/bash
# 1. Create the VPC
VPC_ID=$(aws ec2 create-vpc --cidr-block 10.0.0.0/16 --query Vpc.VpcId --output text)
aws ec2 create-tags --resources $VPC_ID --tags Key=Name,Value=Simulearn-VPC

# 2. Create 4 Subnets (2 Public and 2 Private across 2 different AZs)
# Assuming deployment in us-east-1
SUBNET_PUB_1=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block 10.0.1.0/24 --availability-zone us-east-1a --query Subnet.SubnetId --output text)
SUBNET_PUB_2=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block 10.0.2.0/24 --availability-zone us-east-1b --query Subnet.SubnetId --output text)
SUBNET_PRIV_1=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block 10.0.3.0/24 --availability-zone us-east-1a --query Subnet.SubnetId --output text)
SUBNET_PRIV_2=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block 10.0.4.0/24 --availability-zone us-east-1b --query Subnet.SubnetId --output text)

aws ec2 create-tags --resources $SUBNET_PUB_1 $SUBNET_PUB_2 --tags Key=Name,Value=Simulearn-Public-Subnet
aws ec2 create-tags --resources $SUBNET_PRIV_1 $SUBNET_PRIV_2 --tags Key=Name,Value=Simulearn-Private-Subnet

# Enable auto-assign public IP on the public subnets
aws ec2 modify-subnet-attribute --subnet-id $SUBNET_PUB_1 --map-public-ip-on-launch
aws ec2 modify-subnet-attribute --subnet-id $SUBNET_PUB_2 --map-public-ip-on-launch

# 3. Create the Internet Gateway and attach it to the VPC
IGW_ID=$(aws ec2 create-internet-gateway --query InternetGateway.InternetGatewayId --output text)
aws ec2 attach-internet-gateway --vpc-id $VPC_ID --internet-gateway-id $IGW_ID
aws ec2 create-tags --resources $IGW_ID --tags Key=Name,Value=Simulearn-IGW

# 4. Create the Public Route Table, add default route to IGW and associate public subnets
RT_ID=$(aws ec2 create-route-table --vpc-id $VPC_ID --query RouteTable.RouteTableId --output text)
aws ec2 create-tags --resources $RT_ID --tags Key=Name,Value=Simulearn-Public-RT
aws ec2 create-route --route-table-id $RT_ID --destination-cidr-block 0.0.0.0/0 --gateway-id $IGW_ID
aws ec2 associate-route-table --subnet-id $SUBNET_PUB_1 --route-table-id $RT_ID
aws ec2 associate-route-table --subnet-id $SUBNET_PUB_2 --route-table-id $RT_ID

# 5. Create the Security Group and allow HTTP traffic (Port 80)
SG_ID=$(aws ec2 create-security-group --group-name SimulearnWebSG --description "Allow HTTP traffic" --vpc-id $VPC_ID --query GroupId --output text)
aws ec2 authorize-security-group-ingress --group-id $SG_ID --protocol tcp --port 80 --cidr 0.0.0.0/0

# 6. Launch the EC2 instance in the first public subnet with the Bootstrap script
# Note: Using a specific Amazon Linux 2023 AMI in us-east-1
AMI_ID="ami-02dfbd4ff395f2a1b" 
INSTANCE_ID=$(aws ec2 run-instances \
    --image-id $AMI_ID \
    --count 1 \
    --instance-type t2.micro \
    --security-group-ids $SG_ID \
    --subnet-id $SUBNET_PUB_1 \
    --user-data file://userdata.sh \
    --query 'Instances[0].InstanceId' \
    --output text)

aws ec2 create-tags --resources $INSTANCE_ID --tags Key=Name,Value=Simulearn-WebServer
