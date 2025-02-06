#!/bin/bash

# Verificar ejecución como superusuario
if [ "$EUID" -ne 0 ]; then
  echo "Este script debe ejecutarse como superusuario. Usa sudo."
  exit 1
fi

# Variables del entorno
MASTER_IP="10.0.1.10"
SLAVE_IP="10.0.1.20"
MASTER_USER="replicador"
MASTER_PASSWORD="Admin123"

# Actualizar repositorios e instalar MySQL Server
echo "Actualizando repositorios e instalando MySQL Server..."
sudo apt update
sudo apt install mysql-server -y

# Iniciar y habilitar MySQL
sudo systemctl start mysql
sudo systemctl enable mysql

# Configurar MySQL para aceptar conexiones remotas
echo "Configurando MySQL para aceptar conexiones remotas..."
CONFIG_DIR="/etc/mysql/mysql.conf.d"
CONFIG_FILE="mysqld.cnf"
CONFIG_PATH="$CONFIG_DIR/$CONFIG_FILE"
if [ -f "$CONFIG_PATH" ]; then
  sudo sed -i "s/^bind-address.*/bind-address = 0.0.0.0/" "$CONFIG_PATH"
  sudo sed -i "s/^# server-id.*/server-id = 1/" "$CONFIG_PATH"
  sudo sed -i "s|^# log_bin.*|log_bin = /var/log/mysql/mysql-bin.log|" "$CONFIG_PATH"
else
  echo "Archivo de configuración $CONFIG_PATH no encontrado. Abortando."
  exit 1
fi

# Reiniciar MySQL para aplicar cambios
sudo systemctl restart mysql

# Crear usuario replicador y bloquear tablas temporalmente
mysql -u root <<EOF
CREATE USER IF NOT EXISTS '$MASTER_USER'@'$SLAVE_IP' IDENTIFIED WITH mysql_native_password BY '$MASTER_PASSWORD';
GRANT REPLICATION SLAVE, REPLICATION CLIENT ON *.* TO '$MASTER_USER'@'$SLAVE_IP';
FLUSH PRIVILEGES;
FLUSH TABLES WITH READ LOCK;
SHOW MASTER STATUS;
UNLOCK TABLES;
EOF

# Mostrar instrucciones finales
echo "------------------------------------------------------------"
echo "Anota el archivo binlog y la posición mostrados. Recuerda desbloquear tablas si es necesario con UNLOCK TABLES."
echo "------------------------------------------------------------"
sudo systemctl restart mysql

mysql -u root <<EOF
SHOW MASTER STATUS;
EOF

exit 0