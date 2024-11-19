pipeline {
    agent none

    environment {
        DOCKER_CREDS = credentials('docker-hub-credentials')
        DJANGO_SETTINGS_MODULE = 'my_project.settings'
        PYTHONPATH = 'backend'
        WORKSPACE_VENV = './venv'
        SONAR_TOKEN = credentials('sonar-token')
        SONAR_PROJECT_KEY = 'ecommerce-app'
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
        parallel {
            stage('SonarQube Analysis') {
                agent { label 'build-node' }
                steps {
                    sh '''
                        sonar-scanner \
                        -Dsonar.projectKey=$SONAR_PROJECT_KEY \
                        -Dsonar.sources=. \
                        -Dsonar.host.url=http://localhost:9000 \
                        -Dsonar.login=$SONAR_TOKEN \
                        -Dsonar.python.coverage.reportPaths=coverage.xml \
                        -Dsonar.exclusions=**/tests/**,**/migrations/**
                    '''
                }
            }
            
            stage('Checkov Infrastructure Scan') {
                agent { label 'build-node' }
                steps {
                    sh '''
                        source /opt/security-tools-venv/bin/activate
                        mkdir -p reports
                        checkov -d Terraform -o json > reports/checkov_report.json || true
                        deactivate
                    '''
                }
            }
            
            stage('Trivy Image Scan') {
                agent { label 'build-node' }
                steps {
                    sh '''
                        mkdir -p reports
                        # Scan backend image dependencies
                        trivy fs --format json -o reports/trivy_backend_deps.json backend/requirements.txt
                        # Scan frontend image dependencies
                        trivy fs --format json -o reports/trivy_frontend_deps.json frontend/package.json
                        # Scan Dockerfiles
                        trivy config --format json -o reports/trivy_dockerfiles.json .
                    '''
                }
            }
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

        stage('Build & Push Images') {
            agent { label 'build-node' }
            steps {
                // login to DockerHub
                sh 'echo ${DOCKER_CREDS_PSW} | docker login -u ${DOCKER_CREDS_USR} --password-stdin'
                
                // build and push backend
                sh '''
                    docker build -t shafeekuralabs/ecommerce-backend:latest -f Dockerfile.backend .
                    trivy image --format json -o reports/trivy_backend_image.json shafeekuralabs/ecommerce-backend:latest
                    docker push shafeekuralabs/ecommerce-backend:latest
                '''
                
                // build and push frontend
                sh '''
                    docker build -t shafeekuralabs/ecommerce-frontend:latest -f Dockerfile.frontend .
                    trivy image --format json -o reports/trivy_frontend_image.json shafeekuralabs/ecommerce-frontend:latest
                    docker push shafeekuralabs/ecommerce-frontend:latest
                '''
            }
        }

        stage('Infrastructure') {
            agent { label 'build-node' }
            environment {
                TF_DB_PASSWORD = credentials('terraform-db-password')
                TF_KEY_NAME = credentials('terraform-key-name')
                TF_PRIVATE_KEY_PATH = credentials('terraform-private-key-path')
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

        stage('Dynamic Security Testing') {
            agent { label 'build-node' }
            steps {
                script {
                    // Wait for application to be ready
                    sh 'sleep 60' 
                    
                    // Run OWASP ZAP scan
                    sh '''
                        mkdir -p reports
                        
                        # Get the ALB DNS name from Terraform output
                        cd Terraform
                        ALB_URL=$(terraform output -raw alb_dns_name)
                        cd ..
                        
                        # Run ZAP scan against the application
                        /opt/zap/zap.sh -cmd \
                            -quickurl http://$ALB_URL \
                            -quickprogress \
                            -quickout reports/zap_scan_results.json
                    '''
                }
            }
        }
    }

    post {
        always {
            node('build-node') {
                // Archive security reports
                archiveArtifacts artifacts: 'reports/**/*.*', allowEmptyArchive: true
                
                // Cleanup
                sh '''
                    docker logout
                    docker system prune -f
                '''
            }
        }
    }
}