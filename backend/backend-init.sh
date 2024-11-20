#!/bin/bash
set -e

echo 'Waiting for PostgreSQL...'
sleep 15

# Function to check if PostgreSQL is ready
check_postgres() {
    python << END
import psycopg2
import sys
try:
    conn = psycopg2.connect(
        dbname="ecommerce",
        user="${DB_USER}",
        password="${DB_PASSWORD}",
        host="${DB_HOST}",
        port="${DB_PORT}"
    )
    conn.close()
    sys.exit(0)
except:
    sys.exit(1)
END
}

# Wait for PostgreSQL to be ready
echo "Waiting for PostgreSQL to be ready..."
for i in {1..30}; do
    if check_postgres; then
        echo "PostgreSQL is ready!"
        break
    fi
    echo "Waiting for PostgreSQL... attempt $i"
    sleep 5
done

if [ "$RUN_MIGRATIONS" = "true" ]; then
    echo "Running database migrations..."
    
    # Run core migrations first
    python manage.py migrate auth
    python manage.py migrate admin
    python manage.py migrate contenttypes
    python manage.py migrate sessions

    # Run app migrations
    python manage.py migrate account
    python manage.py migrate product
    python manage.py migrate payments

    # Dump data from SQLite and load into PostgreSQL
    if [ -f db.sqlite3 ]; then
        echo "Found SQLite database, transferring data..."
        python manage.py dumpdata --database=sqlite --natural-foreign --natural-primary -e contenttypes -e auth.Permission --indent 4 > datadump.json
        python manage.py loaddata datadump.json
        rm -f db.sqlite3
        rm -f datadump.json
    fi

    # Create superuser
    python manage.py shell << END
from django.contrib.auth.models import User
if not User.objects.filter(username='admin').exists():
    User.objects.create_superuser('admin', 'admin@example.com', 'admin123')
    print('Superuser created successfully')
else:
    print('Superuser already exists')
END

else
    echo "Skipping migrations..."
fi

echo 'Starting server...'
python manage.py runserver 0.0.0.0:8000