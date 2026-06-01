pipeline {
    agent any
    
    environment {
        // Updated with your explicit AWS Registry details
        AWS_ACCOUNT_ID = '951151046739' 
        AWS_REGION     = 'ap-south-1'
        ECR_REPO_NAME  = 'spring-boot-app'
        CLUSTER_NAME   = 'confused-classical-dolphin'
        
        // Dynamic image definition tag
        IMAGE_TAG      = "build-${BUILD_NUMBER}"
        ECR_REGISTRY   = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
        FULL_IMAGE_URI = "${ECR_REGISTRY}/${ECR_REPO_NAME}:${IMAGE_TAG}"
    }

    stages {
        stage('Checkout Code') {
            steps {
                // Pulls the matching branch configuration from your GitHub project
                checkout scm
            }
        }

        stage('Build & Tag Docker Image') {
            steps {
                script {
                    echo "Building multi-stage production image: ${FULL_IMAGE_URI}"
                    // Leverages the Maven caching optimization written inside your Dockerfile
                    sh "docker build -t ${FULL_IMAGE_URI} ."
                }
            }
        }

        stage('Push Image to Amazon ECR') {
            steps {
                // Scope securely injects AWS keys to execute inside the wrapper
                withCredentials([[
                    $class: 'AmazonWebServicesCredentialsBinding', 
                    credentialsId: 'aws-credentials-id'
                ]]) {
                    script {
                        echo "Authenticating Docker CLI daemon with ECR..."
                        sh "aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_REGISTRY}"
                        
                        echo "Pushing built image to ECR..."
                        sh "docker push ${FULL_IMAGE_URI}"
                    }
                }
            }
        }

        stage('Deploy to AWS EKS') {
            steps {
                withCredentials([[
                    $class: 'AmazonWebServicesCredentialsBinding', 
                    credentialsId: 'aws-credentials-id'
                ]]) {
                    script {
                        echo "Generating secure local kubeconfig for cluster context..."
                        sh "aws eks update-kubeconfig --region ${AWS_REGION} --name ${CLUSTER_NAME}"
                        
                        echo "Updating deployment manifest references with tag: ${IMAGE_TAG}"
                        // Replaces the placeholder text dynamically inside the YAML file
                        sh "sed -i 's|IMAGE_PLACEHOLDER|${IMAGE_TAG}|g' k8s/deployment.yaml"
                        
                        echo "Applying deployment and services resources to EKS..."
                        sh "kubectl apply -f k8s/deployment.yaml"
                        sh "kubectl apply -f k8s/service.yaml"
                    }
                }
            }
        }

        stage('Verify Deployment Status') {
            steps {
                script {
                    echo "Checking tracking status of active rollout..."
                    sh "kubectl rollout status deployment/spring-boot-app --timeout=90s"
                    
                    echo "Displaying active cluster access details:"
                    sh "kubectl get svc spring-boot-service"
                }
            }
        }
    }

    post {
        always {
            echo "Cleaning workspace lingering images..."
            sh "docker rmi ${FULL_IMAGE_URI} --force || true"
        }
        success {
            echo "Spring Boot Application successfully deployed to EKS!"
        }
        failure {
            echo "Pipeline compilation or deployment run failed. Review logs above."
        }
    }
}