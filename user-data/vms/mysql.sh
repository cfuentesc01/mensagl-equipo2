#!/bin/bash
set -e

# === Environment Variables ===
export DB_USERNAME="${DB_USERNAME}"
export DB_PASSWORD="${DB_PASSWORD}"

apt-get update -y
apt-get install mysql-server mysql-client -y
sudo systemctl start mysql
sudo systemctl enable mysql

sleep 20
# MySQL Configuration File
export CONFIG_FILE="/etc/mysql/mysql.conf.d/mysqld.cnf"
# Update MySQL Configuration using awk
awk -i inplace '
    /^bind-address/ { $0="bind-address = 0.0.0.0" }
    /^mysqlx-bind-address/ { $0="mysqlx-bind-address = 127.0.0.1" }
    /^# server-id/ { $0="server-id = 1" }
    /^# log_bin/ { $0="log_bin = /var/log/mysql/mysql-bin.log" }
    { print }
' "$CONFIG_FILE"
# Debug: Print updated MySQL configuration
echo "Updated MySQL Config:"
cat "$CONFIG_FILE"

sudo systemctl restart mysql
sleep 20

# Secure MySQL User Creation
sudo mysql -e "CREATE USER IF NOT EXISTS '${DB_USERNAME}'@'%' IDENTIFIED WITH mysql_native_password BY '${DB_PASSWORD}';"
sudo mysql -e "GRANT ALL PRIVILEGES ON *.* TO '${DB_USERNAME}'@'%' WITH GRANT OPTION;"
sudo mysql -e "GRANT REPLICATION SLAVE, REPLICATION CLIENT ON *.* TO '${DB_USERNAME}'@'%';"
sudo mysql -e "FLUSH PRIVILEGES;"

# Verify the user was created
sudo mysql -e "SELECT user, host FROM mysql.user;"

# Final restart to ensure everything is applied
sudo systemctl restart mysql

echo "MySQL DB XMPP MASTER SETUP COMPLETED!"
