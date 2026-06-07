# Deployment Guide: Spring Boot Application on AWS EKS

This guide provides detailed, step‑by‑step instructions for deploying the Spring Boot application to an AWS Elastic Kubernetes Service (EKS) cluster, including prerequisites, configuration, and verification.

---

## Table of Contents
1. [Prerequisites](#prerequisites)
2. [Initial Setup](#initial-setup)
3. [ECR Repository Setup](#ecr-repository-setup)
4. [EKS Cluster Setup](#eks-cluster-setup)
5. [Building and Publishing the Docker Image](#building-and-publishing-the-docker-image)
6. [Deploying to EKS](#deploying-to-eks)
7. [Setting Up Monitoring (Prometheus + Grafana)](#setting-up-monitoring-prometheus--grafana)
8. [Verification and Testing](#verification-and-testing)
9. [Troubleshooting Tips](#troubleshooting-tips)
10. [GitOps with Argo CD](#gitops-with-argo-cd)
---

## Prerequisites

Before you begin, ensure you have the following tools and accounts configured:

| Tool / Account | Minimum Version / Details | Installation / Setup |
|----------------|---------------------------|----------------------|
| **AWS Account** | With permissions to create ECR, EKS, IAM roles, and VPC resources | Sign up at [aws.amazon.com](https://aws.amazon.com/) |
| **AWS CLI** | v2.x | `curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && unzip awscliv2.zip && sudo ./aws/install` |
| **kubectl** | v1.27+ (match your EKS cluster version) | `curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"` |
| **helm** | v3.12+ | `curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash` |
| **docker** | v24.0+ | Follow instructions at [docs.docker.com/engine/install/](https://docs.docker.com/engine/install/) |
| **git** | v2.30+ | `sudo apt-get install git` (Linux) or [download](https://git-scm.com/downloads) |
| **Java JDK** | 21 (for local build/testing) | AdoptOpenJDK/Eclipse Temurin: https://adoptium.net/ |
| **Maven** | 3.8+ | `sudo apt-get install maven` or [download](https://maven.apache.org/download.cgi) |
| **IAM User/Programmatic Access** | With policies: `AmazonEC2ContainerRegistryFullAccess`, `AmazonEKSClusterPolicy`, `AmazonEKSWorkerNodePolicy`, `AmazonEKS_CNI_Policy`, `AmazonEKSServicePolicy` | Create via IAM console or CLI |

> **Note**: If you are using an existing EKS cluster, ensure your IAM user/role has `system:masters` or sufficient RBAC permissions to deploy resources.

---

## Initial Setup

### 1. Clone the Repository
```bash
git clone https://github.com/jayadeepchowdary7/aws.git
cd aws
```

### 2. Configure AWS CLI
```bash
aws configure
```
Provide:
- AWS Access Key ID
- AWS Secret Access Key
- Default region (e.g., `ap-south-1`)
- Default output format (`json`)

Verify:
```bash
aws sts get-caller-identity
```

### 3. Set Environment Variables (optional but helpful)
```bash
export AWS_REGION=ap-south-1
export ECR_REGISTRY_ID=$(aws sts get-caller-identity --query Account --output text)
export REPOSITORY_NAME=spring-boot-app
export ECR_URI="${ECR_REGISTRY_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${REPOSITORY_NAME}"
export EKS_CLUSTER_NAME=hilarious-alternative-outfit   # from your Jenkinsfile
export K8S_NAMESPACE=default
```

---

## AWS Resources Preparation

### 1. Create the ECR Repository
```bash
aws ecr create-repository \
    --repository-name ${REPOSITORY_NAME} \
    --region ${AWS_REGION} \
    --image-scanning-configuration scanOnPush=true \
    --image-tag-mutability MUTABLE
```
> **Output**: Note the `repositoryUri` (should match `${ECR_URI}`).

### 2. Ensure EKS Cluster Exists
If you already have an EKS cluster (as referenced in Jenkinsfile), skip this step. Otherwise:

#### Create EKS Cluster (using `eksctl` - recommended)
```bash
# Install eksctl if not present
curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
sudo mv /tmp/eksctl /usr/local/bin

#### Step 1: Define the Variables
# Run these commands in your terminal to set your cluster name and region. Replace my-cool-cluster and us-east-1 with your actual desired values.
```bash
export EKS_CLUSTER_NAME="my-cool-cluster"
export AWS_REGION="us-east-1"
#### Step 2: Verify the Variables
# Before launching a process that takes 15–20 minutes, it is always a good idea to double-check that your terminal actually sees the variables:
```bash
echo "Cluster Name: ${EKS_CLUSTER_NAME}"
echo "Region: ${AWS_REGION}"
Step 3: Run Your Command

# Create cluster
eksctl create cluster \
    --name ${EKS_CLUSTER_NAME} \
    --region ${AWS_REGION} \
    --nodegroup-name standard-workers \
    --node-type t3.micro \
    --nodes 3 \
    --nodes-min 1 \
    --nodes-max 4 \
    --managed
```

#### Configure kubectl for the Cluster
```bash
aws eks update-kubeconfig --region ${AWS_REGION} --name ${EKS_CLUSTER_NAME}
kubectl get nodes   # should show your worker nodes
```

### 3. Create IAM Role for Jenkins/EKS (if not using existing)
The Jenkins pipeline uses credentials ID `aws-credentials`. Ensure this refers to an IAM user/role with:
- `AmazonEC2ContainerRegistryFullAccess`
- `AmazonEKSClusterPolicy`
- `AmazonEKSWorkerNodePolicy`
- `AmazonEKS_CNI_Policy`
- `AmazonEKSServicePolicy`
- `AmazonVPCFullAccess` (or scoped to your VPC)

Store the access key/secret in Jenkins under **Credentials** → **AWS Credentials** with ID `aws-credentials`.

---

## Building and Publishing the Docker Image

You can build and push the image either via Jenkins (as configured) or manually for testing.

### Option A: Using Jenkins (Recommended for CI/CD)
1. Ensure Jenkins is configured with:
   - **AWS Credentials** (`aws-credentials`)
   - **GitHub Token** (`github-token`) for checking out the repo
   - Docker and kubectl installed on the Jenkins agent
2. Trigger the pipeline (e.g., via GitHub webhook or manually).
3. The pipeline will:
   - Check out the code
   - Build the Docker image (multi‑arch, Linux/amd64)
   - Tag it as `${ECR_URI}:${BUILD_NUMBER}`
   - Push to ECR
   - Apply Kubernetes manifests (deployment, service, ServiceMonitor)
   - Restart the deployment to pull the new image

### Option B: Manual Build & Push (for testing)
```bash
# 1. Log in to ECR
aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_URI}

# 2. Build the Docker image (uses Java 21 base images)
docker build -t ${REPOSITORY_NAME}:latest .

# 3. Tag the image for ECR
docker tag ${REPOSITORY_NAME}:latest ${ECR_URI}:latest

# 4. Push the image
docker push ${ECR_URI}:latest
```

---

## Deploying to EKS

The Jenkins pipeline handles deployment via `kubectl apply`. If you prefer to deploy manually:

### 1. Prepare Kubernetes Manifests
Ensure you have the following files in the `k8s/` directory:
- `deployment.yaml` – Defines the Deployment with replica count, image placeholder, liveness/readiness probes.
- `service.yaml` – Exposes the app via a LoadBalancer (port 80 → 8080) and metrics port (8080 → 8080).
- `servicemonitor.yaml` – Instructs Prometheus to scrape `/actuator/prometheus`.

### 2. Apply the Manifests
```bash
# Replace the IMAGE_PLACEHOLDER with the actual image URI
export IMAGE_TAG=latest   # or a specific version like 1
sed -e "s|IMAGE_PLACEHOLDER|${ECR_URI}:${IMAGE_TAG}|g" k8s/deployment.yaml | kubectl apply -f -

kubectl apply -f k8s/service.yaml
kubectl apply -f k8s/servicemonitor.yaml   # if using Prometheus
```

### 3. Verify the Deployment
```bash
kubectl get deployments
kubectl get pods
kubectl get svc spring-boot-service   # note the EXTERNAL-IP or hostname
```

### 4. Access the Application
Once the LoadBalancer provisions an external IP (may take 1-2 minutes):
```bash
export LB_HOSTNAME=$(kubectl get svc spring-boot-service -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "Application URL: http://${LB_HOSTNAME}/api/employees"
```
Test the API:
```bash
curl -s http://${LB_HOSTNAME}/api/employees   # should return [] (empty list) or existing employees
curl -X POST -H "Content-Type: application/json" -d '{"name":"John Doe","role":"Developer"}' http://${LB_HOSTNAME}/api/employees
```

---

## Setting Up Monitoring (Prometheus + Grafana)

The repo includes configurations for Prometheus scraping. Follow the steps below to get a full monitoring stack.

### Option B: Recommended – Install the kube-prometheus-stack Helm Chart

```bash
# 1. Add Helm repository
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# 2. Install the stack (includes Prometheus, Grafana, Alertmanager, node-exporter, etc.)
helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --set grafana.adminPassword=prom-operator \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false
```

> **Why this chart?** It automatically discovers ServiceMonitors (like the one we added) and starts scraping.

### 3. Access Grafana
```bash
# Port‑forward for local access
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80
```
Open <http://localhost:3000> in a browser:
- Username: `admin`
- Password: `prom-operator` (or the password you set)

### 4. Import the JVM Dashboard
1. Click **+ → Import**
2. Enter **Dashboard ID: 4701** (JVM Micrometer)
3. Click **Load**
4. Ensure the data source is set to **Prometheus**
5. Click **Import**

You will now see panels for:
- JVM memory usage (heap/non-heap)
- Garbage collection (GC count & time)
- Thread counts
- HTTP request rates, durations, and error percentages
- Spring Boot specific metrics (beans, cache, datasource)

### 5. Verify Scraping
In Grafana → Explore → Prometheus, try a query:
```
http_server_requests_seconds_count{app="spring-boot-app"}
```
or
```
jvm_memory_used_bytes{area="heap"}
```
You should see time‑series data if the application is running and the ServiceMonitor is applied.

---

## Verification and Testing

### 1. Health Check Endpoints
```bash
curl -s http://${LB_HOSTNAME}/actuator/health   # should return {"status":"UP"}
curl -s http://${LB_HOSTNAME}/actuator/health/liveness
curl -s http://${LB_HOSTNAME}/actuator/health/readiness
```

### 2. Metrics Endpoint
```bash
curl -s http://${LB_HOSTNAME}:8080/actuator/prometheus | head -20
```
You should see lines like:
```
# HELP jvm_memory_used_bytes Used memory
# TYPE jvm_memory_used_bytes gauge
jvm_memory_used_bytes{area="heap",id="PS Survivor Space",} 1.234E6
```

### 3. API Functionality
Create, read, update, delete employees via the REST API:
```bash
# Create
curl -X POST -H "Content-Type: application/json" -d '{"name":"Alice","role":"QA"}' http://${LB_HOSTNAME}/api/employees

# List
curl -s http://${LB_HOSTNAME}/api/employees

# Get by ID (replace 1 with actual ID)
curl -s http://${LB_HOSTNAME}/api/employees/1

# Update
curl -X PUT -H "Content-Type: application/json" -d '{"name":"Alice Smith","role":"Senior QA"}' http://${LB_HOSTNAME}/api/employees/1

# Delete
curl -X DELETE http://${LB_HOSTNAME}/api/employees/1
```

### 4. Kubernetes Resources
```bash
kubectl get all -n default   # see pods, services, deployments
kubectl describe deployment spring-boot-app
kubectl logs -f deployment/spring-boot-app   # follow application logs
```

---

## Troubleshooting Tips

| Symptom | Likely Cause | Fix |
|---------|--------------|-----|
| `ImagePullBackOff` or `ErrImagePull` | Image not found in ECR or lack of pull permissions | - Verify image URI in `deployment.yaml` matches what was pushed.<br>- Ensure EKS node IAM role has `AmazonEC2ContainerRegistryReadOnly` policy.<br>- Run `aws ecr get-login-password ... | docker login ...` on a node (or use IRSA/eks pod identity). |
| Service shows `<pending>` for EXTERNAL-IP | Cloud provider load balancer not provisioning (may need extra time or permissions) | - Wait 2‑3 min.<br>- Ensure the IAM role for the cluster has `elasticloadbalancing:*` permissions.<br>- Check AWS ELB logs in the console. |
| No metrics in Prometheus/Grafana | ServiceMonitor not applied or label mismatch | - Verify `kubectl get servicemonitor` shows your monitor.<br>- Check that the service has a port named `metrics` (see `service.yaml`).<br>- Ensure Prometheus RBAC allows reading endpoints/kubernetes services. |
| Application crashes on start | Missing dependencies, Java version mismatch, or DB issues | - Check pod logs: `kubectl logs <pod-name>`.<br>- Confirm Java 21 is used (both in Dockerfile and pom).<br>- If switching from H2 to a real DB, ensure `application.properties` or env vars point to a valid RDS instance. |
| Jenkins pipeline fails at `aws eks update-kubeconfig` | AWS credentials missing or insufficient EKS permissions | - Validate Jenkins AWS credentials.<br>- Ensure the IAM user has `eks:DescribeCluster` and `eks:AccessKubernetesApi` (via `AmazonEKSClusterPolicy`). |
| LoadBalancer service times out | No healthy pods or container port mismatch | - Check pod readiness: `kubectl get pods`.<br>- Confirm container port in `deployment.yaml` matches the app’s exposed port (8080).<br>- Verify the app actually starts (look at logs). |

---

## Cleanup (Optional)

To delete all resources created by this guide:

```bash
# Delete Helm release (if installed)
helm uninstall kube-prometheus-stack -n monitoring

# Delete Kubernetes manifests
kubectl delete -f k8s/servicemonitor.yaml
kubectl delete -f k8s/service.yaml
kubectl delete -f k8s/deployment.yaml

# Delete ECR repository (warning: deletes all images)
aws ecr delete-repository --repository-name ${REPOSITORY_NAME} --force --region ${AWS_REGION}

# Delete EKS cluster (if you created it via eksctl)
eksctl delete cluster --name ${EKS_CLUSTER_NAME} --region ${AWS_REGION}
```

---

## Conclusion

You now have a production‑ready Spring Boot application deployed on AWS EKS with:

- **Stable Java 21 runtime** (both locally and in containers)
- **GitOps‑style deployments** via Jenkins pushing to ECR and applying Kubernetes manifests
- **Full observability** with Prometheus + Grafana (JVM, HTTP, Spring Boot metrics)
- **Health checks** integrated with Kubernetes liveness/readiness probes
- **REST API** for CRUD operations on an Employee entity (backed by H2 for simplicity; swap to RDS as needed)

From here, you can enhance the project further (e.g., add a real database, input validation, authentication, or expand the API) while maintaining a reliable CI/CD pipeline and observability stack.

Happy deploying! 🚀
## GitOps with Argo CD

Argo CD is a declarative, GitOps continuous delivery tool for Kubernetes. It automates the deployment of applications by monitoring a Git repository and automatically applying changes to the cluster when the desired state in Git diverges from the live state.

### Why Use Argo CD with Your Project?

While your current Jenkins pipeline handles building and pushing Docker images, Argo CD excels at the deployment and synchronization phase:
- **Continuous Synchronization**: Automatically ensures your cluster state matches the desired state in Git
- **Drift Detection & Self-Healing**: Detects and corrects configuration drift
- **Rich UI & CLI**: Visualize deployments, rollbacks, and differences
- **Multi-Cluster & Multi-Tenant**: Manage multiple clusters from a single interface
- **RBAC & SSO**: Integrates with existing authentication systems
- **PreSync & PostSync Hooks**: Run validation or cleanup steps

### Recommended Hybrid Approach
Keep Jenkins for:
- Building Docker images (multi-arch, testing)
- Pushing images to ECR
- Updating image tags in Kubernetes manifests (via `sed`)

Use Argo CD for:
- Deploying and synchronizing Kubernetes manifests
- Automated rollouts and rollbacks
- Observability of deployment state

### Implementation Steps

#### 1. Install Argo CD on Your EKS Cluster
```bash
# Create namespace
kubectl create namespace argocd

# Install Argo CD (stable release)
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for pods to be ready
kubectl -n argocd wait --for=condition=available deployment --all --timeout=180s
```

#### 2. Access Argo CD UI
```bash
# Option A: Port-forward (quick access)
kubectl port-forward svc/argocd-server -n argocd 8080:443
# Visit: https://localhost:8080
# Initial password: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# Option B: LoadBalancer (for permanent access)
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'
# Get external IP: kubectl -n argocd get svc argocd-server
```

#### 3. Prepare Your Repository for Argo CD
Your existing `k8s/` directory structure works with Argo CD. The key is ensuring Jenkins updates the image tag in `k8s/deployment.yaml` and commits the change.

#### Update Your Jenkinsfile (Add Git Commit Step)
Add this stage after pushing the image to ECR:
```groovy
stage('Update Git with Image Tag') {
    steps {
        // Configure Git (if needed)
        sh '''
        git config user.name "jenkins-bot"
        git config user.email "jenkins@your-company.com"
        '''

        // Update the image tag in k8s/deployment.yaml
        sh """
        sed -i \"s|IMAGE_PLACEHOLDER|${ECR_URI}:${IMAGE_TAG}|g\" k8s/deployment.yaml
        """

        // Commit and push the change
        sh '''
        git add k8s/deployment.yaml
        git commit -m "chore: update image tag to ${ECR_URI}:${IMAGE_TAG} [skip ci]"
        git push origin HEAD:${GIT_BRANCH:-main}
        '''
    }
}
```

#### 4. Create the Argo CD Application
This tells Argo CD where to find your manifests and how to sync them.

##### Option A: Using `argocd` CLI
```bash
argocd app create spring-boot-app \
  --repo https://github.com/jayadeepchowdary7/aws.git \
  --revision main \
  --path k8s \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace default \
  --sync-policy automated
```

##### Option B: Define Application as Manifest (GitOps for Argo CD)
Create `.argocd/application.yaml` in your repo:
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: spring-boot-app
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/jayadeepchowdary7/aws.git
    targetRevision: main
    path: k8s
  destination:
    server: https://kubernetes.default.svc
    namespace: default
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```
Apply it:
```bash
kubectl apply -f .argocd/application.yaml
```

#### 5. Verify the Setup
- In Argo CD UI or via `argocd app get spring-boot-app`, confirm the app is `Synced`
- Trigger a Jenkins build to update the image tag
- Watch Argo CD automatically sync the change (if `syncPolicy` is automated) or show it as `OutOfSync` for manual approval

### Benefits of This Approach
- **Audit Trail**: Every deploy is tied to a Git commit
- **Rollbacks**: `argocd app rollback spring-boot-app` to previous version
- **Canary/Blue-Green**: Advanced sync waves and hooks
- **Multi-Environment**: Create separate Applications for dev/staging/prod
- **Security**: Least-privilege service account for Argo CD, separate from Jenkins

### Next Steps
1. Consider using Helm or Kustomize with Argo CD for more complex deployments
2. Implement promotion pipelines (dev → staging → prod) using Argo CD Applications of Applications
3. Add notification services (Slack, Email) for sync status alerts
4. Implement image updater tools to automatically update image tags when new images are pushed to ECR

Argo CD complements your existing Jenkins pipeline by providing robust, GitOps-driven deployment synchronization while maintaining your CI/CD build process.
