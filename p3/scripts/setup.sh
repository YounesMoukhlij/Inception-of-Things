#!/bin/bash
set -euo pipefail

# =========================================================
# Variables
# =========================================================

CLUSTER_NAME="iot-cluster"
ARGO_NAMESPACE="argocd"
DEV_NAMESPACE="dev"

# =========================================================
# Install Docker
# =========================================================

if ! command -v docker >/dev/null 2>&1; then
    echo "Installing Docker..."
    curl -fsSL https://get.docker.com | sh
    systemctl enable --now docker
    usermod -aG docker "${SUDO_USER:-$USER}" 2>/dev/null || true
else
    echo "Docker is already installed."
fi

# =========================================================
# Install kubectl
# =========================================================

if ! command -v kubectl >/dev/null 2>&1; then
    echo "Installing kubectl..."
    KUBERNETES_RELEASE=$(curl -L -s https://dl.k8s.io/release/stable.txt)
    curl -LO "https://dl.k8s.io/release/${KUBERNETES_RELEASE}/bin/linux/amd64/kubectl"
    install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
    rm -f kubectl
else
    echo "kubectl is already installed."
fi

# =========================================================
# Install k3d
# =========================================================

if ! command -v k3d >/dev/null 2>&1; then
    echo "Installing k3d..."
    curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
else
    echo "k3d is already installed."
fi

# =========================================================
# Create k3d cluster with port 8888 mapped to Ingress
# =========================================================

if ! k3d cluster list | awk '{print $1}' | grep -qx "${CLUSTER_NAME}"; then
    echo "Creating k3d cluster '${CLUSTER_NAME}'..."
    k3d cluster create "${CLUSTER_NAME}" --port "8888:80@loadbalancer"
else
    echo "Cluster '${CLUSTER_NAME}' already exists."
fi

# =========================================================
# Create namespaces
# =========================================================

kubectl create namespace "${ARGO_NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace "${DEV_NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -

# =========================================================
# Install Argo CD
# =========================================================

echo "Installing Argo CD..."
kubectl apply -n "${ARGO_NAMESPACE}" \
    --server-side --force-conflicts \
    -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo "Waiting for Argo CD to become ready..."
kubectl wait \
    --for=condition=available \
    deployment/argocd-server \
    -n "${ARGO_NAMESPACE}" \
    --timeout=300s

# =========================================================
# Deploy application & Argo CD Configs
# =========================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONF_DIR="${SCRIPT_DIR}/../confs"

echo "Deploying application and Argo CD manifests..."
if [ -d "${CONF_DIR}/app" ]; then
    kubectl apply -n "${DEV_NAMESPACE}" -f "${CONF_DIR}/app"
fi

if [ -f "${CONF_DIR}/argocd/service.yaml" ]; then
    kubectl apply -f "${CONF_DIR}/argocd/service.yaml"
fi

if [ -f "${CONF_DIR}/argocd/application.yaml" ]; then
    kubectl apply -f "${CONF_DIR}/argocd/application.yaml"
fi

# =========================================================
# Retrieve Argo CD credentials
# =========================================================

ARGO_PASSWORD=$(
    kubectl -n "${ARGO_NAMESPACE}" \
    get secret argocd-initial-admin-secret \
    -o jsonpath="{.data.password}" | base64 -d 2>/dev/null || echo "N/A"
)

# =========================================================
# Start Port Forward for Argo CD UI (in background)
# =========================================================

pkill -f "kubectl port-forward.*8080:443" || true
nohup kubectl port-forward --address 0.0.0.0 \
    -n "${ARGO_NAMESPACE}" \
    svc/argocd-server \
    8080:443 >/dev/null 2>&1 &

echo ""
echo "=================================================="
echo "Argo CD & Wil-Playground successfully deployed!"
echo "=================================================="
echo "Argo CD UI : https://localhost:8080"
echo "Username   : admin"
echo "Password   : ${ARGO_PASSWORD}"
echo "App URL    : http://localhost:8888/"
echo "=================================================="
echo "Verification commands:"
echo "  kubectl get ns"
echo "  kubectl get pods -n dev"
echo "  curl http://localhost:8888/"
echo "=================================================="