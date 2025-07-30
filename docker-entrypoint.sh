#!/bin/bash
set -e

APP_DIR="/var/www/html"
SOURCE_DIR="/usr/src/tastyigniter"
ENV_FILE="$APP_DIR/.env"

wait_for_db() {
    echo "Waiting for database at $DB_HOST:3306..."
    local retries=10
    while ! nc -z "$DB_HOST" 3306; do
        ((retries--))
        if [ "$retries" -le 0 ]; then
            echo "Database not reachable, exiting."
            exit 1
        fi
        sleep 3
    done
    echo "Database is available."
}

is_first_time() {
    [ ! -f "$ENV_FILE" ] || ! grep -q '^APP_KEY=' "$ENV_FILE"
}

initialize_app() {
    echo "First-time setup detected. Initializing TastyIgniter..."
    tar cf - --one-file-system -C "$SOURCE_DIR" . | tar xf - -C "$APP_DIR"
    chown -R www-data:www-data "$APP_DIR"
    php artisan key:generate --force
    wait_for_db
    php artisan igniter:install --no-interaction
    php artisan extension:install igniter.frontend 
    php artisan theme:install tastyigniter-orange
    echo "Setup complete."
}

start_services() {
    echo "Starting services..."
    /etc/init.d/cron start
    supervisord -c /etc/supervisor/supervisord.conf
}

if is_first_time; then
    initialize_app
else
    echo "App already initialized, skipping setup."
fi

start_services

exec "$@"