#!/bin/bash

echo 'Waiting for PostgreSQL...'
sleep 15

echo 'Running migrations for core apps...'
python manage.py migrate auth
python manage.py migrate admin
python manage.py migrate contenttypes
python manage.py migrate sessions

echo 'Making migrations for custom apps...'
python manage.py makemigrations account
python manage.py makemigrations product
python manage.py makemigrations payments

echo 'Running migrations for custom apps...'
python manage.py migrate account
python manage.py migrate product
python manage.py migrate payments

echo 'Creating superuser...'
echo "from django.contrib.auth.models import User; User.objects.create_superuser('admin', 'admin@example.com', 'admin123') if not User.objects.filter(username='admin').exists() else print('Superuser already exists')" | python manage.py shell

echo 'Starting server...'
python manage.py runserver 0.0.0.0:8000