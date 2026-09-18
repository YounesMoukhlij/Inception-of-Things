# Part 3 - K3d and Argo CD

## Overview

Part 3 sets up a continuous deployment pipeline using **k3d** (K3s in Docker) and **Argo CD**, without using Vagrant:
- **`argocd` namespace**: Hosts the Argo CD server and controllers.
- **`dev` namespace**: Hosts the application (`wil-playground`) continuously deployed by Argo CD.

## Prerequisites

- Linux host / VM with Docker installed.
- `kubectl` and `k3d` (installed automatically by the script if missing).

## How to Run

Execute the setup script from the `p3/` directory:

```bash
sudo ./scripts/setup.sh
```

This will:
1. Ensure Docker, kubectl, and k3d are installed.
2. Create the k3d cluster (`iot-cluster`) with port `8888` mapped to the ingress loadbalancer.
3. Create `argocd` and `dev` namespaces.
4. Deploy Argo CD and wait for it to be ready.
5. Deploy the application manifests and configure Argo CD.
6. Start port-forwarding for the Argo CD Web UI at `https://localhost:8080`.

## Verification

### 1. Check Namespaces
```bash
kubectl get ns
```
Expected output includes:
```text
argocd   Active
dev      Active
```

### 2. Check Application Pod
```bash
kubectl get pods -n dev
```
Expected output:
```text
NAME                              READY   STATUS    RESTARTS   AGE
wil-playground-xxxxxxxxxx-xxxxx   1/1     Running   0          ...
```

### 3. Check Application Response (v1)
```bash
curl http://localhost:8888/
```
Expected output:
```json
{"status":"ok", "message": "v1"}
```

### 4. Access Argo CD Web UI
- **URL**: `https://localhost:8080`
- **Username**: `admin`
- **Password**:
  ```bash
  kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo
  ```

### 5. Test Continuous Deployment (v1 -> v2)
Update the deployment image version:
```bash
sed -i 's/wil42\/playground:v1/wil42\/playground:v2/g' confs/app/deployment.yaml
git commit -am "Update app to v2"
git push
```

Once Argo CD syncs the change from GitHub:
```bash
curl http://localhost:8888/
```
Expected output:
```json
{"status":"ok", "message": "v2"}
```

## Cleanup

To delete the cluster:
```bash
k3d cluster delete iot-cluster
```

