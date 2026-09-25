#!/bin/bash
# ============================================================================
#  Removes everything the bonus created: the cluster, the /etc/hosts entry
#  and the local access token.
#
#  Usage:  sudo ./scripts/cleanup.sh
# ============================================================================
set -euo pipefail

CLUSTER_NAME="${CLUSTER_NAME:-iot-bonus}"
GITLAB_HOST="${GITLAB_HOST:-gitlab.local}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

pkill -f "kubectl port-forward.*8080:443" || true
k3d cluster delete "${CLUSTER_NAME}" || true

if [ "$(id -u)" -eq 0 ]; then
    sed -i "/[[:space:]]${GITLAB_HOST}$/d" /etc/hosts
fi
rm -f "${SCRIPT_DIR}/../.gitlab-token"

echo "Cleanup done."
