pipeline {

    agent any

    environment {

        PATH = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

        AWS_REGION = 'ap-south-1'
        REGISTRY_ID = '951151046739'
        REPOSITORY_NAME = 'spring-boot-app'
        IMAGE_TAG = "${BUILD_NUMBER}"

        ECR_URI = "${REGISTRY_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${REPOSITORY_NAME}"

        EKS_CLUSTER = 'hilarious-alternative-outfit'
        K8S_NAMESPACE = 'default'
        DEPLOYMENT_NAME = 'spring-boot-app'
        CONTAINER_NAME = 'spring-boot-app'
    }

    stages {

        stage('Check Environment') {
            steps {
                sh '''
                whoami
                echo $PATH
                which docker || true
                docker --version
                aws --version
                kubectl version --client || true
                '''
            }
        }

        stage('Git Checkout') {
            steps {
                git branch: 'main',
                    credentialsId: 'github-token',
                    url: 'https://github.com/jayadeepchowdary7/aws.git'
            }
        }
        
        stage('Build & Tag Docker Image') {
            steps {
                sh """
                docker buildx create --use --name multiarch-builder || true

                docker buildx build \
                --platform linux/amd64 \
                -t ${REPOSITORY_NAME}:${IMAGE_TAG} \
                --load .

                docker tag \
                ${REPOSITORY_NAME}:${IMAGE_TAG} \
                ${ECR_URI}:${IMAGE_TAG}
                """
            }
        }

        stage('Login to Amazon ECR') {
            steps {
                withCredentials([
                    [$class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: 'aws-credentials']
                ]) {
                    sh """
                    aws ecr get-login-password --region ${AWS_REGION} | \
                    docker login --username AWS --password-stdin \
                    ${REGISTRY_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com
                    """
                }
            }
        }

        stage('Push Docker Image') {
            steps {
                sh """
                docker push ${ECR_URI}:${IMAGE_TAG}
                """
            }
        }

        stage('Configure kubectl for EKS') {
            steps {
                withCredentials([
                    [$class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: 'aws-credentials']
                ]) {
                    sh """
                    aws eks update-kubeconfig \
                    --region ${AWS_REGION} \
                    --name ${EKS_CLUSTER}

                    kubectl get nodes
                    """
                }
            }
        }

        stage('Deploy to AWS EKS') {
            steps {
                sh """
                echo "Applying Kubernetes manifests..."

                # Replace IMAGE_PLACEHOLDER with the actual image URI and apply
                sed -e "s|IMAGE_PLACEHOLDER|${ECR_URI}:${IMAGE_TAG}|g" k8s/deployment.yaml | \
                    kubectl apply -f -

                kubectl apply -f k8s/service.yaml
                kubectl apply -f k8s/servicemonitor.yaml

                # Trigger a rolling restart to ensure the new image is pulled
                kubectl rollout restart deployment/${DEPLOYMENT_NAME} -n ${K8S_NAMESPACE} || true
                """
            }
        }

        stage('Verify Deployment Status') {
            steps {
                sh """
                kubectl rollout status deployment/${DEPLOYMENT_NAME} \
                -n ${K8S_NAMESPACE} --timeout=300s

                echo "========== DEPLOYMENTS =========="
                kubectl get deployments -n ${K8S_NAMESPACE}

                echo "========== PODS =========="
                kubectl get pods -o wide -n ${K8S_NAMESPACE}

                echo "========== SERVICES =========="
                kubectl get svc -n ${K8S_NAMESPACE}
                """
            }
        }
    }
}
