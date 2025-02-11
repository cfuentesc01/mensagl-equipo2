#!/bin/bash
set -e

# === Environment Variables ===
export DB_USERNAME="${DB_USERNAME}"
export DB_PASSWORD="${DB_PASSWORD}"

sudo apt update
sudo apt install mysql-server mysql-client -y
sudo systemctl start mysql
sudo systemctl enable mysql

sleep 20
# MySQL Configuration File
export CONFIG_FILE="/etc/mysql/mysql.conf.d/mysqld.cnf"
# Update MySQL Configuration using awk
awk -i inplace '
    /^bind-address/ { $0="bind-address = 0.0.0.0" }
    /^mysqlx-bind-address/ { $0="mysqlx-bind-address = 127.0.0.1" }
    /^# server-id/ { $0="server-id = 2" }
    /^# log_bin/ { $0="log_bin = /var/log/mysql/mysql-bin.log" }
    { print }
' "$CONFIG_FILE"
# Debug: Print updated MySQL configuration
echo "Updated MySQL Config:"
cat "$CONFIG_FILE"

#sudo systemctl restart mysql
sleep 20

echo "Obteniendo información del maestro..."
MASTER_STATUS=$(mysql -h "10.0.3.10" -u "${DB_USERNAME}" -p"${DB_PASSWORD}" -e "SHOW MASTER STATUS\G" 2>/dev/null)
BINLOG_FILE=$(echo "$MASTER_STATUS" | grep "File:" | awk '{print $2}')
BINLOG_POSITION=$(echo "$MASTER_STATUS" | grep "Position:" | awk '{print $2}')
echo "Archivo binlog: $BINLOG_FILE, Posición: $BINLOG_POSITION"

# Secure MySQL User Creation
sudo mysql -e "CREATE USER IF NOT EXISTS '${DB_USERNAME}'@'%' IDENTIFIED WITH mysql_native_password BY '${DB_PASSWORD}';"
sudo mysql -e "GRANT ALL PRIVILEGES ON *.* TO '${DB_USERNAME}'@'%' WITH GRANT OPTION;"
sudo mysql -e "GRANT REPLICATION SLAVE, REPLICATION CLIENT ON *.* TO '${DB_USERNAME}'@'%';"
sudo mysql -e "FLUSH PRIVILEGES;"

mysql -u root <<SQL
CHANGE MASTER TO
    MASTER_HOST='10.0.3.10',
    MASTER_USER='${DB_USERNAME}',
    MASTER_PASSWORD='${DB_PASSWORD}',
    MASTER_LOG_FILE='$BINLOG_FILE',
    MASTER_LOG_POS=$BINLOG_POSITION,
    MASTER_SSL=0;
START SLAVE;
SHOW SLAVE STATUS\G;
SQL

sudo systemctl restart mysql
echo "MySQL DB XMPP SLAVE !!"
