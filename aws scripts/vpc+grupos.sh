#!/bin/bash

# Top-level variables for names and tags
VPC_NAME="vpc-mensagl-2025-MarioAja"
REGION="us-east-1"
AVAILABILITY_ZONE1="${REGION}a"
AVAILABILITY_ZONE2="${REGION}b"

# Create VPC and capture its ID
VPC_ID=$(aws ec2 create-vpc --cidr-block "10.0.0.0/16" --instance-tenancy "default" --tag-specifications "ResourceType=vpc,Tags=[{Key=Name,Value=${VPC_NAME}-vpc}]" --query 'Vpc.VpcId' --output text)
aws ec2 modify-vpc-attribute --vpc-id $VPC_ID --enable-dns-hostnames

# Create public and private subnets, capture their IDs
SUBNET_PUBLIC1=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block "10.0.1.0/24" --availability-zone $AVAILABILITY_ZONE1 --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=${VPC_NAME}-subnet-public1-${AVAILABILITY_ZONE1}}]" --query 'Subnet.SubnetId' --output text)
aws ec2 modify-subnet-attribute --subnet-id $SUBNET_PUBLIC1 --map-public-ip-on-launch

SUBNET_PUBLIC2=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block "10.0.2.0/24" --availability-zone $AVAILABILITY_ZONE2 --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=${VPC_NAME}-subnet-public2-${AVAILABILITY_ZONE2}}]" --query 'Subnet.SubnetId' --output text)
aws ec2 modify-subnet-attribute --subnet-id $SUBNET_PUBLIC2 --map-public-ip-on-launch

SUBNET_PRIVATE1=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block "10.0.3.0/24" --availability-zone $AVAILABILITY_ZONE1 --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=${VPC_NAME}-subnet-private1-${AVAILABILITY_ZONE1}}]" --query 'Subnet.SubnetId' --output text)

SUBNET_PRIVATE2=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block "10.0.4.0/24" --availability-zone $AVAILABILITY_ZONE2 --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=${VPC_NAME}-subnet-private2-${AVAILABILITY_ZONE2}}]" --query 'Subnet.SubnetId' --output text)

# Create Internet Gateway and attach to the VPC
IGW_ID=$(aws ec2 create-internet-gateway --tag-specifications "ResourceType=internet-gateway,Tags=[{Key=Name,Value=${VPC_NAME}-igw}]" --query 'InternetGateway.InternetGatewayId' --output text)
aws ec2 attach-internet-gateway --internet-gateway-id $IGW_ID --vpc-id $VPC_ID

# Create public route table and associate public subnets
RTB_PUBLIC=$(aws ec2 create-route-table --vpc-id $VPC_ID --tag-specifications "ResourceType=route-table,Tags=[{Key=Name,Value=${VPC_NAME}-rtb-public}]" --query 'RouteTable.RouteTableId' --output text)
aws ec2 create-route --route-table-id $RTB_PUBLIC --destination-cidr-block "0.0.0.0/0" --gateway-id $IGW_ID
aws ec2 associate-route-table --route-table-id $RTB_PUBLIC --subnet-id $SUBNET_PUBLIC1
aws ec2 associate-route-table --route-table-id $RTB_PUBLIC --subnet-id $SUBNET_PUBLIC2

# Create Elastic IP and NAT Gateway
EIP_ALLOC_ID=$(aws ec2 allocate-address --domain vpc --tag-specifications "ResourceType=elastic-ip,Tags=[{Key=Name,Value=${VPC_NAME}-eip-${AVAILABILITY_ZONE1}}]" --query 'AllocationId' --output text)
NATGW_ID=$(aws ec2 create-nat-gateway --subnet-id $SUBNET_PUBLIC1 --allocation-id $EIP_ALLOC_ID --tag-specifications "ResourceType=natgateway,Tags=[{Key=Name,Value=${VPC_NAME}-nat-public1-${AVAILABILITY_ZONE1}}]" --query 'NatGateway.NatGatewayId' --output text)

# Wait for the NAT Gateway to become available
aws ec2 wait nat-gateway-available --nat-gateway-ids $NATGW_ID

# Create private route tables and associate private subnets
RTB_PRIVATE1=$(aws ec2 create-route-table --vpc-id $VPC_ID --tag-specifications "ResourceType=route-table,Tags=[{Key=Name,Value=${VPC_NAME}-rtb-private1-${AVAILABILITY_ZONE1}}]" --query 'RouteTable.RouteTableId' --output text)
aws ec2 create-route --route-table-id $RTB_PRIVATE1 --destination-cidr-block "0.0.0.0/0" --nat-gateway-id $NATGW_ID
aws ec2 associate-route-table --route-table-id $RTB_PRIVATE1 --subnet-id $SUBNET_PRIVATE1

RTB_PRIVATE2=$(aws ec2 create-route-table --vpc-id $VPC_ID --tag-specifications "ResourceType=route-table,Tags=[{Key=Name,Value=${VPC_NAME}-rtb-private2-${AVAILABILITY_ZONE2}}]" --query 'RouteTable.RouteTableId' --output text)
aws ec2 create-route --route-table-id $RTB_PRIVATE2 --destination-cidr-block "0.0.0.0/0" --nat-gateway-id $NATGW_ID
aws ec2 associate-route-table --route-table-id $RTB_PRIVATE2 --subnet-id $SUBNET_PRIVATE2

# Final verifications
#aws ec2 describe-vpcs --vpc-ids $VPC_ID
#aws ec2 describe-nat-gateways --nat-gateway-ids $NATGW_ID
#aws ec2 describe-route-tables --route-table-ids $RTB_PRIVATE1 $RTB_PRIVATE2


###########################################################################################################


# Variables
DESCRIPTION="Security group for EC2 instances"
MY_IP="0.0.0.0/0" # Replace with your public IP range or '0.0.0.0/0' for open access (not recommended)

SECURITY_GROUP_NAME_PROXYS="${VPC_NAME}-PROXYS"
SECURITY_GROUP_NAME_XMPP="${VPC_NAME}-XMPP"
SECURITY_GROUP_NAME_MYSQL="${VPC_NAME}-MYSQL"
SECURITY_GROUP_NAME_WORDPRESS="${VPC_NAME}-WORDPRESS"

# Create security group PROXYS
SG_ID=$(aws ec2 create-security-group \
  --group-name $SECURITY_GROUP_NAME_PROXYS \
  --description "$DESCRIPTION" \
  --vpc-id $VPC_ID \
  --tag-specifications "ResourceType=security-group,Tags=[{Key=Name,Value=${SECURITY_GROUP_NAME_PROXYS}}]" \
  --query 'GroupId' \
  --output text)
# Add inbound rule to allow SSH
aws ec2 authorize-security-group-ingress \
  --group-id $SG_ID \
  --protocol tcp \
  --port 22 \
  --cidr $MY_IP
# Add inbound rule to allow HTTP
aws ec2 authorize-security-group-ingress \
  --group-id $SG_ID \
  --protocol tcp \
  --port 80 \
  --cidr $MY_IP
# Add inbound rule to allow HTTPS
aws ec2 authorize-security-group-ingress \
  --group-id $SG_ID \
  --protocol tcp \
  --port 443 \
  --cidr $MY_IP






# Create security group XMPP
SG_ID=$(aws ec2 create-security-group \
  --group-name $SECURITY_GROUP_NAME_XMPP \
  --description "$DESCRIPTION" \
  --vpc-id $VPC_ID \
  --tag-specifications "ResourceType=security-group,Tags=[{Key=Name,Value=${SECURITY_GROUP_NAME_XMPP}}]" \
  --query 'GroupId' \
  --output text)
# Add inbound rule to allow SSH
aws ec2 authorize-security-group-ingress \
  --group-id $SG_ID \
  --protocol tcp \
  --port 22 \
  --cidr $MY_IP
# Add inbound rule to allow 5222
aws ec2 authorize-security-group-ingress \
  --group-id $SG_ID \
  --protocol tcp \
  --port 5222 \
  --cidr $MY_IP
# Add inbound rule to allow 5269
aws ec2 authorize-security-group-ingress \
  --group-id $SG_ID \
  --protocol tcp \
  --port 5269 \
  --cidr $MY_IP
# Add inbound rule to allow MYSQL
aws ec2 authorize-security-group-ingress \
  --group-id $SG_ID \
  --protocol tcp \
  --port 3306 \
  --cidr $MY_IP








# Create security group MYSQL
SG_ID=$(aws ec2 create-security-group \
  --group-name $SECURITY_GROUP_NAME_MYSQL \
  --description "$DESCRIPTION" \
  --vpc-id $VPC_ID \
  --tag-specifications "ResourceType=security-group,Tags=[{Key=Name,Value=${SECURITY_GROUP_NAME_MYSQL}}]" \
  --query 'GroupId' \
  --output text)
# Add inbound rule to allow SSH
aws ec2 authorize-security-group-ingress \
  --group-id $SG_ID \
  --protocol tcp \
  --port 22 \
  --cidr $MY_IP
# Add inbound rule to allow MYSQL
aws ec2 authorize-security-group-ingress \
  --group-id $SG_ID \
  --protocol tcp \
  --port 3306 \
  --cidr $MY_IP







# Create security group WORDPRESS
SG_ID=$(aws ec2 create-security-group \
  --group-name $SECURITY_GROUP_NAME_WORDPRESS \
  --description "$DESCRIPTION" \
  --vpc-id $VPC_ID \
  --tag-specifications "ResourceType=security-group,Tags=[{Key=Name,Value=${SECURITY_GROUP_NAME_WORDPRESS}}]" \
  --query 'GroupId' \
  --output text)
# Add inbound rule to allow SSH
aws ec2 authorize-security-group-ingress \
  --group-id $SG_ID \
  --protocol tcp \
  --port 22 \
  --cidr $MY_IP
# Add inbound rule to allow HTTP
aws ec2 authorize-security-group-ingress \
  --group-id $SG_ID \
  --protocol tcp \
  --port 80 \
  --cidr $MY_IP
# Add inbound rule to allow HTTPS
aws ec2 authorize-security-group-ingress \
  --group-id $SG_ID \
  --protocol tcp \
  --port 443 \
  --cidr $MY_IP


