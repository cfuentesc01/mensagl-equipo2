#!/bin/bash
set -e

sudo apt update
sudo apt install mysql-server mysql-client -y
sudo systemctl start mysql
sudo systemctl enable mysql

sleep 60
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

sudo systemctl restart mysql
sleep 120

echo "Obteniendo información del maestro..."
MASTER_STATUS=$(mysql -h "10.0.3.10" -u "cowboy_del_infierno" -p"_Admin123" -e "SHOW MASTER STATUS\G" 2>/dev/null)
BINLOG_FILE=$(echo "$MASTER_STATUS" | grep "File:" | awk '{print $2}')
BINLOG_POSITION=$(echo "$MASTER_STATUS" | grep "Position:" | awk '{print $2}')
echo "Archivo binlog: $BINLOG_FILE, Posición: $BINLOG_POSITION"
mysql -u root <<SQL
CHANGE MASTER TO
    MASTER_HOST='10.0.3.10',
    MASTER_USER='cowboy_del_infierno',
    MASTER_PASSWORD='_Admin123',
    MASTER_LOG_FILE='$BINLOG_FILE',
    MASTER_LOG_POS=$BINLOG_POSITION,
    MASTER_SSL=0;
START SLAVE;
SHOW SLAVE STATUS\G;
SQL

echo "MySQL DB XMPP SLAVE !!"
