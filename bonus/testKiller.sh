#!/usr/bin/env bash
# ============================================================================
#  IoT - Bonus  ·  GitLab + Argo CD test
#  Verifies the whole bonus from the host: the three namespaces, the local
#  GitLab, the CoreDNS rewrite, Argo CD syncing FROM that GitLab, and the
#  application answering on port 8888.
#
#  Usage:   ./testKiller.sh              run every check
#           ./testKiller.sh --cd         also run the full v1 <-> v2 continuous
#                                        deployment test (needs sudo)
#           NO_COLOR=1 ./testKiller.sh   disable colors
# ============================================================================

CLUSTER_NAME="iot-bonus"
GITLAB_HOST="gitlab.local"
APP_PORT="8888"
PROJECT_PATH="root/iot"
ARGO_APP="wil-playground"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

RUN_CD=0
[[ "${1:-}" == "--cd" ]] && RUN_CD=1

# ---- colors -----------------------------------------------------------------
if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
  R=$'\e[31m'; G=$'\e[32m'; Y=$'\e[33m'; B=$'\e[34m'; C=$'\e[36m'
  BOLD=$'\e[1m'; DIM=$'\e[2m'; X=$'\e[0m'
else
  R=; G=; Y=; B=; C=; BOLD=; DIM=; X=
fi

PASS=0; FAIL=0

title() { printf '\n%s%s━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━%s\n' "$BOLD" "$B" "$X"
          printf '%s%s  %s%s\n' "$BOLD" "$B" "$1" "$X"
          printf '%s%s━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━%s\n' "$BOLD" "$B" "$X"; }
ok()    { printf '  %s✔ PASS%s  %s\n' "$G" "$X" "$1"; PASS=$((PASS+1)); }
ko()    { printf '  %s✗ FAIL%s  %s\n' "$R" "$X" "$1"; [[ -n "${2:-}" ]] && printf '           %s%s%s\n' "$DIM" "$2" "$X"; FAIL=$((FAIL+1)); }
info()  { printf '  %s→%s %s\n' "$C" "$X" "$1"; }
warn()  { printf '  %s! %s%s\n' "$Y" "$1" "$X"; }

K() { kubectl "$@" 2>/dev/null; }

# ---- pre-flight -------------------------------------------------------------
title "Pre-flight"
command -v kubectl >/dev/null || { ko "kubectl not found in PATH"; exit 1; }
command -v curl    >/dev/null || { ko "curl not found in PATH"; exit 1; }

if k3d cluster list 2>/dev/null | awk '{print $1}' | grep -qx "${CLUSTER_NAME}"; then
  ok "k3d cluster '${CLUSTER_NAME}' exists"
else
  ko "k3d cluster '${CLUSTER_NAME}' not found" "run: sudo ./scripts/setup.sh"; exit 1
fi

# Use the cluster context if it is not the current one (e.g. setup ran as root).
if ! K cluster-info >/dev/null; then
  if kubectl config get-contexts -o name 2>/dev/null | grep -qx "k3d-${CLUSTER_NAME}"; then
    kubectl() { command kubectl --context "k3d-${CLUSTER_NAME}" "$@"; }
    info "using context k3d-${CLUSTER_NAME}"
  fi
fi
if K get nodes >/dev/null; then
  ok "cluster is reachable ($(K get nodes -o name | wc -l) node)"
else
  ko "cannot reach the cluster" "try: sudo ./testKiller.sh, or export KUBECONFIG"; exit 1
fi

if grep -qE "^[0-9.]+[[:space:]]+${GITLAB_HOST}\b" /etc/hosts; then
  ok "/etc/hosts resolves ${GITLAB_HOST}"
else
  ko "${GITLAB_HOST} missing from /etc/hosts" "add: 127.0.0.1 ${GITLAB_HOST}"
fi

# ---- TEST 1 · the three namespaces -----------------------------------------
title "TEST 1 · namespaces (argocd, dev, gitlab)"
for ns in argocd dev gitlab; do
  if [[ "$(K get ns "$ns" -o jsonpath='{.status.phase}')" == "Active" ]]; then
    ok "namespace ${ns} is Active"
  else
    ko "namespace ${ns} is missing"
  fi
done

# ---- TEST 2 · GitLab runs in the cluster ------------------------------------
title "TEST 2 · GitLab runs in the gitlab namespace"
GL_POD=$(K -n gitlab get pod -l app=gitlab -o jsonpath='{.items[0].metadata.name}')
if [[ -n "$GL_POD" ]]; then
  READY=$(K -n gitlab get pod "$GL_POD" -o jsonpath='{.status.containerStatuses[0].ready}')
  if [[ "$READY" == "true" ]]; then ok "pod ${GL_POD} is Running and Ready"
  else ko "pod ${GL_POD} is not Ready" "follow: kubectl -n gitlab get pods -w"; fi
  VER=$(K -n gitlab exec "$GL_POD" -- cat /opt/gitlab/embedded/service/gitlab-rails/VERSION 2>/dev/null)
  [[ -n "$VER" ]] && info "GitLab version ${VER}"
else
  ko "no GitLab pod in the gitlab namespace"
fi

# ---- TEST 3 · GitLab answers on the host ------------------------------------
title "TEST 3 · GitLab is reachable from the host"
CODE=$(curl -s -o /dev/null -w '%{http_code}' --max-time 15 "http://${GITLAB_HOST}/users/sign_in")
if [[ "$CODE" == "200" ]]; then
  ok "http://${GITLAB_HOST}/ answers ${CODE}"
else
  ko "http://${GITLAB_HOST}/ answers ${CODE}" "expected 200 - is host port 80 mapped to Traefik?"
fi

# The app must still own the catch-all route on 8888.
APP_BODY=$(curl -s --max-time 15 "http://localhost:${APP_PORT}/")
if grep -q '"status":"ok"' <<<"$APP_BODY"; then
  ok "http://localhost:${APP_PORT}/ is routed to the application, not to GitLab"
else
  ko "http://localhost:${APP_PORT}/ does not answer like the application" "got: ${APP_BODY:0:80}"
fi

# ---- TEST 4 · the repository is public and clonable --------------------------
title "TEST 4 · public repository ${PROJECT_PATH}"
RAW_URL="http://${GITLAB_HOST}/api/v4/projects/root%2Fiot/repository/files/confs%2Fapp%2Fdeployment.yaml/raw?ref=main"
REPO_MANIFEST=$(curl -s --max-time 15 "$RAW_URL")
if grep -q 'wil42/playground' <<<"$REPO_MANIFEST"; then
  REPO_TAG=$(grep -o 'wil42/playground:v[0-9]*' <<<"$REPO_MANIFEST" | head -1 | cut -d: -f2)
  ok "confs/app/deployment.yaml is readable anonymously (${REPO_TAG})"
else
  ko "cannot read the manifest anonymously" "is the project public? ${RAW_URL}"
fi

if command -v git >/dev/null && git ls-remote "http://${GITLAB_HOST}/${PROJECT_PATH}.git" >/dev/null 2>&1; then
  ok "anonymous git clone works (this is what Argo CD does)"
else
  ko "anonymous git ls-remote failed" "http://${GITLAB_HOST}/${PROJECT_PATH}.git"
fi

# ---- TEST 5 · gitlab.local resolves INSIDE the cluster ----------------------
title "TEST 5 · CoreDNS rewrite (gitlab.local inside the cluster)"
if K -n kube-system get cm coredns-custom >/dev/null; then
  ok "the coredns-custom ConfigMap is applied"
else
  ko "coredns-custom ConfigMap missing"
fi
DNS=$(K -n default run "dnstest-$$" --rm -i --restart=Never --image=busybox:1.36 \
        --command -- nslookup "${GITLAB_HOST}" 2>/dev/null)
if grep -q "Address" <<<"$DNS" && ! grep -qi "can't resolve" <<<"$DNS"; then
  ok "${GITLAB_HOST} resolves from a pod"
else
  warn "${GITLAB_HOST} does not resolve in-cluster - Argo CD then uses the Service FQDN"
fi

# ---- TEST 6 · Argo CD uses the LOCAL GitLab ---------------------------------
title "TEST 6 · Argo CD pulls from the local GitLab"
if [[ "$(K -n argocd get deploy argocd-server -o jsonpath='{.status.availableReplicas}')" == "1" ]]; then
  ok "argocd-server is available"
else
  ko "argocd-server is not available"
fi

REPO_URL=$(K -n argocd get application "$ARGO_APP" -o jsonpath='{.spec.source.repoURL}')
if [[ -z "$REPO_URL" ]]; then
  ko "the Argo CD Application ${ARGO_APP} does not exist"
elif grep -qi 'github' <<<"$REPO_URL"; then
  ko "the Application still points to GitHub" "repoURL=${REPO_URL}"
elif grep -qE "${GITLAB_HOST}|gitlab\.gitlab\.svc" <<<"$REPO_URL"; then
  ok "source repository is the local GitLab"
  info "repoURL=${REPO_URL}"
else
  ko "unexpected source repository" "repoURL=${REPO_URL}"
fi

SYNC=$(K -n argocd get application "$ARGO_APP" -o jsonpath='{.status.sync.status}')
HEALTH=$(K -n argocd get application "$ARGO_APP" -o jsonpath='{.status.health.status}')
[[ "$SYNC"   == "Synced"  ]] && ok "Application is Synced"   || ko "Application is ${SYNC:-unknown}"
[[ "$HEALTH" == "Healthy" ]] && ok "Application is Healthy"  || ko "Application is ${HEALTH:-unknown}"

# ---- TEST 7 · the application in the dev namespace --------------------------
title "TEST 7 · application in the dev namespace"
if [[ "$(K -n dev get deploy wil-playground -o jsonpath='{.status.availableReplicas}')" == "1" ]]; then
  ok "deployment wil-playground is available"
else
  ko "deployment wil-playground is not available" "kubectl -n dev get pods"
fi

LIVE_IMG=$(K -n dev get deploy wil-playground -o jsonpath='{.spec.template.spec.containers[0].image}')
LIVE_TAG="${LIVE_IMG##*:}"
APP_BODY=$(curl -s --max-time 15 "http://localhost:${APP_PORT}/")
info "cluster image = ${LIVE_IMG}"
info "curl http://localhost:${APP_PORT}/ -> ${APP_BODY}"

if grep -q "\"${LIVE_TAG}\"" <<<"$APP_BODY"; then
  ok "the application answers the version it runs (${LIVE_TAG})"
else
  ko "the answer does not match the deployed image" "image=${LIVE_TAG} body=${APP_BODY}"
fi

# GitOps consistency: what GitLab holds is what the cluster runs.
if [[ -n "${REPO_TAG:-}" ]]; then
  if [[ "$REPO_TAG" == "$LIVE_TAG" ]]; then
    ok "GitLab (${REPO_TAG}) and the cluster (${LIVE_TAG}) agree"
  else
    ko "GitLab says ${REPO_TAG} but the cluster runs ${LIVE_TAG}" "Argo CD has not synced yet"
  fi
fi

# ---- TEST 8 (optional) · full continuous deployment -------------------------
if [[ "$RUN_CD" == "1" ]]; then
  title "TEST 8 · continuous deployment from GitLab (v1 <-> v2)"
  TARGET="v2"; [[ "$LIVE_TAG" == "v2" ]] && TARGET="v1"
  info "switching ${LIVE_TAG} -> ${TARGET} through the GitLab repository"
  if [[ $EUID -ne 0 ]]; then
    warn "not root: re-run with  sudo ./testKiller.sh --cd"
  elif "${SCRIPT_DIR}/scripts/switch_version.sh" "$TARGET"; then
    NEW_BODY=$(curl -s --max-time 15 "http://localhost:${APP_PORT}/")
    if grep -q "\"${TARGET}\"" <<<"$NEW_BODY"; then
      ok "the change pushed to GitLab was deployed by Argo CD (${TARGET})"
    else
      ko "the application still does not answer ${TARGET}" "body=${NEW_BODY}"
    fi
  else
    ko "switch_version.sh failed"
  fi
fi

# ---- summary ----------------------------------------------------------------
title "Summary"
printf '  %s%d passed%s, %s%d failed%s\n\n' "$G" "$PASS" "$X" \
       "$([[ $FAIL -gt 0 ]] && echo "$R" || echo "$DIM")" "$FAIL" "$X"
[[ $FAIL -eq 0 ]]
