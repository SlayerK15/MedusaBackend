#!/bin/bash
set -e

echo "Waiting for PostgreSQL to be ready..."
# Wait for PostgreSQL server to be ready first (without specifying medusa database)
until PGPASSWORD=postgres psql -h postgres -U postgres -d postgres -c '\q' 2>/dev/null; do
  echo "Postgres server is unavailable - sleeping"
  sleep 1
done

echo "Postgres server is up - creating medusa database"

# Force recreate the database
PGPASSWORD=postgres psql -h postgres -U postgres -d postgres -c "DROP DATABASE IF EXISTS medusa;" 2>/dev/null || true
PGPASSWORD=postgres psql -h postgres -U postgres -d postgres -c "CREATE DATABASE medusa WITH OWNER postgres;" || true

# Verify the database was created
echo "Verifying medusa database exists..."
if PGPASSWORD=postgres psql -h postgres -U postgres -d postgres -c "SELECT 1 FROM pg_database WHERE datname = 'medusa'" | grep -q 1; then
  echo "Medusa database exists."
else
  echo "Failed to create medusa database. Trying again..."
  PGPASSWORD=postgres psql -h postgres -U postgres -d postgres -c "CREATE DATABASE medusa;" || true
fi

# Set environment variables 
export DATABASE_URL=${DATABASE_URL:-"postgres://postgres:postgres@postgres:5432/medusa?sslmode=disable"}
export REDIS_URL="redis://redis:6379"
export PGSSLMODE=disable
export PGHOST=postgres
export PGPORT=5432
export PGUSER=postgres
export PGPASSWORD=postgres
export PGDATABASE=medusa
export NODE_TLS_REJECT_UNAUTHORIZED=0

echo "Environment variables set:"
echo "DATABASE_URL=$DATABASE_URL"
echo "PGHOST=$PGHOST"
echo "PGDATABASE=$PGDATABASE"

# Run migrations with explicit PostgreSQL variables
if [ -f ./node_modules/.bin/medusa ]; then
  echo "Running Medusa database migrations..."
  # Use all PG* environment variables directly
  PGHOST=postgres PGPORT=5432 PGUSER=postgres PGPASSWORD=postgres PGDATABASE=medusa PGSSLMODE=disable ./node_modules/.bin/medusa db:migrate
  
  echo "Database setup complete."
fi

echo "Starting Medusa application with PostgreSQL environment variables..."
# Pass all PG* environment variables explicitly
PGHOST=postgres PGPORT=5432 PGUSER=postgres PGPASSWORD=postgres PGDATABASE=medusa PGSSLMODE=disable exec "$@"