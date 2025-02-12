#!/bin/bash

# Variables de configuración
MAESTRO_USER="osboxes"  # Usuario SSH del servidor maestro
MAESTRO_IP="192.168.31.221"  # IP del servidor maestro
DB_NAME="sedes"  # Nombre de la base de datos a copiar
BACKUP_DIR="/var/backups/mysql_maestro"  # Directorio de respaldo
SSH_KEY="/home/osboxes/.ssh/id_rsa"  # Ruta de la clave SSH
MYSQL_DATA_DIR="/var/lib/mysql"  # Directorio de datos de MySQL
LOGFILE="/var/log/backup_mysql.log"  # Archivo de log
DUMP_FILE="/tmp/${DB_NAME}-full-dump.sql"  # Ruta de los archivos de datos de MySQL
BINLOG_DIR="/var/lib/mysql"  # Directorio de binlogs en el maestro
BINLOG_BACKUP_DIR="$BACKUP_DIR/$DB_NAME/binlogs"  # Directorio de respaldo de binlogs

# Marca temporal para diferenciar los respaldos
DATE=$(date +"%Y%m%d%H%M")

# Crear directorio de backup si no existe
mkdir -p "$BACKUP_DIR/$DB_NAME"
mkdir -p "$BINLOG_BACKUP_DIR"

function perform_backup() {
    # Si es el primer backup, hacemos un dump completo
    if [ ! -f "$BACKUP_DIR/$DB_NAME/last_backup" ]; then
        echo "== Realizando un respaldo completo de la base de datos '$DB_NAME' en el maestro =="

        # Realizar el volcado completo de la base de datos
        ssh -i "$SSH_KEY" "$MAESTRO_USER@$MAESTRO_IP" \
            "sudo mysqldump -u root --databases $DB_NAME --single-transaction --quick --lock-tables=false > $DUMP_FILE"

        # Transferir el volcado completo al servidor local
        scp -i "$SSH_KEY" "$MAESTRO_USER@$MAESTRO_IP:$DUMP_FILE" "$BACKUP_DIR/$DB_NAME/"
        echo "Backup completo realizado: $(date)" >> "$LOGFILE"

        # Marcar el último backup realizado
        touch "$BACKUP_DIR/$DB_NAME/last_backup"
    else
        # Realizar un respaldo incremental de los archivos de datos de MySQL
        echo "== Realizando backup incremental de los archivos de datos de MySQL de '$DB_NAME' =="

        # Crear directorio para el respaldo incremental de la fecha
        sudo mkdir -p "$BACKUP_DIR/$DB_NAME/incremental/$DATE"

        # Usamos rsync para copiar los archivos de datos que han cambiado desde el último backup
        sshpass -p 'osboxes.org' sudo rsync -avz --delete -e "ssh -i $SSH_KEY" --rsync-path="sudo rsync" \
        "$MAESTRO_USER@$MAESTRO_IP:$MYSQL_DATA_DIR/sedes/" "$BACKUP_DIR/$DB_NAME/incremental/$DATE/"

        if [ $? -eq 0 ]; then
            echo "Backup incremental exitoso para '$DB_NAME': $DATE" >> "$LOGFILE"
        else
            echo "Error en el backup incremental: $DATE" >> "$LOGFILE"
        fi

        # Backup incremental de los binlogs
        echo "== Realizando backup incremental de binlogs para '$DB_NAME' =="

        # Copiar los dos archivos binlog más recientes
        FILES=$(ssh -i "$SSH_KEY" "$MAESTRO_USER@$MAESTRO_IP" "sudo ls -1t $BINLOG_DIR/llamadas-relay-bin.* | grep -v '\.index$'| head -n 2")

        while IFS= read -r FILE; do
            FILENAME=$(basename "$FILE")
            echo "Copiando $FILENAME..."

            scp -i "$SSH_KEY" "$MAESTRO_USER@$MAESTRO_IP:$FILE" "$BINLOG_BACKUP_DIR/$FILENAME"
        done <<< "$FILES"

        if [ $? -eq 0 ]; then
            echo "Backup incremental exitoso de binlogs para '$DB_NAME': $DATE" >> "$LOGFILE"
        else
            echo "Error en el backup incremental de binlogs: $DATE" >> "$LOGFILE"
        fi
    fi

    echo "=== Backup finalizado para la base de datos '$DB_NAME' ==="
}

# Ejecutar el backup
perform_backup
