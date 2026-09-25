#!/bin/bash
# ============================================================================
#  BONUS - Part 3 driven by a LOCAL GitLab
#
#  1. Installs Docker, kubectl, k3d and Git if they are missing.
#  2. Creates the k3d cluster:
#        host :80   -> Traefik  (GitLab, Ingress with the gitlab.local host rule)
#        host :8888 -> Traefik  (the application, catch-all Ingress)
#  3. Creates the three namespaces: argocd, dev, gitlab.
#  4. Makes gitlab.local resolvable on the host (/etc/hosts) AND inside the
#     cluster (CoreDNS rewrite), so one single URL works everywhere.
#  5. Deploys GitLab CE (official omnibus image, latest release).
#  6. Creates the public project root/iot and seeds it with confs/app.
#  7. Installs Argo CD and points it at the LOCAL GitLab repository.
#
#  Usage:  sudo ./scripts/setup.sh
# ============================================================================
set -euo pipefail

# =========================================================
# Variables
# =========================================================

CLUSTER_NAME="iot-bonus"
ARGO_NAMESPACE="argocd"
DEV_NAMESPACE="dev"
GITLAB_NAMESPACE="gitlab"

GITLAB_HOST="gitlab.local"            # same name on the host and in the cluster
GITLAB_ROOT_PASSWORD="Iot42-Bonus-Pass"
APP_PORT="8888"                       # curl http://localhost:8888/

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONF_DIR="${SCRIPT_DIR}/../confs"

log() { echo -e "\n==> $*"; }

# =========================================================
# Pre-flight checks
# =========================================================

if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root (it edits /etc/hosts and binds port 80)."
    echo "  sudo ./scripts/setup.sh"
    exit 1
fi

port_busy() { ss -ltnH "sport = :$1" 2>/dev/null | grep -q .; }

if ! k3d cluster list 2>/dev/null | awk '{print $1}' | grep -qx "${CLUSTER_NAME}"; then
    for p in 80 "${APP_PORT}"; do
        if port_busy "$p"; then
            echo "Port ${p} is already in use on this host."
            echo "Free it first - the Part 3 cluster uses ${APP_PORT}:"
            echo "  k3d cluster delete iot-cluster"
            exit 1
        fi
    done
fi

# =========================================================
# Install Docker
# =========================================================

if ! command -v docker >/dev/null 2>&1; then
    log "Installing Docker..."
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
    log "Installing kubectl..."
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
    log "Installing k3d..."
    curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
else
    echo "k3d is already installed."
fi

# =========================================================
# Install Git (used for the clone/push demo)
# =========================================================

if ! command -v git >/dev/null 2>&1; then
    log "Installing Git..."
    (apt-get update && apt-get install -y git) \
        || dnf install -y git \
        || pacman -S --noconfirm git
else
    echo "Git is already installed."
fi

# =========================================================
# Create the k3d cluster
# =========================================================

if ! k3d cluster list | awk '{print $1}' | grep -qx "${CLUSTER_NAME}"; then
    log "Creating k3d cluster '${CLUSTER_NAME}'..."
    k3d cluster create "${CLUSTER_NAME}" \
        --port "80:80@loadbalancer" \
        --port "${APP_PORT}:80@loadbalancer" \
        --k3s-arg "--disable=metrics-server@server:0" \
        --wait
else
    echo "Cluster '${CLUSTER_NAME}' already exists."
fi

# Give the unprivileged user a usable kubeconfig too (merged, not overwritten).
if [ -n "${SUDO_USER:-}" ]; then
    USER_HOME=$(getent passwd "${SUDO_USER}" | cut -d: -f6)
    mkdir -p "${USER_HOME}/.kube"
    KUBECONFIG="${USER_HOME}/.kube/config" k3d kubeconfig merge "${CLUSTER_NAME}" \
        --kubeconfig-merge-default --kubeconfig-switch-context >/dev/null
    chown -R "${SUDO_USER}:${SUDO_USER}" "${USER_HOME}/.kube"
    chmod 600 "${USER_HOME}/.kube/config"
fi

# =========================================================
# Namespaces
# =========================================================

log "Creating namespaces..."
for ns in "${ARGO_NAMESPACE}" "${DEV_NAMESPACE}" "${GITLAB_NAMESPACE}"; do
    kubectl create namespace "${ns}" --dry-run=client -o yaml | kubectl apply -f -
done

# =========================================================
# Name resolution for gitlab.local (host + cluster)
# =========================================================

log "Making ${GITLAB_HOST} resolvable..."
if ! grep -qE "^[0-9.]+[[:space:]]+${GITLAB_HOST}\b" /etc/hosts; then
    echo "127.0.0.1 ${GITLAB_HOST}" >> /etc/hosts
    echo "    /etc/hosts: added '127.0.0.1 ${GITLAB_HOST}'"
else
    echo "    /etc/hosts: already configured"
fi

kubectl apply -f "${CONF_DIR}/gitlab/coredns-custom.yaml"
kubectl -n kube-system rollout restart deployment coredns
kubectl -n kube-system rollout status deployment coredns --timeout=180s

# =========================================================
# Deploy GitLab
# =========================================================

log "Deploying GitLab (first boot takes 5 to 15 minutes)..."

kubectl -n "${GITLAB_NAMESPACE}" create secret generic gitlab-root-password \
    --from-literal=password="${GITLAB_ROOT_PASSWORD}" \
    --dry-run=client -o yaml | kubectl apply -f -

kubectl apply -f "${CONF_DIR}/gitlab/service.yaml"
kubectl apply -f "${CONF_DIR}/gitlab/statefulset.yaml"
kubectl apply -f "${CONF_DIR}/gitlab/ingress.yaml"

echo "Waiting for GitLab to be ready (follow with: kubectl -n gitlab get pods -w)..."
kubectl -n "${GITLAB_NAMESPACE}" rollout status statefulset/gitlab --timeout=1800s
kubectl -n "${GITLAB_NAMESPACE}" wait --for=condition=ready pod -l app=gitlab --timeout=1800s

# =========================================================
# Seed GitLab: public project + application manifests
# =========================================================

GITLAB_HOST="${GITLAB_HOST}" \
GITLAB_NAMESPACE="${GITLAB_NAMESPACE}" \
    bash "${SCRIPT_DIR}/seed_gitlab.sh"

# =========================================================
# Install Argo CD
# =========================================================

log "Installing Argo CD..."
kubectl apply -n "${ARGO_NAMESPACE}" \
    --server-side --force-conflicts \
    -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo "Waiting for Argo CD to become ready..."
kubectl wait --for=condition=available \
    deployment/argocd-server -n "${ARGO_NAMESPACE}" --timeout=600s
kubectl wait --for=condition=available \
    deployment/argocd-repo-server -n "${ARGO_NAMESPACE}" --timeout=600s

# =========================================================
# Point Argo CD at the local GitLab
# =========================================================

log "Checking that ${GITLAB_HOST} resolves inside the cluster..."
if kubectl run "dns-check-$$" --rm -i --restart=Never --namespace "${ARGO_NAMESPACE}" \
        --image=busybox:1.36 --command -- nslookup "${GITLAB_HOST}" >/dev/null 2>&1; then
    echo "    OK - Argo CD clones http://${GITLAB_HOST}/root/iot.git"
    kubectl apply -f "${CONF_DIR}/argocd/application.yaml"
else
    echo "    CoreDNS rewrite unavailable - falling back to the Service FQDN."
    sed "s|http://${GITLAB_HOST}/|http://gitlab.${GITLAB_NAMESPACE}.svc.cluster.local/|" \
        "${CONF_DIR}/argocd/application.yaml" | kubectl apply -f -
fi

# =========================================================
# Argo CD Web UI
# =========================================================

ARGO_PASSWORD=$(
    kubectl -n "${ARGO_NAMESPACE}" get secret argocd-initial-admin-secret \
    -o jsonpath="{.data.password}" | base64 -d 2>/dev/null || echo "N/A"
)

pkill -f "kubectl port-forward.*8080:443" || true
nohup kubectl port-forward --address 0.0.0.0 \
    -n "${ARGO_NAMESPACE}" svc/argocd-server 8080:443 >/dev/null 2>&1 &

echo ""
echo "=================================================="
echo "GitLab + Argo CD + wil-playground are up!"
echo "=================================================="
echo "GitLab UI  : http://${GITLAB_HOST}/"
echo "  login    : root"
echo "  password : ${GITLAB_ROOT_PASSWORD}"
echo "  repo     : http://${GITLAB_HOST}/root/iot"
echo "--------------------------------------------------"
echo "Argo CD UI : https://localhost:8080"
echo "  login    : admin"
echo "  password : ${ARGO_PASSWORD}"
echo "--------------------------------------------------"
echo "App URL    : http://localhost:${APP_PORT}/"
echo "=================================================="
echo "Verification commands:"
echo "  kubectl get ns"
echo "  kubectl get pods -n gitlab"
echo "  kubectl get pods -n dev"
echo "  curl http://localhost:${APP_PORT}/"
echo "  sudo ./scripts/switch_version.sh v2   # continuous deployment demo"
echo "=================================================="
