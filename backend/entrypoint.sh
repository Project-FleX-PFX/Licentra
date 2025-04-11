#!/bin/sh
set -e

until nc -z db 5432; do
  echo "Waiting for PostgreSQL to start..."
  sleep 1
done
echo "PostgreSQL is up and running!"

bundle exec rake db:setup

exec bundle exec rackup --host 0.0.0.0 -p 4567

