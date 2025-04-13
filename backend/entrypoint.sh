#!/bin/sh
set -e

until nc -z db 5432; do
  echo "Waiting for PostgreSQL to start..."
  sleep 1
done
echo "PostgreSQL is up and running!"

# only migrations without loading of models
MIGRATION_ONLY=true bundle exec rake db:migrate

# afterwards loading seed and models
bundle exec rake db:seed

exec bundle exec rackup --host 0.0.0.0 -p 4567

