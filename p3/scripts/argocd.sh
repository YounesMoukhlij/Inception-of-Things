#!/bin/bash -e

# =========================================================
# Variables
# =========================================================

CLUSTER_NAME="demo"
APP_NAMESPACE="ooulcaid"
ARGO_NAMESPACE="argocd"

# =========================================================
# Update packages
# =========================================================
echo "Waiting for network..."

until ping -c1 archive.ubuntu.com >/dev/null 2>&1; do
    sleep 2
done

echo "Updating packages..."

apt update
apt install -y curl

# =========================================================
# Install Docker
# =========================================================

if ! command -v docker >/dev/null 2>&1; then
    echo "Installing Docker..."

    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh

    systemctl enable docker
    systemctl start docker

    sudo usermod -aG docker vagrant 2>/dev/null || sudo usermod -aG docker "${SUDO_USER:-$USER}" 2>/dev/null || true
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
    curl -LO "https://dl.k8s.io/${KUBERNETES_RELEASE}/bin/linux/amd64/kubectl.sha256"

    echo "$(cat kubectl.sha256) kubectl" | sha256sum --check

    install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

    rm -f kubectl kubectl.sha256
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
# Create k3d cluster
# =========================================================

if ! k3d cluster list | awk '{print $1}' | grep -qx "${CLUSTER_NAME}"; then
    echo "Creating k3d cluster '${CLUSTER_NAME}'..."
    k3d cluster create "${CLUSTER_NAME}"
else
    echo "Cluster '${CLUSTER_NAME}' already exists."
fi

kubectl cluster-info

# =========================================================
# Install Argo CD
# =========================================================

kubectl create namespace "${ARGO_NAMESPACE}" \
    --dry-run=client -o yaml | kubectl apply -f -

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

echo "Setting up dev namespace and application manifests..."

kubectl create namespace dev \
    --dry-run=client -o yaml | kubectl apply -f -

CONF_DIR=""
if [ -d /tmp/confs ]; then
    CONF_DIR="/tmp/confs"
elif [ -d /confs ]; then
    CONF_DIR="/confs"
elif [ -d ./confs ]; then
    CONF_DIR="./confs"
fi

if [ -n "${CONF_DIR}" ]; then
    if [ -d "${CONF_DIR}/app" ]; then
        kubectl apply -n dev -f "${CONF_DIR}/app"
    fi
    if [ -f "${CONF_DIR}/argocd/service.yaml" ]; then
        kubectl apply -f "${CONF_DIR}/argocd/service.yaml"
    fi
    if [ -f "${CONF_DIR}/argocd/application.yaml" ]; then
        kubectl apply -f "${CONF_DIR}/argocd/application.yaml" || true
    fi
fi

# =========================================================
# Retrieve Argo CD credentials
# =========================================================

ARGO_PASSWORD=$(
kubectl -n "${ARGO_NAMESPACE}" \
get secret argocd-initial-admin-secret \
-o jsonpath="{.data.password}" | base64 -d || echo "N/A"
)

echo
echo "=================================================="
echo "Argo CD successfully installed!"
echo
echo "URL      : https://localhost:8080 (or https://192.168.56.110:8080)"
echo "Username : admin"
echo "Password : ${ARGO_PASSWORD}"
echo "=================================================="

# =========================================================
# Start Port Forward (in background)
# =========================================================

pkill -f "kubectl port-forward.*8080:443" || true
nohup kubectl port-forward --address 0.0.0.0 \
    -n "${ARGO_NAMESPACE}" \
    svc/argocd-server \
    8080:443 >/var/log/argocd-port-forward.log 2>&1 &

echo "Port-forward running in background (PID: $!)."