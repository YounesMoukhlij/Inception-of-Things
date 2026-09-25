#!/bin/bash
# ============================================================================
#  Continuous deployment demo, driven by the LOCAL GitLab.
#
#  Clones root/iot from the local GitLab, changes the image tag of the
#  application, pushes, then asks Argo CD to refresh and waits until the
#  cluster serves the new version.
#
#  Usage:  sudo ./scripts/switch_version.sh v2
#          sudo ./scripts/switch_version.sh v1
#
#  (The same thing can be done by hand from the GitLab web IDE - the point of
#  the exercise is that the change comes from the Git repository, not kubectl.)
# ============================================================================
set -euo pipefail

VERSION="${1:-}"
if [[ ! "${VERSION}" =~ ^v[0-9]+$ ]]; then
    echo "Usage: $0 <v1|v2>"
    exit 1
fi

GITLAB_HOST="${GITLAB_HOST:-gitlab.local}"
ARGO_NAMESPACE="${ARGO_NAMESPACE:-argocd}"
APP_NAME="${APP_NAME:-wil-playground}"
APP_PORT="${APP_PORT:-8888}"
PROJECT_PATH="root/iot"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOKEN_FILE="${SCRIPT_DIR}/../.gitlab-token"

if [ ! -s "${TOKEN_FILE}" ]; then
    echo "No access token found (${TOKEN_FILE}). Run ./scripts/setup.sh first."
    exit 1
fi
TOKEN="$(cat "${TOKEN_FILE}")"
AUTH_URL="http://oauth2:${TOKEN}@${GITLAB_HOST}/${PROJECT_PATH}.git"

WORKDIR="$(mktemp -d)"
trap 'rm -rf "${WORKDIR}"' EXIT

echo "==> Cloning http://${GITLAB_HOST}/${PROJECT_PATH}.git"
git clone -q "${AUTH_URL}" "${WORKDIR}/iot"

MANIFEST="${WORKDIR}/iot/confs/app/deployment.yaml"
sed -i "s|wil42/playground:v[0-9]*|wil42/playground:${VERSION}|g" "${MANIFEST}"

if git -C "${WORKDIR}/iot" diff --quiet; then
    echo "    already on ${VERSION}, nothing to commit."
else
    echo "==> Pushing ${VERSION} to GitLab"
    git -C "${WORKDIR}/iot" -c user.email="root@${GITLAB_HOST}" -c user.name="root" \
        commit -q -am "Update application to ${VERSION}"
    git -C "${WORKDIR}/iot" push -q origin HEAD:main
fi

grep -n 'image:' "${MANIFEST}"

echo "==> Asking Argo CD to refresh (it would poll on its own within ~3 min)"
kubectl -n "${ARGO_NAMESPACE}" patch application "${APP_NAME}" --type merge \
    -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}' >/dev/null

echo "==> Waiting for the cluster to serve ${VERSION}..."
for _ in $(seq 1 60); do
    if curl -s "http://localhost:${APP_PORT}/" | grep -q "\"${VERSION}\""; then
        echo ""
        curl -s "http://localhost:${APP_PORT}/"; echo
        echo "Application is now running ${VERSION}."
        exit 0
    fi
    sleep 5
done

echo "Timed out. Current answer:"
curl -s "http://localhost:${APP_PORT}/"; echo
exit 1
