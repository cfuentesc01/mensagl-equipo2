#!/bin/bash


# The name of the user for lab
printf "%s" "Insert personal name: "
read ALUMNO
# The name of the user for lab
printf "%s" "Insert email: "
read EMAIL

# DuckDNS variables
printf "%s" "DuckDNS token: "
read DUCKDNS_TOKEN
printf "%s" "DuckDNS domain1: "
read DUCKDNS_SUBDOMAIN
printf "%s" "DuckDNS domain2: "
read DUCKDNS_SUBDOMAIN2


# Key pair SSH
KEY_NAME="ssh-mensagl-2025-${ALUMNO}"
AMI_ID="ami-04b4f1a9cf54c11d0"          # Ubuntu 24.04 AMI ID

# Variables for RDS
RDS_INSTANCE_ID="wordpress-db"
printf "%s" "RDS Wordpress Database: "
read wDBName
printf "%s" "RDS Wordpress Username: "
read DB_USERNAME
printf "%s" "RDS Wordpress Password: "
read DB_PASSWORD


###########################################################################################################
###########################                      V P C                          ###########################
###########################################################################################################
export EDITOR=true

# VPC Variables
VPC_NAME="vpc-mensagl-2025-${ALUMNO}"
REGION="us-east-1"
AVAILABILITY_ZONE1="${REGION}a"
AVAILABILITY_ZONE2="${REGION}b"
DESCRIPTION="Mensagl Security group"
MY_IP="0.0.0.0/0" # Replace with your public IP range or '0.0.0.0/0' for open access

# Create VPC and capture its ID
VPC_ID=$(aws ec2 create-vpc --cidr-block "10.0.0.0/16" --instance-tenancy "default" --tag-specifications "ResourceType=vpc,Tags=[{Key=Name,Value=${VPC_NAME}-vpc}]" --query 'Vpc.VpcId' --output text)
aws ec2 modify-vpc-attribute --vpc-id $VPC_ID --enable-dns-hostnames

# Create subnets (Public and Private)
# Public Subnet 1
SUBNET_PUBLIC1=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block "10.0.1.0/24" --availability-zone $AVAILABILITY_ZONE1 --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=${VPC_NAME}-subnet-public1-${AVAILABILITY_ZONE1}}]" --query 'Subnet.SubnetId' --output text)
aws ec2 modify-subnet-attribute --subnet-id $SUBNET_PUBLIC1 --map-public-ip-on-launch

# Public Subnet 2
SUBNET_PUBLIC2=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block "10.0.2.0/24" --availability-zone $AVAILABILITY_ZONE2 --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=${VPC_NAME}-subnet-public2-${AVAILABILITY_ZONE2}}]" --query 'Subnet.SubnetId' --output text)
aws ec2 modify-subnet-attribute --subnet-id $SUBNET_PUBLIC2 --map-public-ip-on-launch

# Private Subnet 1
SUBNET_PRIVATE1=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block "10.0.3.0/24" --availability-zone $AVAILABILITY_ZONE1 --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=${VPC_NAME}-subnet-private1-${AVAILABILITY_ZONE1}}]" --query 'Subnet.SubnetId' --output text)

# Private Subnet 2
SUBNET_PRIVATE2=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block "10.0.4.0/24" --availability-zone $AVAILABILITY_ZONE2 --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=${VPC_NAME}-subnet-private2-${AVAILABILITY_ZONE2}}]" --query 'Subnet.SubnetId' --output text)

# Create Internet Gateway and attach to the VPC
IGW_ID=$(aws ec2 create-internet-gateway --tag-specifications "ResourceType=internet-gateway,Tags=[{Key=Name,Value=${VPC_NAME}-igw}]" --query 'InternetGateway.InternetGatewayId' --output text)
aws ec2 attach-internet-gateway --internet-gateway-id $IGW_ID --vpc-id $VPC_ID

# Create public route table and associate public subnets
RTB_PUBLIC=$(aws ec2 create-route-table --vpc-id $VPC_ID --tag-specifications "ResourceType=route-table,Tags=[{Key=Name,Value=${VPC_NAME}-rtb-public}]" --query 'RouteTable.RouteTableId' --output text)
aws ec2 create-route --route-table-id $RTB_PUBLIC --destination-cidr-block "0.0.0.0/0" --gateway-id $IGW_ID
aws ec2 associate-route-table --route-table-id $RTB_PUBLIC --subnet-id $SUBNET_PUBLIC1
aws ec2 associate-route-table --route-table-id $RTB_PUBLIC --subnet-id $SUBNET_PUBLIC2

# Create Elastic IP and NAT Gateway (Only ONE NAT in AZ1)
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


# Final verification (optional)
#aws ec2 describe-vpcs --vpc-ids $VPC_ID
#aws ec2 describe-nat-gateways --nat-gateway-ids $NATGW_ID
#aws ec2 describe-route-tables --route-table-ids $RTB_PRIVATE1 $RTB_PRIVATE2

echo "VPC Created !"




###########################################################################################################
########################                    SECURITY GROUPS                        ########################
###########################################################################################################


# Create security group PROXYS
SG_ID_PROXY=$(aws ec2 create-security-group \
  --group-name "Proxy-inverso" \
  --description "$DESCRIPTION" \
  --vpc-id $VPC_ID \
  --tag-specifications "ResourceType=security-group,Tags=[{Key=Name,Value="Proxy-inverso"}]" \
  --query 'GroupId' \
  --output text)
# Add inbound rule to allow SSH
aws ec2 authorize-security-group-ingress \
  --group-id $SG_ID_PROXY \
  --protocol tcp \
  --port 22 \
  --cidr $MY_IP
# Add inbound rule to allow HTTP
aws ec2 authorize-security-group-ingress \
  --group-id $SG_ID_PROXY \
  --protocol tcp \
  --port 80 \
  --cidr $MY_IP
# Add inbound rule to allow HTTPS
aws ec2 authorize-security-group-ingress \
  --group-id $SG_ID_PROXY \
  --protocol tcp \
  --port 443 \
  --cidr $MY_IP



# Create security group XMPP
SG_ID_XMPP=$(aws ec2 create-security-group \
  --group-name "Servidor-Mensajeria" \
  --description "$DESCRIPTION" \
  --vpc-id $VPC_ID \
  --tag-specifications "ResourceType=security-group,Tags=[{Key=Name,Value="Servidor-Mensajeria"}]" \
  --query 'GroupId' \
  --output text)
# Add inbound rule to allow 10000
aws ec2 authorize-security-group-ingress \
  --group-id $SG_ID_XMPP \
  --protocol tcp \
  --port 1000 \
  --cidr $MY_IP
# Add inbound rule to allow 5269
aws ec2 authorize-security-group-ingress \
  --group-id $SG_ID_XMPP \
  --protocol tcp \
  --port 5269 \
  --cidr $MY_IP
# Add inbound rule to allow 4443
aws ec2 authorize-security-group-ingress \
  --group-id $SG_ID_XMPP \
  --protocol tcp \
  --port 4443 \
  --cidr $MY_IP
# Add inbound rule to allow 5281
aws ec2 authorize-security-group-ingress \
  --group-id $SG_ID_XMPP \
  --protocol tcp \
  --port 5281 \
  --cidr $MY_IP
# Add inbound rule to allow 5280
aws ec2 authorize-security-group-ingress \
  --group-id $SG_ID_XMPP \
  --protocol tcp \
  --port 5280 \
  --cidr $MY_IP
# Add inbound rule to allow 5347
aws ec2 authorize-security-group-ingress \
  --group-id $SG_ID_XMPP \
  --protocol tcp \
  --port 5347 \
  --cidr $MY_IP
# Add inbound rule to allow 5222
aws ec2 authorize-security-group-ingress \
  --group-id $SG_ID_XMPP \
  --protocol tcp \
  --port 5222 \
  --cidr $MY_IP
# Add inbound rule to allow HTTP
aws ec2 authorize-security-group-ingress \
  --group-id $SG_ID_XMPP \
  --protocol tcp \
  --port 80 \
  --cidr $MY_IP
# Add inbound rule to allow HTTPS
aws ec2 authorize-security-group-ingress \
  --group-id $SG_ID_XMPP \
  --protocol tcp \
  --port 443 \
  --cidr $MY_IP
# Add inbound rule to allow SSH
aws ec2 authorize-security-group-ingress \
  --group-id $SG_ID_XMPP \
  --protocol tcp \
  --port 1000 \
  --cidr $MY_IP
# Add inbound rule to allow 12345
aws ec2 authorize-security-group-ingress \
  --group-id $SG_ID_XMPP \
  --protocol tcp \
  --port 12345 \
  --cidr $MY_IP
# Add inbound rule to allow MYSQL
aws ec2 authorize-security-group-ingress \
  --group-id $SG_ID_XMPP \
  --protocol tcp \
  --port 3306 \
  --cidr $MY_IP
aws ec2 authorize-security-group-ingress \
  --group-id $SG_ID_XMPP \
  --protocol -1 \
  --source-group $SG_ID_PROXY





# Create security group MYSQL
SG_ID_MYSQL=$(aws ec2 create-security-group \
  --group-name "Servidor-SGBD" \
  --description "$DESCRIPTION" \
  --vpc-id $VPC_ID \
  --tag-specifications "ResourceType=security-group,Tags=[{Key=Name,Value="Servidor-SGBD"}]" \
  --query 'GroupId' \
  --output text)
# Add inbound rule to allow SSH
aws ec2 authorize-security-group-ingress \
  --group-id $SG_ID_MYSQL \
  --protocol tcp \
  --port 22 \
  --cidr $MY_IP
# Add inbound rule to allow MYSQL
aws ec2 authorize-security-group-ingress \
  --group-id $SG_ID_MYSQL \
  --protocol tcp \
  --port 3306 \
  --cidr $MY_IP







# Create security group WORDPRESS
SG_ID_WORDPRESS=$(aws ec2 create-security-group \
  --group-name "Servidor-ticketing" \
  --description "$DESCRIPTION" \
  --vpc-id $VPC_ID \
  --tag-specifications "ResourceType=security-group,Tags=[{Key=Name,Value="Servidor-ticketing"}]" \
  --query 'GroupId' \
  --output text)
# Add inbound rule to allow SSH
aws ec2 authorize-security-group-ingress \
  --group-id $SG_ID_WORDPRESS \
  --protocol tcp \
  --port 22 \
  --cidr $MY_IP
# Add inbound rule to allow HTTP
aws ec2 authorize-security-group-ingress \
  --group-id $SG_ID_WORDPRESS \
  --protocol tcp \
  --port 80 \
  --cidr $MY_IP
# Add inbound rule to allow HTTPS
aws ec2 authorize-security-group-ingress \
  --group-id $SG_ID_WORDPRESS \
  --protocol tcp \
  --port 443 \
  --cidr $MY_IP


echo "Sec Groups Created !";

###########################################################################################################
#########################                      KEYS SSH                          ##########################
###########################################################################################################

aws ec2 create-key-pair \
  --key-name "${KEY_NAME}" \
  --query "KeyMaterial" \
  --output text > ${KEY_NAME}.pem

echo "SSH KEYS !";

###########################################################################################################
###########################                      E C 2                          ###########################
###########################################################################################################

####### PROXY

# PROXY-1
# ====== Variables ======
INSTANCE_NAME="PROXY-1"                 # Tag: Name of the EC2 instance
SUBNET_ID="${SUBNET_PUBLIC1}"           # Subnet ID
SECURITY_GROUP_ID="${SG_ID_PROXY}"      # Security Group ID
PRIVATE_IP="10.0.1.10"                 # Private IP for the instance

INSTANCE_TYPE="t2.micro"                # EC2 Instance Type
KEY_NAME="${KEY_NAME}"                  # Name of the SSH Key Pair
VOLUME_SIZE=8                           # Size of the root EBS volume (in GB)

USER_DATA_SCRIPT=$(cat <<'EOF'
#!/bin/bash
# Update and install necessary packages
apt-get update -y
apt-get install -y curl certbot

# Set up DuckDNS - Update the DuckDNS IP every 5 minutes
echo "Setting up DuckDNS update script..."
mkdir -p /opt/duckdns
cat <<DUCKDNS_SCRIPT > /opt/duckdns/duckdns.sh
#!/bin/bash
echo "Updating DuckDNS: $DUCKDNS_SUBDOMAIN"
curl -k "https://www.duckdns.org/update?domains=$DUCKDNS_SUBDOMAIN&token=$DUCKDNS_TOKEN&ip=" -o /opt/duckdns/duck.log
DUCKDNS_SCRIPT
chmod +x /opt/duckdns/duckdns.sh
(crontab -l 2>/dev/null; echo "*/5 * * * * /opt/duckdns/duckdns.sh >/dev/null 2>&1") | crontab -

# Update DuckDNS immediately to set the IP
echo "Updating DuckDNS IP..."
/opt/duckdns/duckdns.sh

# Obtain SSL certificate in standalone mode (non-interactive)
echo "Obtaining SSL certificate using certbot..."
certbot certonly --standalone \
  --non-interactive \
  --agree-tos \
  --email $EMAIL \
  -d "$DUCKDNS_SUBDOMAIN.duckdns.org"

apt install nginx -y
# Install and configure NGINX
echo "Installing and configuring NGINX..."
cat <<CONFIG > /etc/nginx/sites-available/proxy_site
upstream backend_meets {
    server 10.0.3.100:443;
    server 10.0.3.200:443;
}

upstream backend_xmpp {
    server 10.0.3.100:12345;
    server 10.0.3.200:12345;
}

server {
    listen 80;
    server_name $DUCKDNS_SUBDOMAIN.duckdns.org;

    location /.well-known/acme-challenge/ {
        root /var/www/html;
    }

    location / {
        return 403;
    }

    location /llamadas {
        return 301 https://\$host\$request_uri;
    }

    location /xmpp {
        return 301 https://\$host\$request_uri;
    }
}

server {
    listen 443 ssl;
    server_name $DUCKDNS_SUBDOMAIN.duckdns.org;

    ssl_certificate /etc/letsencrypt/live/$DUCKDNS_SUBDOMAIN.duckdns.org/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DUCKDNS_SUBDOMAIN.duckdns.org/privkey.pem;

    # Redirect root (/) to /llamadas
    location / {
        return 301 https://\$host/llamadas;
    }

    # Strip /llamadas before sending to Jitsi
    location /llamadas/ {
        rewrite ^/llamadas(/.*)\$ \$1 break;
        proxy_pass https://backend_meets;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    # Allow Jitsi static files (CSS, JS, images)
    location /libs/ {
        proxy_pass https://backend_meets;
        proxy_set_header Host \$host;
    }

    location /css/ {
        proxy_pass https://backend_meets;
        proxy_set_header Host \$host;
    }

    location /static/ {
        proxy_pass https://backend_meets;
        proxy_set_header Host \$host;
    }

    location /images/ {
        proxy_pass https://backend_meets;
        proxy_set_header Host \$host;
    }

    location /sounds/ {
        proxy_pass https://backend_meets;
        proxy_set_header Host \$host;
    }

    location /xmpp {
        proxy_pass http://backend_xmpp;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
CONFIG
ln -s /etc/nginx/sites-available/proxy_site /etc/nginx/sites-enabled/
rm /etc/nginx/sites-enabled/default
systemctl restart nginx
systemctl enable nginx
echo "NGINX installed and configured!"

EOF
)

# ====== Create EC2 Instance ======
INSTANCE_ID=$(aws ec2 run-instances \
    --image-id "$AMI_ID" \
    --instance-type "$INSTANCE_TYPE" \
    --key-name "$KEY_NAME" \
    --block-device-mappings "DeviceName=/dev/sda1,Ebs={VolumeSize=$VOLUME_SIZE,VolumeType=gp3,DeleteOnTermination=true}" \
    --network-interfaces "SubnetId=$SUBNET_ID,AssociatePublicIpAddress=true,DeviceIndex=0,PrivateIpAddresses=[{Primary=true,PrivateIpAddress=$PRIVATE_IP}],Groups=[$SECURITY_GROUP_ID]" \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$INSTANCE_NAME}]" \
    --user-data "$(echo "$USER_DATA_SCRIPT" | sed "s/\$DUCKDNS_TOKEN/$DUCKDNS_TOKEN/g" | sed "s/\$EMAIL/$EMAIL/g" | sed "s/\$DUCKDNS_SUBDOMAIN/$DUCKDNS_SUBDOMAIN/g")" \
    --query "Instances[0].InstanceId" \
    --output text)

echo "${INSTANCE_NAME} created"







# PROXY-2
# ====== Variables ======
INSTANCE_NAME="PROXY-2"                 # Tag: Name of the EC2 instance
SUBNET_ID="${SUBNET_PUBLIC2}"           # Subnet ID
SECURITY_GROUP_ID="${SG_ID_PROXY}"  # Security Group ID
PRIVATE_IP="10.0.2.10"                # Private IP for the instance

INSTANCE_TYPE="t2.micro"                # EC2 Instance Type
KEY_NAME="${KEY_NAME}"                  # Name of the SSH Key Pair
VOLUME_SIZE=8                           # Size of the root EBS volume (in GB)
USER_DATA_SCRIPT=$(cat <<'EOF'
#!/bin/bash
apt-get update -y
PUBLIC_IP=$(curl https://ipinfo.io/ip)
curl -s https://www.duckdns.org/update?domains=$DUCKDNS_SUBDOMAIN2&token=$DUCKDNS_TOKEN&ip=$PUBLIC_IP&verbose=true&clear=true
sleep 30
sudo apt install -y certbot
# Obtain SSL certificate in standalone mode (non-interactive)
sudo certbot certonly --standalone \
  --non-interactive \
  --agree-tos \
  --email $EMAIL \
  -d "$DUCKDNS_SUBDOMAIN2.duckdns.org"
sudo chmod 755 /etc/letsencrypt/archive/
sudo chmod 755 /etc/letsencrypt/archive/${DUCKDNS_SUBDOMAIN2}.duckdns.org/
sudo chmod 755 /etc/letsencrypt/live/
sudo chmod 755 /etc/letsencrypt/live/${DUCKDNS_SUBDOMAIN2}.duckdns.org/


apt-get install nginx -y
cat <<CONFIG > /etc/nginx/sites-available/proxy_site
upstream backend_servers {
        server 10.0.4.100:443;
        server 10.0.4.200:443;
}

server {
        listen 80;
        server_name 10.0.2.10;

        location / {
                proxy_pass http://backend_servers;
                proxy_set_header Host \$host;
                proxy_set_header X-Real-IP \$remote_addr;
                proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
                proxy_set_header X-Forwarded-Proto \$scheme;
        }
}
CONFIG
ln -s /etc/nginx/sites-available/proxy_site /etc/nginx/sites-enabled/
rm /etc/nginx/sites-enabled/default
systemctl restart nginx
systemctl enable nginx

mkdir -p /opt/duckdns
cd /opt/duckdns

cat <<'DUCKDNS_SCRIPT' > duckdns.sh
#!/bin/bash
echo url="https://www.duckdns.org/update?domains=$DUCKDNS_SUBDOMAIN2&token=$DUCKDNS_TOKEN&ip=" | curl -k -o /opt/duckdns/duck.log -K -
DUCKDNS_SCRIPT
chmod +x duckdns.sh
(crontab -l 2>/dev/null; echo "*/5 * * * * /opt/duckdns/duckdns.sh >/dev/null 2>&1") | crontab -
echo "DDNS installed !"
EOF
)


# ====== Create EC2 Instance ======
INSTANCE_ID=$(aws ec2 run-instances \
    --image-id "$AMI_ID" \
    --instance-type "$INSTANCE_TYPE" \
    --key-name "$KEY_NAME" \
    --block-device-mappings "DeviceName=/dev/sda1,Ebs={VolumeSize=$VOLUME_SIZE,VolumeType=gp3,DeleteOnTermination=true}" \
    --network-interfaces "SubnetId=$SUBNET_ID,AssociatePublicIpAddress=true,DeviceIndex=0,PrivateIpAddresses=[{Primary=true,PrivateIpAddress=$PRIVATE_IP}],Groups=[$SECURITY_GROUP_ID]" \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$INSTANCE_NAME}]" \
    --user-data "$(echo "$USER_DATA_SCRIPT" | sed "s/\$DUCKDNS_TOKEN/$DUCKDNS_TOKEN/g" | sed "s/\$EMAIL/$EMAIL/g" )"
    --query "Instances[0].InstanceId" \
    --output text)
echo "${INSTANCE_NAME} created";











####### MySQL

# MYSQL-1
# ====== Variables ======
INSTANCE_NAME="MYSQL-1"                 # Tag: Name of the EC2 instance
SUBNET_ID="${SUBNET_PRIVATE1}"           # Subnet ID
SECURITY_GROUP_ID="${SG_ID_MYSQL}"  # Security Group ID
PRIVATE_IP="10.0.3.10"                # Private IP for the instance

INSTANCE_TYPE="t2.micro"                # EC2 Instance Type
KEY_NAME="${KEY_NAME}"                  # Name of the SSH Key Pair
VOLUME_SIZE=8                           # Size of the root EBS volume (in GB)
USER_DATA_SCRIPT=$(cat <<'EOF'
#!/bin/bash
set -e
apt-get update -y
apt-get install mysql-server mysql-client -y
systemctl start mysql
systemctl enable mysql
mysql -e "CREATE DATABASE wordpress;"
mysql -e "CREATE USER 'cowboy_del_infierno'@'%' IDENTIFIED BY '_Admin123';"
mysql -e "GRANT ALL PRIVILEGES ON wordpress.* TO 'cowboy_del_infierno'@'%';"
mysql -e "FLUSH PRIVILEGES;"
sed -i "s/^bind-address\s*=.*/bind-address = 0.0.0.0/" /etc/mysql/mysql.conf.d/mysqld.cnf
sed -i "s/^mysqlx-bind-address\s*=.*/mysqlx-bind-address = 127.0.0.1/" /etc/mysql/mysql.conf.d/mysqld.cnf
echo "MySQL DB WORDPRESS !!"
EOF
)

# ====== Create EC2 Instance ======
INSTANCE_ID=$(aws ec2 run-instances \
    --image-id "$AMI_ID" \
    --instance-type "$INSTANCE_TYPE" \
    --key-name "$KEY_NAME" \
    --block-device-mappings "DeviceName=/dev/sda1,Ebs={VolumeSize=$VOLUME_SIZE,VolumeType=gp3,DeleteOnTermination=true}" \
    --network-interfaces "SubnetId=$SUBNET_ID,AssociatePublicIpAddress=true,DeviceIndex=0,PrivateIpAddresses=[{Primary=true,PrivateIpAddress=$PRIVATE_IP}],Groups=[$SECURITY_GROUP_ID]" \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$INSTANCE_NAME}]" \
    --user-data "$USER_DATA_SCRIPT" \
    --query "Instances[0].InstanceId" \
    --output text)
echo "${INSTANCE_NAME} created";



####### MySQL

# MYSQL-2
# ====== Variables ======
INSTANCE_NAME="MYSQL-2"                 # Tag: Name of the EC2 instance
SUBNET_ID="${SUBNET_PRIVATE1}"           # Subnet ID
SECURITY_GROUP_ID="${SG_ID_MYSQL}"  # Security Group ID
PRIVATE_IP="10.0.3.20"                # Private IP for the instance

INSTANCE_TYPE="t2.micro"                # EC2 Instance Type
KEY_NAME="${KEY_NAME}"                  # Name of the SSH Key Pair
VOLUME_SIZE=8                           # Size of the root EBS volume (in GB)
USER_DATA_SCRIPT=$(cat <<'EOF'
#!/bin/bash
echo "MySQL DB WORDPRESS !!"
EOF
)

# ====== Create EC2 Instance ======
INSTANCE_ID=$(aws ec2 run-instances \
    --image-id "$AMI_ID" \
    --instance-type "$INSTANCE_TYPE" \
    --key-name "$KEY_NAME" \
    --block-device-mappings "DeviceName=/dev/sda1,Ebs={VolumeSize=$VOLUME_SIZE,VolumeType=gp3,DeleteOnTermination=true}" \
    --network-interfaces "SubnetId=$SUBNET_ID,AssociatePublicIpAddress=true,DeviceIndex=0,PrivateIpAddresses=[{Primary=true,PrivateIpAddress=$PRIVATE_IP}],Groups=[$SECURITY_GROUP_ID]" \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$INSTANCE_NAME}]" \
    --user-data "$USER_DATA_SCRIPT" \
    --query "Instances[0].InstanceId" \
    --output text)
echo "${INSTANCE_NAME} created";







#aws rds delete-db-instance \
#    --db-instance-identifier "wordpress-db" \
#    --skip-final-snapshot \
#    --region "us-east-1"
#aws rds describe-db-instances --db-instance-identifier "wordpress-db"
#aws rds delete-db-subnet-group --db-subnet-group-name wp-rds-subnet-group
#aws rds describe-db-subnet-groups --db-subnet-group-name wp-rds-subnet-group




########################################################################
###################### ADD RDS MYSQL INSTANCE BELOW ####################
########################################################################


# Create RDS Subnet Group (Requires at Least 2 AZs)
aws rds create-db-subnet-group \
    --db-subnet-group-name wp-rds-subnet-group \
    --db-subnet-group-description "RDS Subnet Group for WordPress" \
    --subnet-ids "$SUBNET_PRIVATE1" "$SUBNET_PRIVATE2"

# Create Security Group for RDS
SG_ID_RDS=$(aws ec2 create-security-group \
  --group-name "RDS-MySQL" \
  --description "Security group for RDS MySQL" \
  --vpc-id "$VPC_ID" \
  --query 'GroupId' \
  --output text)

# Allow MySQL access (replace with actual security group or IP CIDR)
aws ec2 authorize-security-group-ingress \
  --group-id "$SG_ID_RDS" \
  --protocol tcp \
  --port 3306 \
  --cidr 0.0.0.0/0  # Replace with actual WordPress server CIDR

# Create RDS Instance (Single-AZ in Private Subnet 2)
aws rds create-db-instance \
    --db-instance-identifier "$RDS_INSTANCE_ID" \
    --db-instance-class db.t3.micro \
    --engine mysql \
    --allocated-storage 20 \
    --storage-type gp2 \
    --master-username "$DB_USERNAME" \
    --master-user-password "$DB_PASSWORD" \
    --db-subnet-group-name wp-rds-subnet-group \
    --vpc-security-group-ids "$SG_ID_RDS" \
    --backup-retention-period 7 \
    --no-publicly-accessible \
    --region "$REGION" \
    --availability-zone "$AVAILABILITY_ZONE1" \
    --no-multi-az  # Ensures Single-AZ deployment

# Wait for RDS to be available
echo "Waiting for RDS to become available (may take ~10 minutes)..."
aws rds wait db-instance-available --db-instance-identifier "$RDS_INSTANCE_ID"

# Retrieve RDS endpoint
RDS_ENDPOINT=$(aws rds describe-db-instances \
    --db-instance-identifier "$RDS_INSTANCE_ID" \
    --query 'DBInstances[0].Endpoint.Address' \
    --output text)
echo "RDS Endpoint: $RDS_ENDPOINT"











####### XMPP

# XMPP-1
# ====== Variables ======
INSTANCE_NAME="XMPP-1"                 # Tag: Name of the EC2 instance
SUBNET_ID="${SUBNET_PRIVATE1}"           # Subnet ID
SECURITY_GROUP_ID="${SG_ID_XMPP}"  # Security Group ID
PRIVATE_IP="10.0.3.100"                # Private IP for the instance

INSTANCE_TYPE="t2.micro"                # EC2 Instance Type
KEY_NAME="${KEY_NAME}"                  # Name of the SSH Key Pair
VOLUME_SIZE=8                           # Size of the root EBS volume (in GB)


# ====== Create EC2 Instance ======
INSTANCE_ID=$(aws ec2 run-instances \
    --image-id "$AMI_ID" \
    --instance-type "$INSTANCE_TYPE" \
    --key-name "$KEY_NAME" \
    --block-device-mappings "DeviceName=/dev/sda1,Ebs={VolumeSize=$VOLUME_SIZE,VolumeType=gp3,DeleteOnTermination=true}" \
    --network-interfaces "SubnetId=$SUBNET_ID,AssociatePublicIpAddress=true,DeviceIndex=0,PrivateIpAddresses=[{Primary=true,PrivateIpAddress=$PRIVATE_IP}],Groups=[$SECURITY_GROUP_ID]" \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$INSTANCE_NAME}]" \
    --query "Instances[0].InstanceId" \
    --output text)
echo "${INSTANCE_NAME} created";



# XMPP-2
# ====== Variables ======
INSTANCE_NAME="XMPP-2"                 # Tag: Name of the EC2 instance
SUBNET_ID="${SUBNET_PRIVATE1}"           # Subnet ID
SECURITY_GROUP_ID="${SG_ID_XMPP}"  # Security Group ID
PRIVATE_IP="10.0.3.200"                # Private IP for the instance

INSTANCE_TYPE="t2.micro"                # EC2 Instance Type
KEY_NAME="${KEY_NAME}"                  # Name of the SSH Key Pair
VOLUME_SIZE=8                           # Size of the root EBS volume (in GB)


# ====== Create EC2 Instance ======
INSTANCE_ID=$(aws ec2 run-instances \
    --image-id "$AMI_ID" \
    --instance-type "$INSTANCE_TYPE" \
    --key-name "$KEY_NAME" \
    --block-device-mappings "DeviceName=/dev/sda1,Ebs={VolumeSize=$VOLUME_SIZE,VolumeType=gp3,DeleteOnTermination=true}" \
    --network-interfaces "SubnetId=$SUBNET_ID,AssociatePublicIpAddress=true,DeviceIndex=0,PrivateIpAddresses=[{Primary=true,PrivateIpAddress=$PRIVATE_IP}],Groups=[$SECURITY_GROUP_ID]" \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$INSTANCE_NAME}]" \
    --query "Instances[0].InstanceId" \
    --output text)
echo "${INSTANCE_NAME} created";





















####### WORDPRESS

# WORDPRESS-1
# ====== Variables ======
INSTANCE_NAME="WORDPRESS-1"                 # Tag: Name of the EC2 instance
SUBNET_ID="${SUBNET_PRIVATE2}"           # Subnet ID
SECURITY_GROUP_ID="${SG_ID_WORDPRESS}"  # Security Group ID
PRIVATE_IP="10.0.4.100"                # Private IP for the instance

INSTANCE_TYPE="t2.micro"                # EC2 Instance Type
KEY_NAME="${KEY_NAME}"                  # Name of the SSH Key Pair
VOLUME_SIZE=8                           # Size of the root EBS volume (in GB)
USER_DATA_SCRIPT=$(cat <<'EOF'
#!/bin/bash
set -e
sudo apt update
sudo apt install apache2 mysql-client mysql-server php php-mysql -y
curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
chmod +x wp-cli.phar
sudo mv wp-cli.phar /usr/local/bin/wp
sudo rm -rf /var/www/html/*
sudo chmod -R 755 /var/www/html
sudo chown -R ubuntu:ubuntu /var/www/html
# MySQL credentials
MYSQL_CMD="mysql -h ${RDS_ENDPOINT} -u ${DB_USERNAME} -p${DB_PASSWORD}"
$MYSQL_CMD <<EOF2
CREATE DATABASE IF NOT EXISTS ${wDBName};
CREATE USER IF NOT EXISTS '${DB_USERNAME}'@'%' IDENTIFIED BY '${DB_PASSWORD}';
GRANT ALL PRIVILEGES ON ${wDBName}.* TO '${DB_USERNAME}'@'%';
FLUSH PRIVILEGES;
EOF2
sudo -u ubuntu -k -- wp core download --path=/var/www/html
sudo -u ubuntu -k -- wp core config --dbname=${wDBName} --dbuser=${DB_USERNAME} --dbpass=${DB_PASSWORD} --dbhost=${RDS_ENDPOINT} --dbprefix=wp_ --path=/var/www/html
sudo -u ubuntu -k -- wp core install --url=10.0.4.100  --title=Site_Title --admin_user=${DB_USERNAME} --admin_password=${DB_PASSWORD} --admin_email=${EMAIL} --path=/var/www/html
#sudo -u ubuntu -k -- wp option update home 'http://10.0.4.100' --path=/var/www/html
#sudo -u ubuntu -k -- wp option update siteurl 'http://0.0.4.100' --path=/var/www/html
sudo -u ubuntu -k -- wp plugin install supportcandy --activate --path=/var/www/html
echo "Wordpress mounted !!"
EOF
)

# ====== Create EC2 Instance ======
INSTANCE_ID=$(aws ec2 run-instances \
    --image-id "$AMI_ID" \
    --instance-type "$INSTANCE_TYPE" \
    --key-name "$KEY_NAME" \
    --block-device-mappings "DeviceName=/dev/sda1,Ebs={VolumeSize=$VOLUME_SIZE,VolumeType=gp3,DeleteOnTermination=true}" \
    --network-interfaces "SubnetId=$SUBNET_ID,AssociatePublicIpAddress=true,DeviceIndex=0,PrivateIpAddresses=[{Primary=true,PrivateIpAddress=$PRIVATE_IP}],Groups=[$SECURITY_GROUP_ID]" \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$INSTANCE_NAME}]" \
    --query "Instances[0].InstanceId" \
    --user-data "$USER_DATA_SCRIPT" \
    --output text)
echo "${INSTANCE_NAME} created";








# WORDPRESS-2
# ====== Variables ======
INSTANCE_NAME="WORDPRESS-2"                 # Tag: Name of the EC2 instance
SUBNET_ID="${SUBNET_PRIVATE2}"           # Subnet ID
SECURITY_GROUP_ID="${SG_ID_WORDPRESS}"  # Security Group ID
PRIVATE_IP="10.0.4.200"                # Private IP for the instance

INSTANCE_TYPE="t2.micro"                # EC2 Instance Type
KEY_NAME="${KEY_NAME}"                  # Name of the SSH Key Pair
VOLUME_SIZE=8                           # Size of the root EBS volume (in GB)
USER_DATA_SCRIPT=$(cat <<'EOF'
#!/bin/bash
set -e
sudo apt update
sudo apt install apache2 mysql-client mysql-server php php-mysql -y
curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
chmod +x wp-cli.phar
sudo mv wp-cli.phar /usr/local/bin/wp
sudo rm -rf /var/www/html/*
sudo chmod -R 755 /var/www/html
sudo chown -R ubuntu:ubuntu /var/www/html
# MySQL credentials
MYSQL_CMD="mysql -h ${RDS_ENDPOINT} -u ${DB_USERNAME} -p${DB_PASSWORD}"
$MYSQL_CMD <<EOF2
CREATE DATABASE IF NOT EXISTS ${wDBName};
CREATE USER IF NOT EXISTS '${DB_USERNAME}'@'%' IDENTIFIED BY '${DB_PASSWORD}';
GRANT ALL PRIVILEGES ON ${wDBName}.* TO '${DB_USERNAME}'@'%';
FLUSH PRIVILEGES;
EOF2
sudo -u ubuntu -k -- wp core download --path=/var/www/html
sudo -u ubuntu -k -- wp core config --dbname=${wDBName} --dbuser=${DB_USERNAME} --dbpass=${DB_PASSWORD} --dbhost=${RDS_ENDPOINT} --dbprefix=wp_ --path=/var/www/html
sudo -u ubuntu -k -- wp core install --url=10.0.4.200  --title=Site_Title --admin_user=${DB_USERNAME} --admin_password=${DB_PASSWORD} --admin_email=${EMAIL} --path=/var/www/html
#sudo -u ubuntu -k -- wp option update home 'http://10.0.4.200' --path=/var/www/html
#sudo -u ubuntu -k -- wp option update siteurl 'http://0.0.4.200' --path=/var/www/html
sudo -u ubuntu -k -- wp plugin install supportcandy --activate --path=/var/www/html
echo "Wordpress mounted !!"
EOF
)

# ====== Create EC2 Instance ======
INSTANCE_ID=$(aws ec2 run-instances \
    --image-id "$AMI_ID" \
    --instance-type "$INSTANCE_TYPE" \
    --key-name "$KEY_NAME" \
    --block-device-mappings "DeviceName=/dev/sda1,Ebs={VolumeSize=$VOLUME_SIZE,VolumeType=gp3,DeleteOnTermination=true}" \
    --network-interfaces "SubnetId=$SUBNET_ID,AssociatePublicIpAddress=true,DeviceIndex=0,PrivateIpAddresses=[{Primary=true,PrivateIpAddress=$PRIVATE_IP}],Groups=[$SECURITY_GROUP_ID]" \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$INSTANCE_NAME}]" \
    --query "Instances[0].InstanceId" \
    --user-data "$USER_DATA_SCRIPT" \
    --output text)
echo "${INSTANCE_NAME} created";
