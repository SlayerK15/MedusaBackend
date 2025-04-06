FROM node:18

WORKDIR /app

# Install system dependencies
RUN apt-get update && \
    apt-get install -y python3 build-essential && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Add PostgreSQL apt repository and install diagnostic tools
RUN apt-get update && \
    apt-get install -y lsb-release wget gnupg2 && \
    echo "deb http://apt.postgresql.org/pub/repos/apt/ $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list && \
    wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add - && \
    apt-get update && \
    apt-get install -y postgresql-client iputils-ping net-tools redis-tools && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Install Medusa CLI globally
RUN npm install -g @medusajs/medusa-cli

# Copy package.json and package-lock.json
COPY package*.json ./

# Install dependencies
RUN npm install

# Copy the rest of the application
COPY . .

# Build the application including the admin panel
RUN echo "Building Medusa application and admin panel..." && \
    npm run build && \
    medusa build

# Create a modified entrypoint script for Fargate
RUN echo '#!/bin/bash' > /usr/local/bin/fargate-entrypoint.sh && \
    echo 'set -e' >> /usr/local/bin/fargate-entrypoint.sh && \
    echo '' >> /usr/local/bin/fargate-entrypoint.sh && \
    echo '# Check if we are running in ECS by checking for ECS container metadata endpoint' >> /usr/local/bin/fargate-entrypoint.sh && \
    echo 'if [[ -n "$ECS_CONTAINER_METADATA_URI_V4" ]]; then' >> /usr/local/bin/fargate-entrypoint.sh && \
    echo '  echo "Running in ECS environment - using localhost for connections"' >> /usr/local/bin/fargate-entrypoint.sh && \
    echo '  PG_HOST="127.0.0.1"' >> /usr/local/bin/fargate-entrypoint.sh && \
    echo '  REDIS_HOST="127.0.0.1"' >> /usr/local/bin/fargate-entrypoint.sh && \
    echo 'else' >> /usr/local/bin/fargate-entrypoint.sh && \
    echo '  echo "Running in standard Docker environment - using service names for connections"' >> /usr/local/bin/fargate-entrypoint.sh && \
    echo '  PG_HOST="postgres"' >> /usr/local/bin/fargate-entrypoint.sh && \
    echo '  REDIS_HOST="redis"' >> /usr/local/bin/fargate-entrypoint.sh && \
    echo 'fi' >> /usr/local/bin/fargate-entrypoint.sh && \
    echo '' >> /usr/local/bin/fargate-entrypoint.sh && \
    echo 'echo "Waiting for PostgreSQL to be ready at $PG_HOST..."' >> /usr/local/bin/fargate-entrypoint.sh && \
    echo '# Wait for PostgreSQL server to be ready' >> /usr/local/bin/fargate-entrypoint.sh && \
    echo 'MAX_TRIES=60' >> /usr/local/bin/fargate-entrypoint.sh && \
    echo 'COUNT=0' >> /usr/local/bin/fargate-entrypoint.sh && \
    echo 'until PGPASSWORD=postgres psql -h $PG_HOST -U postgres -d postgres -c "\q" 2>/dev/null; do' >> /usr/local/bin/fargate-entrypoint.sh && \
    echo '  COUNT=$((COUNT+1))' >> /usr/local/bin/fargate-entrypoint.sh && \
    echo '  if [ $COUNT -gt $MAX_TRIES ]; then' >> /usr/local/bin/fargate-entrypoint.sh && \
    echo '    echo "Error: PostgreSQL did not become available in time. Network diagnostics:"' >> /usr/local/bin/fargate-entrypoint.sh && \
    echo '    ip addr' >> /usr/local/bin/fargate-entrypoint.sh && \
    echo '    ping -c 1 $PG_HOST || echo "Cannot ping PostgreSQL host"' >> /usr/local/bin/fargate-entrypoint.sh && \
    echo '    netstat -tuln' >> /usr/local/bin/fargate-entrypoint.sh && \
    echo '    exit 1' >> /usr/local/bin/fargate-entrypoint.sh && \
    echo '  fi' >> /usr/local/bin/fargate-entrypoint.sh && \
    echo '  echo "Postgres server is unavailable (attempt $COUNT/$MAX_TRIES) - sleeping"' >> /usr/local/bin/fargate-entrypoint.sh && \
    echo '  sleep 2' >> /usr/local/bin/fargate-entrypoint.sh && \
    echo 'done' >> /usr/local/bin/fargate-entrypoint.sh && \
    echo '' >> /usr/local/bin/fargate-entrypoint.sh && \
    echo 'echo "Postgres server is up - creating medusa database"' >> /usr/local/bin/fargate-entrypoint.sh && \
    echo '' >> /usr/local/bin/fargate-entrypoint.sh && \
    echo '# Force recreate the database' >> /usr/local/bin/fargate-entrypoint.sh && \
    echo 'PGPASSWORD=postgres psql -h $PG_HOST -U postgres -d postgres -c "DROP DATABASE IF EXISTS medusa;" 2>/dev/null || true' >> /usr/local/bin/fargate-entrypoint.sh && \
    echo 'PGPASSWORD=postgres psql -h $PG_HOST -U postgres -d postgres -c "CREATE DATABASE medusa WITH OWNER postgres;" || true' >> /usr/local/bin/fargate-entrypoint.sh && \
    echo '' >> /usr/local/bin/fargate-entrypoint.sh && \
    echo '# Verify the database was created' >> /usr/local/bin/fargate-entrypoint.sh && \
    echo 'echo "Verifying medusa database exists..."' >> /usr/local/bin/fargate-entrypoint.sh && \
    echo 'if PGPASSWORD=postgres psql -h $PG_HOST -U postgres -d postgres -c "SELECT 1 FROM pg_database WHERE datname = \\"medusa\\"" | grep -q 1; then' >> /usr/local/bin/fargate-entrypoint.sh && \
    echo '  echo "Medusa database exists."' >> /usr/local/bin/fargate-entrypoint.sh && \
    echo 'else' >> /usr/local/bin/fargate-entrypoint.sh && \
    echo '  echo "Failed to create medusa database. Trying again..."' >> /usr/local/bin/fargate-entrypoint.sh && \
    echo '  PGPASSWORD=postgres psql -h $PG_HOST -U postgres -d postgres -c "CREATE DATABASE medusa;" || true' >> /usr/local/bin/fargate-entrypoint.sh && \
    echo 'fi' >> /usr/local/bin/fargate-entrypoint.sh && \
    echo '' >> /usr/local/bin/fargate-entrypoint.sh && \
    echo '# Wait for Redis to be ready' >> /usr/local/bin/fargate-entrypoint.sh && \
    echo 'echo "Checking if Redis is available at $REDIS_HOST..."' >> /usr/local/bin/fargate-entrypoint.sh && \
    echo 'MAX_TRIES=30' >> /usr/local/bin/fargate-entrypoint.sh && \
    echo 'COUNT=0' >> /usr/local/bin/fargate-entrypoint.sh && \
    echo 'until redis-cli -h $REDIS_HOST ping | grep -q PONG; do' >> /usr/local/bin/fargate-entrypoint.sh && \
    echo '  COUNT=$((COUNT+1))' >> /usr/local/bin/fargate-entrypoint.sh && \
    echo '  if [ $COUNT -gt $MAX_TRIES ]; then' >> /usr/local/bin/fargate-entrypoint.sh && \
    echo '    echo "Error: Redis did not become available in time"' >> /usr/local/bin/fargate-entrypoint.sh && \
    echo '    exit 1' >> /usr/local/bin/fargate-entrypoint.sh && \
    echo '  fi' >> /usr/local/bin/fargate-entrypoint.sh && \
    echo '  echo "Redis is unavailable (attempt $COUNT/$MAX_TRIES) - sleeping"' >> /usr/local/bin/fargate-entrypoint.sh && \
    echo '  sleep 2' >> /usr/local/bin/fargate-entrypoint.sh && \
    echo 'done' >> /usr/local/bin/fargate-entrypoint.sh && \
    echo 'echo "Redis is available!"' >> /usr/local/bin/fargate-entrypoint.sh && \
    echo '' >> /usr/local/bin/fargate-entrypoint.sh && \
    echo '# Set environment variables' >> /usr/local/bin/fargate-entrypoint.sh && \
    echo 'export DATABASE_URL="postgres://postgres:postgres@$PG_HOST:5432/medusa?sslmode=disable"' >> /usr/local/bin/fargate-entrypoint.sh && \
    echo 'export REDIS_URL="redis://$REDIS_HOST:6379"' >> /usr/local/bin/fargate-entrypoint.sh && \
    echo 'export PGSSLMODE=disable' >> /usr/local/bin/fargate-entrypoint.sh && \
    echo 'export PGHOST=$PG_HOST' >> /usr/local/bin/fargate-entrypoint.sh && \
    echo 'export PGPORT=5432' >> /usr/local/bin/fargate-entrypoint.sh && \
    echo 'export PGUSER=postgres' >> /usr/local/bin/fargate-entrypoint.sh && \
    echo 'export PGPASSWORD=postgres' >> /usr/local/bin/fargate-entrypoint.sh && \
    echo 'export PGDATABASE=medusa' >> /usr/local/bin/fargate-entrypoint.sh && \
    echo 'export NODE_TLS_REJECT_UNAUTHORIZED=0' >> /usr/local/bin/fargate-entrypoint.sh && \
    echo '' >> /usr/local/bin/fargate-entrypoint.sh && \
    echo 'echo "Environment variables set:"' >> /usr/local/bin/fargate-entrypoint.sh && \
    echo 'echo "DATABASE_URL=$DATABASE_URL"' >> /usr/local/bin/fargate-entrypoint.sh && \
    echo 'echo "REDIS_URL=$REDIS_URL"' >> /usr/local/bin/fargate-entrypoint.sh && \
    echo 'echo "PGHOST=$PGHOST"' >> /usr/local/bin/fargate-entrypoint.sh && \
    echo 'echo "PGDATABASE=$PGDATABASE"' >> /usr/local/bin/fargate-entrypoint.sh && \
    echo '' >> /usr/local/bin/fargate-entrypoint.sh && \
    echo '# Run migrations with explicit PostgreSQL variables' >> /usr/local/bin/fargate-entrypoint.sh && \
    echo 'if [ -f ./node_modules/.bin/medusa ]; then' >> /usr/local/bin/fargate-entrypoint.sh && \
    echo '  echo "Running Medusa database migrations..."' >> /usr/local/bin/fargate-entrypoint.sh && \
    echo '  ./node_modules/.bin/medusa db:migrate' >> /usr/local/bin/fargate-entrypoint.sh && \
    echo '  echo "Database setup complete."' >> /usr/local/bin/fargate-entrypoint.sh && \
    echo 'fi' >> /usr/local/bin/fargate-entrypoint.sh && \
    echo '' >> /usr/local/bin/fargate-entrypoint.sh && \
    echo '# For debugging admin build directory' >> /usr/local/bin/fargate-entrypoint.sh && \
    echo 'echo "Checking admin build directory:"' >> /usr/local/bin/fargate-entrypoint.sh && \
    echo 'ls -la /app/build || echo "No build directory found"' >> /usr/local/bin/fargate-entrypoint.sh && \
    echo 'ls -la /app/dist || echo "No dist directory found"' >> /usr/local/bin/fargate-entrypoint.sh && \
    echo 'find /app -name "index.html" | grep admin || echo "No admin index.html found"' >> /usr/local/bin/fargate-entrypoint.sh && \
    echo '' >> /usr/local/bin/fargate-entrypoint.sh && \
    echo 'echo "Starting Medusa application..."' >> /usr/local/bin/fargate-entrypoint.sh && \
    echo 'exec "$@"' >> /usr/local/bin/fargate-entrypoint.sh

RUN chmod +x /usr/local/bin/fargate-entrypoint.sh

# Expose the port Medusa runs on
EXPOSE 9000

# Set environment variables (these will be overridden by container definitions)
ENV NODE_ENV=production
ENV PORT=9000

# Use our Fargate-compatible entrypoint
ENTRYPOINT ["/usr/local/bin/fargate-entrypoint.sh"]

# Start Medusa with the dev flag to avoid admin build requirements
CMD ["npm", "run", "dev"]