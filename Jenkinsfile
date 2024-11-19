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
                    python3 -m venv venv
                    source venv/bin/activate
                    pip install --upgrade pip
                    pip install -r backend/requirements.txt
                    deactivate
                '''
            }
        }

        stage('Security: Static Code Analysis') {
            agent { label 'build-node' }
            steps {
                sh '''#!/bin/bash
                    mkdir -p reports
                    
                    # Run static code analysis using SonarQube CLI
                    sonar-scanner \
                        -Dsonar.projectKey=ecommerce-docker \
                        -Dsonar.sources=. \
                        -Dsonar.host.url=http://localhost:9000 \
                        -Dsonar.login=${SONAR_TOKEN} || true
                        
                    # Save SonarQube results
                    curl -s http://localhost:9000/api/qualitygates/project_status?projectKey=ecommerce-docker > reports/sonar_report.json || true
                '''
                
                sh '''#!/bin/bash
                    if grep -q '"status":"ERROR"' reports/sonar_report.json; then
                        echo "WARNING: SonarQube quality gate failed"
                    fi
                '''
            }
        }

        stage('Security: Infrastructure as Code Scan') {
            agent { label 'build-node' }
            steps {
                sh '''#!/bin/bash
                    # Activate virtual environment
                    source venv/bin/activate
                    
                    # Install Checkov if not already installed
                    pip install checkov
                    
                    # Scan Terraform files and save report
                    checkov -d Terraform --framework terraform -o json > reports/checkov_report.json || true
                    
                    # Check for high severity issues
                    if grep -q '"severity": "HIGH"' reports/checkov_report.json; then
                        echo "WARNING: Checkov found high severity issues"
                    fi
                    
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
                    
                    # Create test reports directory
                    mkdir -p test-reports
                    
                    # Export Python path
                    export PYTHONPATH=$WORKSPACE/backend:$PYTHONPATH
                    
                    # Run Django migrations
                    cd backend
                    python manage.py makemigrations
                    python manage.py migrate
                    
                    # Run tests
                    DJANGO_SETTINGS_MODULE=my_project.settings pytest account/tests.py --verbose --junit-xml ../test-reports/results.xml
                    cd ..
                    
                    deactivate
                '''
            }
        }

        stage('Security: Container Scan') {
            agent { label 'build-node' }
            steps {
                sh '''#!/bin/bash
                    mkdir -p reports
                    
                    # Scan backend Dockerfile and dependencies
                    trivy config -f json -o reports/trivy_config_backend.json Dockerfile.backend || true
                    trivy fs -f json -o reports/trivy_fs_backend.json backend/ || true
                    
                    # Scan frontend Dockerfile and dependencies
                    trivy config -f json -o reports/trivy_config_frontend.json Dockerfile.frontend || true
                    trivy fs -f json -o reports/trivy_fs_frontend.json frontend/ || true
                    
                    # Check for critical vulnerabilities
                    for report in reports/trivy_*.json; do
                        if grep -q '"Severity": "CRITICAL"' "$report"; then
                            echo "WARNING: Critical vulnerabilities found in $report"
                        fi
                    done
                '''
            }
        }

        stage('Build & Push Images') {
            agent { label 'build-node' }
            steps {
                sh '''
                    echo ${DOCKER_CREDS_PSW} | docker login -u ${DOCKER_CREDS_USR} --password-stdin
                    
                    docker build -t shafeekuralabs/ecommerce-backend:latest -f Dockerfile.backend .
                    docker push shafeekuralabs/ecommerce-backend:latest
                    
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
                TF_PRIVATE_KEY_PATH = credentials('terraform-private-key-path')
            }
            steps {
                dir('Terraform') {
                    script {
                        sh 'terraform init'
                        
                        def planExitCode = sh(
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
                        
                        if (planExitCode == 0) {
                            echo "No infrastructure changes needed"
                        } else if (planExitCode == 2) {
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

        stage('Security: Dynamic Application Scan') {
            agent { label 'build-node' }
            steps {
                sh '''#!/bin/bash
                    # Allow application to stabilize
                    sleep 120
                    
                    # Get ALB DNS from Terraform output
                    cd Terraform
                    ALB_DNS=$(terraform output -raw alb_dns_name)
                    cd ..
                    
                    # Create reports directory
                    mkdir -p reports
                    
                    # Run OWASP ZAP scan
                    /opt/zap/zap-baseline.py -t http://${ALB_DNS} \
                        -r reports/zap_report.html \
                        -J reports/zap_report.json \
                        -I || true
                    
                    # Check for high risk findings
                    if grep -q '"risk": "High"' reports/zap_report.json; then
                        echo "WARNING: ZAP found high risk vulnerabilities"
                    fi
                '''
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
                
                // Archive reports directory
                sh 'if [ -d "reports" ]; then tar -czf security-reports.tar.gz reports/; fi'
                archiveArtifacts artifacts: '**/*reports.tar.gz', allowEmptyArchive: true
                
                cleanWs()
            }
        }
    }
}