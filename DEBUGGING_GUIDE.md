# Kubernetes Debugging Guide

This guide provides steps to debug common Kubernetes issues encountered when deploying and running applications.

## Table of Contents
1. [CrashLoopBackOff](#crashloopofoff)
2. [OOMKilled](#oomkilled)
3. [ImagePullBackOff](#imagepullbackoff)
4. [NodeNotReady](#nodenotready)
5. [Pending Pods](#pending-pods)
6. [Service Not Exposing Application](#service-not-exposing-application)
7. [General Debugging Steps](#general-debugging-steps)

---

## CrashLoopBackOff

A pod is crashing repeatedly after starting.

### Possible Causes
- Application error (exception during startup)
- Missing dependencies or configuration
- Incorrect command or arguments in the container
- Resource constraints (CPU/Memory) causing immediate termination

### Debugging Steps
1. **Check pod logs**:
   ```bash
   kubectl logs <pod-name>
   ```
   If the pod restarts, check previous instance:
   ```bash
   kubectl logs <pod-name> --previous
   ```

2. **Describe the pod** to see events and container status:
   ```bash
   kubectl describe pod <pod-name>
   ```

3. **Check if the container image is correct** and the entrypoint/command.

4. **Run the container locally** (if possible) to reproduce the issue.

5. **Check resource limits**: If the container is requesting more resources than available, it may crash.

### Common Fixes
- Fix application errors and redeploy.
- Correct the command or arguments in the pod spec.
- Adjust resource requests/limits.
- Ensure configuration (ConfigMaps, Secrets) is mounted correctly.

---

## OOMKilled

The container was killed because it exceeded its memory limit.

### Possible Causes
- Application using more memory than the limit set in the container.
- Memory leak in the application.
- Underestimated memory requirements.

### Debugging Steps
1. **Check pod events**:
   ```bash
   kubectl describe pod <pod-name>
   ```
   Look for `OOMKilled` in the container status.

2. **Check memory usage** (if metrics are available):
   ```bash
   kubectl top pod <pod-name>
   ```

3. **Review application memory usage** (heap dumps, etc.).

### Common Fixes
- Increase the memory limit in the container spec.
- Optimize the application to use less memory.
- Fix memory leaks.

---

## ImagePullBackOff

Kubernetes cannot pull the container image.

### Possible Causes
- Incorrect image name or tag.
- Image does not exist in the registry.
- Lack of permissions to pull the image (private registry).
- Network issues preventing access to the registry.

### Debugging Steps
1. **Describe the pod** to see events:
   ```bash
   kubectl describe pod <pod-name>
   ```
   Look for `Failed to pull image` or `ErrImagePull`.

2. **Verify the image name and tag** in the pod spec.

3. **Check if the image exists** in the registry (e.g., via `docker pull` or registry UI).

4. **Check credentials**: If using a private registry, ensure the image pull secret is correctly configured.

5. **Check network connectivity** from the node to the registry.

### Common Fixes
- Correct the image name/tag.
- Push the image to the registry.
- Create or update image pull secret for private registry.
- Fix network issues or firewall rules.

---

## NodeNotReady

A node is not ready to schedule pods.

### Possible Causes
- Node is unhealthy (disk pressure, memory pressure, PID pressure).
- Kubelet is not running or having issues.
- Network problems between node and control plane.

### Debugging Steps
1. **Check node status**:
   ```bash
   kubectl get nodes
   ```
   Look for `NotReady` and the conditions.

2. **Describe the node** to see conditions:
   ```bash
   kubectl describe node <node-name>
   ```

3. **Check kubelet logs** on the node (if you have access):
   ```bash
   journalctl -u kubelet
   ```

4. **Check system resources** on the node (disk, memory, CPU).

### Common Fixes
- Resolve resource pressure (free disk, stop memory-hogging processes).
- Restart kubelet service.
- Fix network issues between node and control plane.
- If using a cloud provider, check the node's health and consider replacing it.

---

## Pending Pods

Pods are stuck in Pending state and not being scheduled.

### Possible Causes
- Insufficient resources (CPU, memory) in the cluster.
- Node selector or affinity rules that match no nodes.
- Taints and tolerations preventing scheduling.
- Volume binding failures (if using persistent volumes).

### Debugging Steps
1. **Check pod events**:
   ```bash
   kubectl describe pod <pod-name>
   ```
   Look for events like `FailedScheduling`.

2. **Check node resources**:
   ```bash
   kubectl describe nodes
   ```
   Look for `Allocatable` vs. `Allocated` resources.

3. **Check node labels and taints** if using node affinity or tolerations.

4. **Check persistent volume claims** if the pod uses storage.

### Common Fixes
- Add more nodes to the cluster.
- Adjust resource requests/limits of the pod.
- Modify node selector, affinity, or tolerations.
- Resolve taints or add matching tolerations.
- Fix storage class or persistent volume issues.

---

## Service Not Exposing Application

The service is not forwarding traffic to the pods.

### Possible Causes
- Service selector does not match pod labels.
- Pods are not ready (not passing readiness probe).
- Service type misconfiguration (e.g., LoadBalancer not provisioning external IP).

### Debugging Steps
1. **Check service definition**:
   ```bash
   kubectl get svc <service-name> -o yaml
   ```
   Verify the `selector` matches pod labels.

2. **Check pod labels**:
   ```bash
   kubectl get pods --show-labels
   ```

3. **Check if pods are ready**:
   ```bash
   kubectl get pods
   ```
   Look for `READY` column (e.g., 1/1).

4. **Check service events** (if any):
   ```bash
   kubectl describe svc <service-name>
   ```

5. **For LoadBalancer services**, check if cloud provider has provisioned an LB:
   ```bash
   kubectl get svc <service-name> -o wide
   ```
   Check `EXTERNAL-IP` or `LOAD BALANCER INGRESS`.

### Common Fixes
- Correct the service selector to match pod labels.
- Ensure pods pass readiness checks (fix application or probe).
- Wait for cloud provider to provision LB or check quota/permissions.
- Use NodePort or Ingress as alternatives if needed.

---

## General Debugging Steps

1. **Check pod status**:
   ```bash
   kubectl get pods
   ```

2. **Describe the pod** for events and details:
   ```bash
   kubectl describe pod <pod-name>
   ```

3. **Check logs** (current and previous):
   ```bash
   kubectl logs <pod-name>
   kubectl logs <pod-name> --previous
   ```

4. **Exec into the pod** (if it's running):
   ```bash
   kubectl exec -it <pod-name> -- /bin/sh
   ```

5. **Check related resources** (services, deployments, statefulsets, etc.).

6. **Use kubectl get events** to see cluster-wide events:
   ```bash
   kubectl get events --sort-by=.metadata.creationTimestamp
   ```

7. **Monitor resource usage**:
   ```bash
   kubectl top pod
   kubectl top node
   ```

8. **Check if the issue is node-specific** by draining or cordoning nodes.

---

## Specific to This Project

### Checking the Spring Boot Application
- **Health endpoint**: `curl http://<external-ip>/actuator/health`
- **Metrics endpoint**: `curl http://<external-ip>:8080/actuator/prometheus`
- **API endpoints**: `curl http://<external-ip>/api/employees`

### Checking Deployment
```bash
kubectl get deployment spring-boot-app
kubectl describe deployment spring-boot-app
```

### Checking Service
```bash
kubectl get svc spring-boot-service
kubectl describe svc spring-boot-service
```

### Checking Prometheus Scraping
- Ensure the ServiceMonitor is applied: `kubectl get servicemonitor`
- Check Prometheus targets: `http://<prometheus-ip>:9090/targets`

### Checking Argo CD Sync
```bash
argocd app get spring-boot-app
```
or
```bash
kubectl -n argocd get application spring-boot-app -o yaml
```

---

## Conclusion

Debugging Kubernetes issues requires a systematic approach: check pod state, logs, events, and related resources. Use the commands above to isolate the problem and apply the appropriate fix. When in doubt, start with `kubectl describe` and `kubectl logs`.

Remember to check the official Kubernetes documentation for more details: https://kubernetes.io/docs/tasks/debug-application-cluster/
