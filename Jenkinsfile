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

        stage('Security: Code Analysis') {
            agent { label 'build-node' }
            steps {
                // Create reports directory
                sh 'mkdir -p reports'
                
                // Run SonarQube Analysis
                withSonarQubeEnv('SonarQubeServer') {
                    sh '''
                        sonar-scanner \
                            -Dsonar.projectKey=ecommerce-docker \
                            -Dsonar.sources=. \
                            -Dsonar.host.url=http://localhost:9000 \
                            -Dsonar.login=$SONAR_TOKEN
                    '''
                }
                
                // Quality Gate check
                timeout(time: 5, unit: 'MINUTES') {
                    waitForQualityGate abortPipeline: true
                }
            }
        }

        stage('Security: Infrastructure as Code Scan') {
            agent { label 'build-node' }
            steps {
                sh '''#!/bin/bash
                    # Activate virtual environment and run Checkov
                    source venv/bin/activate
                    
                    # Scan Terraform files
                    checkov -d Terraform --framework terraform --output json > reports/checkov_report.json
                    
                    deactivate
                '''
                
                // Analyze Checkov results and fail if high severity issues found
                script {
                    def checkovReport = readJSON file: 'reports/checkov_report.json'
                    def highSeverityCount = checkovReport.summary.failed
                    if (highSeverityCount > 0) {
                        error "Checkov found ${highSeverityCount} high severity issues"
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

        stage('Security: Container Scan') {
            agent { label 'build-node' }
            steps {
                sh '''
                    # Scan Backend Dockerfile and dependencies
                    trivy config -f json -o reports/trivy_config_backend.json Dockerfile.backend
                    trivy fs -f json -o reports/trivy_fs_backend.json backend/
                    
                    # Scan Frontend Dockerfile and dependencies
                    trivy config -f json -o reports/trivy_config_frontend.json Dockerfile.frontend
                    trivy fs -f json -o reports/trivy_fs_frontend.json frontend/
                '''
                
                // Analyze Trivy results
                script {
                    def trivyReports = [
                        readJSON(file: 'reports/trivy_config_backend.json'),
                        readJSON(file: 'reports/trivy_fs_backend.json'),
                        readJSON(file: 'reports/trivy_config_frontend.json'),
                        readJSON(file: 'reports/trivy_fs_frontend.json')
                    ]
                    
                    def highSeverityIssues = trivyReports.sum { report ->
                        report.Results.sum { result ->
                            result.Vulnerabilities?.count { vuln ->
                                vuln.Severity in ['HIGH', 'CRITICAL']
                            } ?: 0
                        }
                    }
                    
                    if (highSeverityIssues > 0) {
                        error "Trivy found ${highSeverityIssues} high/critical severity issues"
                    }
                }
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

        stage('Security: Dynamic Application Scan') {
            agent { label 'build-node' }
            steps {
                script {
                    // Wait for application to be ready
                    sleep(time: 2, unit: 'MINUTES')
                    
                    // Get ALB DNS from Terraform output
                    dir('Terraform') {
                        def albDns = sh(
                            script: 'terraform output -raw alb_dns_name',
                            returnStdout: true
                        ).trim()
                        
                        // Run OWASP ZAP scan
                        sh """
                            mkdir -p reports
                            /opt/zap/zap-baseline.py -t http://${albDns} \
                                -r reports/zap_report.html \
                                -J reports/zap_report.json \
                                -I
                        """
                    }
                }
                
                // Analyze ZAP results
                script {
                    def zapReport = readJSON file: 'reports/zap_report.json'
                    def highAlerts = zapReport.site[0].alerts.count { alert ->
                        alert.riskcode >= 3  // High or Critical severity
                    }
                    
                    if (highAlerts > 0) {
                        error "OWASP ZAP found ${highAlerts} high/critical severity issues"
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
                
                // Archive security reports
                archiveArtifacts artifacts: 'reports/**/*', allowEmptyArchive: true
                
                // Clean workspace
                cleanWs()
            }
        }
    }
}