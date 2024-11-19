pipeline {
    agent none

    environment {
        DOCKER_CREDS = credentials('docker-hub-credentials')
        DJANGO_SETTINGS_MODULE = 'my_project.settings'
        PYTHONPATH = "${WORKSPACE}/backend:${PYTHONPATH}"
        WORKSPACE_VENV = "${WORKSPACE}/venv"
        TF_DB_PASSWORD = credentials('terraform-db-password')
        TF_KEY_NAME = credentials('terraform-key-name')
        TF_PRIVATE_KEY_PATH = credentials('terraform-private-key-path')
        SONAR_TOKEN = credentials('sonar-token')
    }

    stages {
        stage('Initialize') {
            agent { label 'build-node' }
            steps {
                // Clean workspace while preserving terraform state
                sh '''
                    git clean -ffdx -e "*.tfstate*" -e ".terraform/*"
                    mkdir -p reports test-reports
                '''

                // Create Python virtual environment
                sh '''#!/bin/bash
                    python3.9 -m venv venv
                    . venv/bin/activate
                    
                    # Install build dependencies
                    python -m pip install --upgrade pip setuptools wheel
                    python -m pip install distutils-extra
                    
                    # Install project and test dependencies
                    pip install -r backend/requirements.txt
                    pip install pytest pytest-django coverage pytest-cov checkov
                    
                    deactivate
                '''
            }
        }

        stage('Security Scans') {
            agent { label 'build-node' }
            parallel {
                stage('Infrastructure Security') {
                    steps {
                        sh '''#!/bin/bash
                            source venv/bin/activate
                            
                            # Run Checkov for IaC scanning
                            echo "Running Checkov scan on Terraform files..."
                            checkov -d Terraform -o json > reports/checkov_report.json || true
                            
                            # Scan Dockerfiles and infrastructure files
                            echo "Running Trivy scan on configuration files..."
                            trivy config --severity HIGH,CRITICAL -f json -o reports/trivy_config_report.json . || true
                            
                            deactivate
                        '''
                    }
                }
                
                stage('Base Image Security') {
                    steps {
                        sh '''
                            # Scan base images
                            echo "Running Trivy scan on Python base image..."
                            trivy image --severity HIGH,CRITICAL -f json -o reports/trivy_python_image_report.json python:3.9 || true
                            
                            echo "Running Trivy scan on Node base image..."
                            trivy image --severity HIGH,CRITICAL -f json -o reports/trivy_node_image_report.json node:14 || true
                        '''
                    }
                }

                stage('SonarQube Analysis') {
                    steps {
                        sh '''#!/bin/bash
                            source venv/bin/activate
                            
                            # Run backend tests with coverage for SonarQube
                            cd backend
                            coverage run -m pytest
                            coverage xml -o ../coverage.xml
                            cd ..
                            
                            # Run SonarQube analysis
                            sonar-scanner \
                                -Dsonar.projectKey=ecommerce-docker \
                                -Dsonar.sources=. \
                                -Dsonar.host.url=http://localhost:9000 \
                                -Dsonar.login=$SONAR_TOKEN \
                                -Dsonar.python.coverage.reportPaths=coverage.xml \
                                -Dsonar.exclusions=**/tests/**,**/*.json,**/*.yml,**/migrations/** || true
                            
                            deactivate
                        '''
                    }
                }
            }
        }

        stage('Test') {
            agent { label 'build-node' }
            steps {
                sh '''#!/bin/bash
                    source venv/bin/activate
                    
                    # Set up test database
                    cd backend
                    python manage.py migrate --noinput
                    
                    # Run tests with coverage and generate reports
                    pytest \
                        --junitxml=../test-reports/junit.xml \
                        --cov=. \
                        --cov-report=xml:../test-reports/coverage.xml \
                        --cov-report=html:../test-reports/coverage-html \
                        tests/
                    
                    cd ..
                    deactivate
                '''
            }
            post {
                always {
                    junit 'test-reports/junit.xml'
                    publishHTML([
                        allowMissing: false,
                        alwaysLinkToLastBuild: true,
                        keepAll: true,
                        reportDir: 'test-reports/coverage-html',
                        reportFiles: 'index.html',
                        reportName: 'Coverage Report'
                    ])
                }
            }
        }

        stage('Build & Push Images') {
            agent { label 'build-node' }
            steps {
                script {
                    // Login to DockerHub
                    sh '''
                        echo $DOCKER_CREDS_PSW | docker login -u $DOCKER_CREDS_USR --password-stdin
                    '''
                    
                    // Build and push backend image
                    sh '''
                        echo "Building backend image..."
                        docker build -t $DOCKER_CREDS_USR/ecommerce-backend:latest -f Dockerfile.backend .
                        
                        echo "Scanning backend image..."
                        trivy image --severity HIGH,CRITICAL -f json -o reports/trivy_backend_report.json $DOCKER_CREDS_USR/ecommerce-backend:latest || true
                        
                        echo "Pushing backend image..."
                        docker push $DOCKER_CREDS_USR/ecommerce-backend:latest
                    '''
                    
                    // Build and push frontend image
                    sh '''
                        echo "Building frontend image..."
                        docker build -t $DOCKER_CREDS_USR/ecommerce-frontend:latest -f Dockerfile.frontend .
                        
                        echo "Scanning frontend image..."
                        trivy image --severity HIGH,CRITICAL -f json -o reports/trivy_frontend_report.json $DOCKER_CREDS_USR/ecommerce-frontend:latest || true
                        
                        echo "Pushing frontend image..."
                        docker push $DOCKER_CREDS_USR/ecommerce-frontend:latest
                    '''
                }
            }
        }

        stage('Deploy Infrastructure') {
            agent { label 'build-node' }
            steps {
                dir('Terraform') {
                    script {
                        // Initialize Terraform
                        sh 'terraform init'
                        
                        // Run terraform plan and save the output
                        def planExitCode = sh(
                            script: """
                                terraform plan \
                                    -var="dockerhub_username=${DOCKER_CREDS_USR}" \
                                    -var="dockerhub_password=${DOCKER_CREDS_PSW}" \
                                    -var="db_password=${TF_DB_PASSWORD}" \
                                    -var="key_name=${TF_KEY_NAME}" \
                                    -var="private_key_path=${TF_PRIVATE_KEY_PATH}" \
                                    -detailed-exitcode -out=tfplan || true
                            """,
                            returnStatus: true
                        )
                        
                        // Check plan exit code and apply if changes are needed
                        if (planExitCode == 0) {
                            echo "No infrastructure changes needed"
                        } else if (planExitCode == 2) {
                            echo "Infrastructure changes detected, applying..."
                            sh "terraform apply -auto-approve tfplan"
                        } else {
                            error "Terraform plan failed"
                        }
                    }
                }
            }
            post {
                success {
                    dir('Terraform') {
                        // Backup terraform state
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
                    
                    // Get application URL and run OWASP ZAP scan
                    sh '''#!/bin/bash
                        # Get ALB DNS name from Terraform output
                        cd Terraform
                        ALB_URL=$(terraform output -raw alb_dns_name)
                        cd ..
                        
                        echo "Running OWASP ZAP scan against http://${ALB_URL}"
                        
                        # Run ZAP scan in headless mode
                        /opt/zap/zap.sh -cmd \
                            -quickurl "http://${ALB_URL}" \
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
                // Clean up Docker
                sh '''
                    docker logout
                    docker system prune -f
                '''
                
                // Archive reports and artifacts
                archiveArtifacts(
                    artifacts: 'reports/**/*,test-reports/**/*,Terraform/terraform-states/**/*',
                    allowEmptyArchive: true,
                    fingerprint: true
                )
                
                // Clean up workspace except Terraform state
                sh 'git clean -ffdx -e "*.tfstate*" -e ".terraform/*"'
            }
        }
        
        success {
            node('build-node') {
                // Send success notification
                echo "Pipeline completed successfully!"
            }
        }
        
        failure {
            node('build-node') {
                // Send failure notification
                echo "Pipeline failed! Check the logs for details."
            }
        }
    }
}