pipeline {
    agent none

    environment {
        DOCKER_CREDS = credentials('docker-hub-credentials')
        DJANGO_SETTINGS_MODULE = 'my_project.settings'
        PYTHONPATH = 'backend'
        WORKSPACE_VENV = './venv'
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

        stage('Security Scan - Infrastructure') {
            agent { label 'build-node' }
            steps {
                sh '''#!/bin/bash
                    # Create reports directory if it doesn't exist
                    mkdir -p reports

                    # Add security tools to PATH
                    export PATH=$PATH:/home/ubuntu/security-venv/bin:/opt/sonar-scanner/bin
                    
                    # Run Checkov on Terraform files
                    source /home/ubuntu/security-venv/bin/activate
                    checkov -d Terraform -o json > reports/checkov_report.json || true
                    deactivate
                '''
            }
        }

        stage('Security Scan - Dependencies') {
            agent { label 'build-node' }
            steps {
                sh '''#!/bin/bash
                    # Scan Python dependencies
                    trivy fs --security-checks vuln --severity HIGH,CRITICAL -f json -o reports/trivy_dependencies.json backend/requirements.txt || true
                    
                    # Scan Node.js dependencies
                    trivy fs --security-checks vuln --severity HIGH,CRITICAL -f json -o reports/trivy_node_dependencies.json frontend/package.json || true
                '''
            }
        }

        stage('SonarQube Analysis') {
            agent { label 'build-node' }
            steps {
                withEnv(["JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64"]) {
                    sh '''
                        export PATH=$PATH:/opt/sonar-scanner/bin
                        sonar-scanner \
                            -Dsonar.projectKey=ecommerce \
                            -Dsonar.sources=. \
                            -Dsonar.host.url=http://localhost:9000 \
                            -Dsonar.login=$SONAR_TOKEN \
                            -Dsonar.java.binaries=.
                    '''
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
                sh '''
                    # Login to DockerHub
                    echo ${DOCKER_CREDS_PSW} | docker login -u ${DOCKER_CREDS_USR} --password-stdin
                    
                    # Build backend image
                    docker build -t shafeekuralabs/ecommerce-backend:latest -f Dockerfile.backend .
                    
                    # Scan backend image for vulnerabilities
                    trivy image --severity HIGH,CRITICAL -f json -o reports/trivy_backend_image.json shafeekuralabs/ecommerce-backend:latest || true
                    
                    # Push backend image
                    docker push shafeekuralabs/ecommerce-backend:latest
                    
                    # Build frontend image
                    docker build -t shafeekuralabs/ecommerce-frontend:latest -f Dockerfile.frontend .
                    
                    # Scan frontend image for vulnerabilities
                    trivy image --severity HIGH,CRITICAL -f json -o reports/trivy_frontend_image.json shafeekuralabs/ecommerce-frontend:latest || true
                    
                    # Push frontend image
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

        stage('OWASP ZAP Scan') {
            agent { label 'build-node' }
            steps {
                script {
                    // Wait for application to be ready
                    sleep(time: 60, unit: 'SECONDS')
                    
                    // Get the ALB DNS from Terraform output
                    dir('Terraform') {
                        def albDns = sh(
                            script: 'terraform output -raw alb_dns_name',
                            returnStdout: true
                        ).trim()
                        
                        // Run ZAP scan
                        sh """
                            /opt/zap/zap.sh -cmd \
                                -quickurl http://${albDns} \
                                -quickout reports/zap_scan_results.json \
                                -quickprogress || true
                        """
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
                archiveArtifacts artifacts: 'reports/**/*.json', allowEmptyArchive: true
            }
        }
        success {
            node('build-node') {
                echo "Pipeline completed successfully! Security reports are available in the artifacts."
            }
        }
    }
}