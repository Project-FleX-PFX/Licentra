#!/bin/sh
set -e

is_test_command=0
if [ "$1" = "bundle" ] && [ "$2" = "exec" ]; then
  if ([ "$3" = "rake" ] && [[ "$4" == spec* ]]) || [ "$3" = "rspec" ]; then
    is_test_command=1
  fi
elif [ "$1" = "rake" ] && [[ "$2" == spec* ]]; then
  is_test_command=1
elif [ "$1" = "rspec" ]; then
  is_test_command=1
fi

if [ "$is_test_command" -eq 1 ]; then
  echo "[Entrypoint] Detected Test Command ($*)."
  echo "[Entrypoint] Setting RACK_ENV=test."
  export RACK_ENV=test

  echo "[Entrypoint] Executing Test Command: $*"
  exec "$@"
else
  echo "[Entrypoint] Detected Non-Test Command ($*)."
  DB_HOST=${DB_HOST:-db}
  DB_PORT=${DB_PORT:-5432}
  echo "[Entrypoint] Waiting for PostgreSQL at $DB_HOST:$DB_PORT..."
  while ! nc -z "$DB_HOST" "$DB_PORT"; do
    echo "[Entrypoint] Waiting for PostgreSQL connection..."
    sleep 1
  done
  echo "[Entrypoint] PostgreSQL is up and running!"

  echo "[Entrypoint] Running database migrations..."
  MIGRATION_ONLY=true bundle exec rake db:migrate
  echo "[Entrypoint] Migrations finished."

  echo "[Entrypoint] Running database seeds..."
  bundle exec rake db:seed
  echo "[Entrypoint] Seeding finished."

  exec bundle exec rackup --host 0.0.0.0 -p 4567
fi
