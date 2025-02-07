#!/bin/bash

# Variables de configuración
MAESTRO_USER="osboxes"  # Usuario SSH del servidor maestro
MAESTRO_IP="192.168.31.221"  # IP del servidor maestro
DB_NAME="sedes"  # Nombre de la base de datos a copiar
BACKUP_DIR="/var/backups/mysql_maestro"  # Directorio de respaldo
SSH_KEY="/home/osboxes/.ssh/id_rsa"  # Ruta de la clave SSH
MYSQL_DATA_DIR="/var/lib/mysql"
LOGFILE="/var/log/backup_mysql.log"
DUMP_FILE="/tmp/${DB_NAME}-full-dump.sql"  # Ruta de los archivos de datos de MySQL
CRON_JOB="0 2 * * * /path/to/this/script.sh >> /var/log/backup_cron.log 2>&1"

# Marca temporal para diferenciar los respaldos
DATE=$(date +"%Y%m%d%H%M")

# Crear directorio de backup si no existe
mkdir -p "$BACKUP_DIR/$DB_NAME"

function setup_cron_job() {
  crontab -l | grep -q "$CRON_JOB"
  if [ $? -ne 0 ]; then
    echo "Configurando cron para ejecutar el script diariamente a las 2:00 AM..."
    (crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab -
    echo "Tarea programada creada."
  else
    echo "La tarea cron ya está configurada."
  fi
}

function perform_backup() {
  echo "=== Iniciando backup incremental de la base de datos '$DB_NAME' ==="

  # Si es el primer backup, hacemos un dump completo
  if [ ! -f "$BACKUP_DIR/$DB_NAME/last_backup" ]; then
      echo "== Realizando un respaldo completo de la base de datos '$DB_NAME' en el maestro =="
      ssh -i "$SSH_KEY" "$MAESTRO_USER@$MAESTRO_IP" \
          "sudo mysqldump -u root --databases $DB_NAME --single-transaction --quick --lock-tables=false > $DUMP_FILE"

      # Transferir el volcado completo al esclavo
      scp -i "$SSH_KEY" "$MAESTRO_USER@$MAESTRO_IP:/tmp/$DB_NAME-full-dump.sql" "$BACKUP_DIR/$DB_NAME/"
      echo "Backup completo realizado: $(date)" >> "$LOGFILE"
      touch "$BACKUP_DIR/$DB_NAME/last_backup"
  else
      # Realizar un respaldo incremental de los archivos de datos usando rsync
      echo "== Realizando backup incremental de los archivos de datos de MySQL de '$DB_NAME' =="
      mkdir -p "$BACKUP_DIR/$DB_NAME/incremental/$DATE"

      sshpass -p 'osboxes.org' rsync -avz --delete -e "ssh -i $SSH_KEY" --rsync-path="sudo rsync" \
        "$MAESTRO_USER@$MAESTRO_IP:$MYSQL_DATA_DIR/$DB_NAME/" \
        "$BACKUP_DIR/$DB_NAME/incremental/$DATE/"

      if [ $? -eq 0 ]; then
          echo "Backup incremental exitoso para '$DB_NAME': $DATE" >> "$LOGFILE"
      else
          echo "Error en el backup incremental: $DATE" >> "$LOGFILE"
      fi
  fi

  echo "=== Backup finalizado para la base de datos '$DB_NAME' ==="
}

# Ejecutar configuración de cron y backup
setup_cron_job
perform_backup
