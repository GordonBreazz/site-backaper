#!/bin/bash

# Настройки
REMOTE_USER="имя_пользователя"                # Пользователь на сервере
REMOTE_HOST="example.com"                      # Домен или IP-адрес сервера
REMOTE_DIR="/путь/к/вашему/сайту"              # Директория сайта на сервере
BACKUP_DIR="/путь/к/локальной/папке/бекапа"    # Локальная папка для бекапа
DATE=$(date +"%Y-%m-%d_%H-%M-%S")              # Метка времени для названия архива

# Запрос пароля при запуске
echo -n "Введите пароль для $REMOTE_USER@$REMOTE_HOST: "
read -s PASSWORD
echo

# Массив с данными для подключения к базам данных
declare -A DATABASES=(
    ["имя_базы1"]="пользователь1:пароль1"
    ["имя_базы2"]="пользователь2:пароль2"
    ["имя_базы3"]="пользователь3:пароль3"
)

# Создаём директорию для бэкапов, если её нет
mkdir -p "$BACKUP_DIR"

# Функция для создания дампов баз данных
function create_db_dumps {
    for DB_NAME in "${!DATABASES[@]}"; do
        DB_CREDENTIALS="${DATABASES[$DB_NAME]}"
        DB_USER="${DB_CREDENTIALS%%:*}"         # Извлекаем пользователя
        DB_PASSWORD="${DB_CREDENTIALS#*:}"      # Извлекаем пароль

        # Запуск дампа базы данных на удалённом сервере
        sshpass -p "$PASSWORD" ssh "$REMOTE_USER@$REMOTE_HOST" << EOF
            mkdir -p "$REMOTE_DIR/db_dumps"                 # Создаём папку для дампов, если её нет
            export MYSQL_PWD="$DB_PASSWORD"                 # Устанавливаем пароль через переменную среды
            mysqldump -u "$DB_USER" "$DB_NAME" > "$REMOTE_DIR/db_dumps/${DB_NAME}_dump_$DATE.sql" # Дамп базы
EOF
        # Проверка успешности дампа базы данных
        if [ $? -eq 0 ]; then
            echo "Дамп базы данных $DB_NAME завершён успешно."
        else
            echo "Ошибка: дамп базы данных $DB_NAME не выполнен."
            exit 1
        fi
    done
}

# Функция для копирования файлов сайта и дампов баз данных на локальный сервер
function backup_site_files {
    echo "Начинается копирование файлов сайта и дампов баз данных..."
    sshpass -p "$PASSWORD" rsync -avz --progress -e ssh "$REMOTE_USER@$REMOTE_HOST:$REMOTE_DIR" "$BACKUP_DIR/site_backup_$DATE"
    
    # Проверка успешности копирования
    if [ $? -eq 0 ]; then
        echo "Бекап завершён успешно. Файлы и дампы сохранены в $BACKUP_DIR/site_backup_$DATE"
    else
        echo "Ошибка: бекап не выполнен."
        exit 1
    fi
}

# Запуск функций
create_db_dumps         # Создание дампов баз данных
backup_site_files       # Копирование файлов сайта и дампов
