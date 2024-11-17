pipeline {
    agent none  // we are specify the build-node agent per stage

    environment {
        DOCKER_CREDS = credentials('docker-hub-credentials')
        DJANGO_SETTINGS_MODULE = 'my_project.settings'
        PYTHONPATH = 'backend'
    }

    stages {
        stage('Build') {
            agent { label 'build-node' } 
            steps {
                sh '''#!/bin/bash
                    # Install Python dependencies
                    python -m pip install --upgrade pip
                    pip install -r backend/requirements.txt
                    
                    # Install Node.js dependencies
                    cd frontend
                    npm install || (echo "Frontend build failed"; exit 1)
                    cd ..
                '''
            }
        }

        stage('Test') {
            agent { label 'build-node' }
            steps {
                sh '''#!/bin/bash
                    # Create test reports directory and install test dependencies
                    mkdir -p test-reports
                    pip install pytest-django
                    
                    # Run Django migrations
                    python backend/manage.py makemigrations
                    python backend/manage.py migrate
                    
                    # Run tests
                    pytest backend/account/tests.py --verbose --junit-xml test-reports/results.xml
                '''
            }
        }

        stage('Cleanup') {
            agent { label 'build-node' }
            steps {
                sh '''
                    # Clean Docker system
                    docker system prune -f
                    
                    # Clean Git repository while preserving Terraform state
                    git clean -ffdx -e "*.tfstate*" -e ".terraform/*"
                '''
            }
        }

        stage('Build & Push Images') {
            agent { label 'build-node' }
            steps {
                // Login to DockerHub
                sh 'echo ${DOCKER_CREDS_PSW} | docker login -u ${DOCKER_CREDS_USR} --password-stdin'
                
                // Build and push backend
                sh '''
                    docker build -t shafeekuralabs/ecommerce-backend:latest -f Dockerfile.backend .
                    docker push shafeekuralabs/ecommerce-backend:latest
                '''
                
                // Build and push frontend
                sh '''
                    docker build -t shafeekuralabs/ecommerce-frontend:latest -f Dockerfile.frontend .
                    docker push shafeekuralabs/ecommerce-frontend:latest
                '''
            }
        }

        stage('Infrastructure') {
            agent { label 'build-node' }
            steps {
                dir('Terraform') {
                    sh '''
                        terraform init
                        terraform apply -auto-approve \
                            -var="dockerhub_username=${DOCKER_CREDS_USR}" \
                            -var="dockerhub_password=${DOCKER_CREDS_PSW}"
                    '''
                }
            }
        }
    }

    post {
        always {
            node('build-node') {
                sh '''
                    docker logout
                    docker system prune -f
                '''
            }
        }
    }
}