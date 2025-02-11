#!/bin/bash

export DUCKDNS_TOKEN="${DUCKDNS_TOKEN}"
export DUCKDNS_SUBDOMAIN="${DUCKDNS_SUBDOMAIN}"
export EMAIL="${EMAIL}"
export host="${host}"
export request_uri="${request_uri}"

# Update and install necessary packages
sudo apt update && sudo  DEBIAN_FRONTEND=noninteractive apt install nginx-full python3-pip -y
sudo snap install --classic certbot
sudo ln -s /snap/bin/certbot /usr/bin/certbot
pip install certbot-dns-duckdns
snap install certbot-dns-duckdns
sudo snap set certbot trust-plugin-with-root=ok
sudo snap connect certbot:plugin certbot-dns-duckdns


# Set up DuckDNS - Update the DuckDNS IP every 5 minutes
echo "Setting up DuckDNS update script..."
mkdir -p /opt/duckdns
cat <<DUCKDNS_SCRIPT > /opt/duckdns/duckdns.sh
#!/bin/bash
echo "Updating DuckDNS: ${DUCKDNS_SUBDOMAIN}"
curl -k "https://www.duckdns.org/update?domains=${DUCKDNS_SUBDOMAIN}&token=${DUCKDNS_TOKEN}&ip=" -o /opt/duckdns/duck.log
DUCKDNS_SCRIPT
chmod +x /opt/duckdns/duckdns.sh
(crontab -l 2>/dev/null; echo "*/5 * * * * /opt/duckdns/duckdns.sh >/dev/null 2>&1") | crontab -

# Update DuckDNS immediately to set the IP
echo "Updating DuckDNS IP..."
/opt/duckdns/duckdns.sh

sleep 30
# Obtain SSL certificate in standalone mode (non-interactive)
echo "Obtaining SSL certificate using certbot..."
certbot certonly --non-interactive \
 --agree-tos \
 --email "${EMAIL}" \
 --preferred-challenges dns \
 --authenticator dns-duckdns \
 --dns-duckdns-token "${DUCKDNS_TOKEN}" \
 --dns-duckdns-propagation-seconds 60 \
 -d "${DUCKDNS_SUBDOMAIN}.duckdns.org" \
 -d "*.${DUCKDNS_SUBDOMAIN}.duckdns.org"

certbot certonly --non-interactive \
 --agree-tos \
 --email "${EMAIL}" \
 --preferred-challenges dns \
 --authenticator dns-duckdns \
 --dns-duckdns-token "${DUCKDNS_TOKEN}" \
 --dns-duckdns-propagation-seconds 120 \
 -d "${DUCKDNS_SUBDOMAIN}.duckdns.org" \
 -d "*.${DUCKDNS_SUBDOMAIN}.duckdns.org"



# Install and configure NGINX
echo "Installing and configuring NGINX..."

cat <<EOF > /etc/nginx/sites-available/proxy_site
upstream backend_meets {
    server 10.0.3.100:443;
    server 10.0.3.200:443;
#    server 10.0.3.150:443;
}

upstream backend_xmpp {
    server 10.0.3.100:12345;
    server 10.0.3.200:12345;
}
server {
    listen 80;
    server_name ${DUCKDNS_SUBDOMAIN}.duckdns.org upload.${DUCKDNS_SUBDOMAIN}.duckdns.org;

    location /.well-known/acme-challenge/ {
        root /var/www/html;
    }

    location / {
        return 301 https://\$host\$request_uri;
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
    server_name ${DUCKDNS_SUBDOMAIN}.duckdns.org;

    ssl_certificate /etc/letsencrypt/live/${DUCKDNS_SUBDOMAIN}.duckdns.org/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${DUCKDNS_SUBDOMAIN}.duckdns.org/privkey.pem;

    # Redirect root (/) to /llamadas
#    location / {
#        return 301 https://\$host/llamadas;
#    }

    # Strip /llamadas before sending to Jitsi
    location /llamadas/ {
#    location / {
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
EOF
ln -s /etc/nginx/sites-available/proxy_site /etc/nginx/sites-enabled/
rm /etc/nginx/sites-enabled/default
rm /etc/nginx/sites-available/default

# Add stream block to nginx.conf
cat <<STREAM_CONF | sudo tee -a /etc/nginx/nginx.conf > /dev/null
stream {
    upstream backend_xmpp_5222 {
        server 10.0.3.100:5222;
        server 10.0.3.200:5222;
    }

    upstream backend_xmpp_5280 {
        server 10.0.3.100:5280;
        server 10.0.3.200:5280;
    }

    upstream backend_xmpp_5281 {
        server 10.0.3.100:5281;
        server 10.0.3.200:5281;
    }

    upstream backend_xmpp_5347 {
        server 10.0.3.100:5347;
        server 10.0.3.200:5347;
    }

    upstream backend_xmpp_4443 {
        server 10.0.3.100:4443;
        server 10.0.3.200:4443;
    }

    upstream backend_xmpp_10000 {
        server 10.0.3.100:10000;
        server 10.0.3.200:10000;
    }

    upstream backend_xmpp_5269 {
        server 10.0.3.100:5269;
        server 10.0.3.200:5269;
    }
    upstream backend_xmpp_5270 {
        server 10.0.3.100:5270;
        server 10.0.3.200:5270;
    }

    server {
        listen 5222;
        proxy_pass backend_xmpp_5222;
#        proxy_protocol on;
    }

    server {
        listen 5280;
        proxy_pass backend_xmpp_5280;
#        proxy_protocol on;
    }

    server {
        listen 5281;
        proxy_pass backend_xmpp_5281;
 #       proxy_protocol on;
    }

    server {
        listen 5347;
        proxy_pass backend_xmpp_5347;
#        proxy_protocol on;
    }
    server {
        listen 4443;
        proxy_pass backend_xmpp_4443;
#        proxy_protocol on;
    }
    server {
        listen 10000;
        proxy_pass backend_xmpp_10000;
#        proxy_protocol on;
    }

    server {
        listen 5269;
        proxy_pass backend_xmpp_5269;
#        proxy_protocol on;
#       ssl_certificate /etc/letsencrypt/${DUCKDNS_SUBDOMAIN}.duckdns.org/fullchain.pem;
#       ssl_certificate_key /etc/letsencrypt/${DUCKDNS_SUBDOMAIN}.duckdns.org/keyfile.pem;
        proxy_ssl_verify off;
    }

    server {
        listen 5270;
        proxy_pass backend_xmpp_5270;
#        proxy_protocol on;
#        ssl_certificate /etc/letsencrypt/${DUCKDNS_SUBDOMAIN}.duckdns.org/fullchain.pem;
#        ssl_certificate_key /etc/letsencrypt/${DUCKDNS_SUBDOMAIN}.duckdns.org/keyfile.pem;
        proxy_ssl_verify off;
    }
}
STREAM_CONF

sudo systemctl start nginx
sudo systemctl restart nginx
systemctl enable nginx
echo "NGINX installed and configured!"
