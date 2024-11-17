pipeline {
    agent none

    environment {
        DOCKER_CREDS = credentials('docker-hub-credentials')
        DJANGO_SETTINGS_MODULE = 'my_project.settings'
        PYTHONPATH = 'backend'
        WORKSPACE_VENV = './venv'
    }

    stages {
        stage('Build') {
            agent { label 'build-node' } 
            steps {
                sh '''#!/bin/bash
                    # Install python3-venv if not already installed
                    sudo apt-get update
                    sudo apt-get install -y python3-venv python3-pip
                    
                    # Create and activate virtual environment if it doesn't exist
                    python3 -m venv $WORKSPACE_VENV
                    
                    # Activate virtual environment and install dependencies
                    . $WORKSPACE_VENV/bin/activate
                    
                    # Install Python dependencies
                    python -m pip install --upgrade pip
                    pip install -r backend/requirements.txt
                    
                    # Install Node.js and npm if not already installed
                    if ! command -v node &> /dev/null; then
                        curl -fsSL https://deb.nodesource.com/setup_14.x | sudo -E bash -
                        sudo apt-get install -y nodejs
                    fi
                    
                    # Install frontend dependencies
                    cd frontend
                    npm install || (echo "Frontend build failed"; exit 1)
                    cd ..
                    
                    # Deactivate virtual environment
                    deactivate
                '''
            }
        }

        stage('Test') {
            agent { label 'build-node' }
            steps {
                sh '''#!/bin/bash
                    # Activate virtual environment
                    . $WORKSPACE_VENV/bin/activate
                    
                    # Create test reports directory and install test dependencies
                    mkdir -p test-reports
                    pip install pytest-django
                    
                    # Run Django migrations
                    cd backend
                    python manage.py makemigrations
                    python manage.py migrate
                    
                    # Run tests
                    pytest account/tests.py --verbose --junit-xml ../test-reports/results.xml
                    cd ..
                    
                    # Deactivate virtual environment
                    deactivate
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
                // login to DockerHub
                sh 'echo ${DOCKER_CREDS_PSW} | docker login -u ${DOCKER_CREDS_USR} --password-stdin'
                
                // build and push backend
                sh '''
                    docker build -t shafeekuralabs/ecommerce-backend:latest -f Dockerfile.backend .
                    docker push shafeekuralabs/ecommerce-backend:latest
                '''
                
                // build and push frontend
                sh '''
                    docker build -t shafeekuralabs/ecommerce-frontend:latest -f Dockerfile.frontend .
                    docker push shafeekuralabs/ecommerce-frontend:latest
                '''
            }
        }

        stage('Infrastructure') {
            agent { label 'build-node' }
            environment {
                TF_DB_PASSWORD = credentials('terraform-db-password')
                TF_KEY_NAME = credentials('terraform-key-name')
            }
            steps {
                dir('Terraform') {
                    script {
                        // Initialize Terraform
                        sh 'terraform init'
                        
                        // Run terraform plan and capture the output
                        def planOutput = sh(
                            script: """
                                terraform plan \
                                    -var="dockerhub_username=${DOCKER_CREDS_USR}" \
                                    -var="dockerhub_password=${DOCKER_CREDS_PSW}" \
                                    -var="db_password=${TF_DB_PASSWORD}" \
                                    -var="key_name=${TF_KEY_NAME}" \
                                    -detailed-exitcode -out=tfplan 2>&1
                            """,
                            returnStatus: true
                        )
                        
                        // Check the exit code
                        if (planOutput == 0) {
                            echo "No infrastructure changes needed"
                        } else if (planOutput == 2) {
                            echo "Infrastructure changes detected"
                            sh 'terraform apply -auto-approve tfplan'
                        } else {
                            error "Terraform plan failed"
                        }
                    }
                }
            }
            post {
                success {
                    dir('Terraform') {
                        sh '''
                            mkdir -p terraform-states
                            cp terraform.tfstate "terraform-states/terraform-$(date +%Y%m%d-%H%M%S).tfstate"
                        '''
                    }
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