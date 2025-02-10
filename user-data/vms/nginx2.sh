#!/bin/bash

export DUCKDNS_TOKEN=${DUCKDNS_TOKEN}
export DUCKDNS_SUBDOMAIN2=${DUCKDNS_SUBDOMAIN2}
export EMAIL=${EMAIL}
export host="$host"
export request_uri="$request_uri"

# Update and install necessary packages
apt-get update -y
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y curl certbot nginx-full wget python3-pip
sudo systemctl stop nginx
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
echo "Updating DuckDNS: ${DUCKDNS_SUBDOMAIN2}"
curl -k "https://www.duckdns.org/update?domains=${DUCKDNS_SUBDOMAIN2}&token=${DUCKDNS_TOKEN}&ip=" -o /opt/duckdns/duck.log
DUCKDNS_SCRIPT
chmod +x /opt/duckdns/duckdns.sh
(crontab -l 2>/dev/null; echo "*/5 * * * * /opt/duckdns/duckdns.sh >/dev/null 2>&1") | crontab -

# Update DuckDNS immediately to set the IP
echo "Updating DuckDNS IP..."
/opt/duckdns/duckdns.sh

sleep 30
# Obtain SSL certificate in standalone mode (non-interactive)
echo "Obtaining SSL certificate using certbot..."
certbot certonly --standalone \
  --non-interactive \
  --agree-tos \
  --email $EMAIL \
  -d "${DUCKDNS_SUBDOMAIN}.duckdns.org"

wget -O /tmp/proxy_site "https://raw.githubusercontent.com/cfuentesc01/mensagl-equipo2/main/user-data/proxy_site2"
envsubst '${DUCKDNS_SUBDOMAIN2}' < /tmp/proxy_site > /etc/nginx/sites-available/proxy_site
envsubst '$DUCKDNS_SUBDOMAIN2' < /tmp/proxy_site > /etc/nginx/sites-available/proxy_site
sed "s|\${DUCKDNS_SUBDOMAIN2}|${DUCKDNS_SUBDOMAIN2}|g" /etc/nginx/sites-available/proxy_site
awk -v sub="$DUCKDNS_SUBDOMAIN2" '{gsub(/\$\{DUCKDNS_SUBDOMAIN2\}/, sub)}1' /etc/nginx/sites-available/proxy_site
ln -s /etc/nginx/sites-available/proxy_site /etc/nginx/sites-enabled/
rm /etc/nginx/sites-enabled/default
rm /etc/nginx/sites-available/default

sudo systemctl start nginx
systemctl enable nginx
echo "DDNS installed !"