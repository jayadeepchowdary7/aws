# Verification Commands

This file contains useful commands to verify the state of the Spring Boot application, 
its deployment on EKS, monitoring setup, and CLI tools.

## Table of Contents
1. [Application Verification](#application-verification)
2. [Deployment Verification](#deployment-verification)
3. [Monitoring Verification](#monitoring-verification)
4. [CLI Tool Verification](#cli-tool-verification)
5. [Argo CD Verification](#argo-cd-verification)

---

## Application Verification

Check that the application is running and responding.

### Health Endpoint
```bash
# Get the external IP or hostname of the LoadBalancer service
export LB_HOSTNAME=$(kubectl get svc spring-boot-service -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# Check health endpoint
curl -s http://${LB_HOSTNAME}/actuator/health   # should return {"status":"UP"}

# Check liveness and readiness
curl -s http://${LB_HOSTNAME}/actuator/health/liveness
curl -s http://${LB_HOSTNAME}/actuator/health/readiness
```

### Metrics Endpoint (Prometheus)
```bash
# Check that the metrics endpoint is accessible and returns Prometheus format
curl -s http://${LB_HOSTNAME}:8080/actuator/prometheus | head -10
```

### API Endpoints
```bash
# List employees (should return empty array or existing data)
curl -s http://${LB_HOSTNAME}/api/employees

# Add a test employee
curl -X POST -H "Content-Type: application/json" -d '{"name":"Test User","role":"Tester"}' http://${LB_HOSTNAME}/api/employees

# Verify it was added
curl -s http://${LB_HOSTNAME}/api/employees
```

---

## Deployment Verification

Check Kubernetes resources.

### Deployments
```bash
kubectl get deployments
kubectl describe deployment spring-boot-app
```

### Pods
```bash
kubectl get pods
kubectl describe pod <pod-name>
kubectl logs -f <pod-name>
```

### Services
```bash
kubectl get svc
kubectl describe svc spring-boot-service
```

### Nodes
```bash
kubectl get nodes
kubectl describe nodes
```

### Resource Usage
```bash
kubectl top pod
kubectl top node
```

---

## Monitoring Verification

Check that Prometheus is scraping metrics.

### Prometheus Targets
```bash
# If using port-forward for Prometheus:
# kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
# Then in another terminal:
curl -s http://localhost:9090/targets

# Or if exposed via LoadBalancer:
# curl -s http://<prometheus-external-ip>:9090/targets
```

Look for `spring-boot-app` or `kubernetes-service-endpoints` targets.

### Verify ServiceMonitor
```bash
kubectl get servicemonitor
kubectl describe servicemonitor spring-boot-app
```

### Check if metrics are being collected
```bash
# Query Prometheus for a metric (if you have access to Prometheus UI or via curl)
curl -s "http://localhost:9090/api/v1/query?query=up{job=\"spring-boot-app\"}" | jq .
```
Or:
```bash
curl -s "http://localhost:9090/api/v1/query?query=http_server_requests_seconds_count{app=\"spring-boot-app\"}" | jq .
```

---

## CLI Tool Verification

Verify that the necessary CLI tools are installed and configured.

### AWS CLI
```bash
aws --version
aws sts get-caller-identity   # Should return your account info
```

### kubectl
```bash
kubectl version --short
kubectl cluster-info
```

### helm
```bash
helm version
helm ls --all-namespaces
```

### argocd
```bash
argocd version
argocd login <ARGOCD_SERVER>   # Then authenticate
argocd app list
```

### docker
```bash
docker --version
docker info
```

### git
```bash
git --version
git status
```

---

## Argo CD Verification

Check the state of the Argo CD application.

### Using argocd CLI
```bash
argocd app get spring-boot-app
argocd app history spring-boot-app
argocd app sync spring-boot-app   # To manually sync if needed
```

### Using kubectl
```bash
kubectl -n argocd get application spring-boot-app -o yaml
kubectl -n argocd get application spring-boot-app -o jsonpath='{.status.health.status}'
```

### Check Sync Status
```bash
# Should show Synced if up to date
argocd app get spring-boot-app --output jsonpath='{.status.sync.status}'
```

### Check Health
```bash
argocd app get spring-boot-app --output jsonpath='{.status.health.status}'
```

---

## End-to-End Verification

A quick checklist to verify the entire system:

1. [ ] Application responds to health checks
2. [ ] Application metrics endpoint returns data
3. [ ] Deployment shows desired number of replicas
4. [ ] Pods are running and ready
5. [ ] Service has an external IP (if LoadBalancer)
6. [ ] Prometheus is scraping the application metrics
7. [ ] Argo CD application is Synced and Healthy
8. [ ] Basic CLI tools (aws, kubectl, helm, argocd) are working

Run these checks periodically to ensure the system is healthy.

---

## Conclusion

Use these commands to verify and troubleshoot your Spring Boot application on AWS EKS with Argo CD and Prometheus/Grafana monitoring.
