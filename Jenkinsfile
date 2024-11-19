pipeline {
    agent none

    environment {
        DOCKER_CREDS = credentials('docker-hub-credentials')
        DJANGO_SETTINGS_MODULE = 'my_project.settings'
        PYTHONPATH = 'backend'
        WORKSPACE_VENV = './venv'
        TF_DB_PASSWORD = credentials('terraform-db-password')
        TF_KEY_NAME = credentials('terraform-key-name')
        TF_PRIVATE_KEY_PATH = credentials('terraform-private-key-path')
        SONAR_TOKEN = credentials('sonar-token')
    }

    stages {
        stage('Build') {
            agent { label 'build-node' }
            steps {
                sh '''#!/bin/bash
                    python3 -m venv venv
                    source venv/bin/activate
                    pip install --upgrade pip
                    pip install -r backend/requirements.txt
                    deactivate
                '''
            }
        }

        stage('Security Scans') {
            agent { label 'build-node' }
            steps {
                // Create reports directory
                sh 'mkdir -p reports'
                
                // Run Checkov for IaC scanning
                sh '''#!/bin/bash
                    source venv/bin/activate
                    cd Terraform
                    checkov -d . -o json > ../reports/checkov_report.json || true
                    cd ..
                    deactivate
                '''

                // Run SonarQube analysis
                sh '''#!/bin/bash
                    sonar-scanner \
                        -Dsonar.projectKey=ecommerce-docker \
                        -Dsonar.sources=. \
                        -Dsonar.host.url=http://localhost:9000 \
                        -Dsonar.login=$SONAR_TOKEN \
                        -Dsonar.python.coverage.reportPaths=coverage.xml \
                        -Dsonar.exclusions=**/tests/**,**/*.json,**/*.yml || true
                '''
                
                // Run Trivy vulnerability scans
                sh '''
                    # Scan Dockerfiles
                    trivy config --severity HIGH,CRITICAL -f json -o reports/trivy_dockerfile_report.json . || true
                    
                    # Scan base images
                    trivy image --severity HIGH,CRITICAL -f json -o reports/trivy_python_image_report.json python:3.9 || true
                    trivy image --severity HIGH,CRITICAL -f json -o reports/trivy_node_image_report.json node:14 || true
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
                    
                    # Export the Python path to include the backend directory
                    export PYTHONPATH=$WORKSPACE/backend:$PYTHONPATH
                    
                    # Run Django migrations
                    cd backend
                    python manage.py makemigrations
                    python manage.py migrate
                    
                    # Run tests with proper Django settings
                    DJANGO_SETTINGS_MODULE=my_project.settings pytest account/tests.py --verbose --junit-xml ../test-reports/results.xml
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

                // Scan built images with Trivy
                sh '''
                    trivy image --severity HIGH,CRITICAL -f json -o reports/trivy_backend_report.json shafeekuralabs/ecommerce-backend:latest || true
                    trivy image --severity HIGH,CRITICAL -f json -o reports/trivy_frontend_report.json shafeekuralabs/ecommerce-frontend:latest || true
                '''
            }
        }

        stage('Infrastructure') {
            agent { label 'build-node' }
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
                                    -var="private_key_path=${TF_PRIVATE_KEY_PATH}" \
                                    -detailed-exitcode -out=tfplan 2>&1
                            """,
                            returnStatus: true
                        )
                        
                        // Check the exit code
                        if (planOutput == 0) {
                            echo "No infrastructure changes needed"
                        } else if (planOutput == 2) {
                            echo "Infrastructure changes detected"
                            sh """
                                terraform apply -auto-approve tfplan
                            """
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

        stage('Dynamic Application Security Testing') {
            agent { label 'build-node' }
            steps {
                script {
                    // Wait for application to be ready
                    sh 'sleep 20'
                    
                    // Run OWASP ZAP scan
                    sh '''
                        # Get the ALB DNS name from Terraform output
                        cd Terraform
                        ALB_URL=$(terraform output -raw frontend_url)
                        cd ..
                        
                        # Run ZAP scan in headless mode
                        /opt/zap/zap.sh -cmd \
                            -quickurl $ALB_URL \
                            -quickout reports/zap_scan_results.json \
                            -quickprogress || true
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