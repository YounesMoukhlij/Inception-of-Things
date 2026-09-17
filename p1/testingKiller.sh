#!/usr/bin/env bash
# ============================================================================
#  IoT - Part 1  ·  cluster test
#  Verifies the two-node K3s cluster (server + worker) from the host.
#  Usage:   ./test_p1.sh [login]      (login defaults to youmoukh)
#           NO_COLOR=1 ./test_p1.sh   to disable colors
# ============================================================================

LOGIN="${1:-youmoukh}"          # <-- your intra login (machine names use this)
SERVER="${LOGIN}S"              # -> youmoukhS
WORKER="${LOGIN}SW"             # -> youmoukhSW
SERVER_IP="192.168.56.110"
WORKER_IP="192.168.56.111"

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

ssh_server() { vagrant ssh "$SERVER" -c "$1" 2>/dev/null; }
ssh_worker() { vagrant ssh "$WORKER" -c "$1" 2>/dev/null; }

# ---- pre-flight -------------------------------------------------------------
title "Pre-flight"
command -v vagrant >/dev/null || { ko "vagrant not found in PATH"; exit 1; }
[[ -f Vagrantfile ]] || { ko "no Vagrantfile here" "run this from your p1/ folder"; exit 1; }
info "login=${LOGIN}  server=${SERVER} (${SERVER_IP})  worker=${WORKER} (${WORKER_IP})"

# ---- TEST 1 · both VMs running ---------------------------------------------
title "TEST 1 · both VMs are running"
ST=$(vagrant status 2>/dev/null)
for vm in "$SERVER" "$WORKER"; do
  state=$(awk -v n="$vm" '$1==n{print $2}' <<<"$ST")
  if [[ "$state" == "running" ]]; then ok "$vm is running"
  else ko "$vm is not running" "state='${state:-missing}' — run: vagrant up"; fi
done

# ---- wait for the cluster to converge --------------------------------------
title "TEST 2 · cluster forms (both nodes Ready)"
info "waiting for the worker to join (up to ~2 min)…"
NODES=""
for i in $(seq 1 24); do
  NODES=$(ssh_server "kubectl get nodes -o wide --no-headers 2>/dev/null")
  ready=$(awk '$2=="Ready"{c++} END{print c+0}' <<<"$NODES")
  [[ "${ready:-0}" -ge 2 ]] && break
  sleep 5
done
count=$(awk 'NF{c++} END{print c+0}' <<<"$NODES")
if [[ "$count" -eq 2 ]]; then ok "exactly 2 nodes in the cluster"
else ko "expected 2 nodes, found ${count:-0}" "worker may still be joining, or the join failed"; fi

sline=$(awk -v n="$SERVER" '$1==n' <<<"$NODES")
wline=$(awk -v n="$WORKER" '$1==n' <<<"$NODES")

# ---- TEST 3 · server node ---------------------------------------------------
title "TEST 3 · server node ($SERVER)"
[[ "$(awk '{print $2}' <<<"$sline")" == "Ready" ]] && ok "$SERVER is Ready" || ko "$SERVER not Ready" "$sline"
grep -q "control-plane" <<<"$sline"  && ok "role is control-plane,master" || ko "wrong role for $SERVER" "$sline"
grep -q "$SERVER_IP"   <<<"$sline"   && ok "INTERNAL-IP is $SERVER_IP"     || ko "wrong IP for $SERVER" "$sline"

# ---- TEST 4 · worker node ---------------------------------------------------
title "TEST 4 · worker node ($WORKER)"
[[ "$(awk '{print $2}' <<<"$wline")" == "Ready" ]] && ok "$WORKER is Ready" || ko "$WORKER not Ready" "$wline"
grep -q "<none>"      <<<"$wline" && ok "role is <none> (worker)" || ko "unexpected role for $WORKER" "$wline"
grep -q "$WORKER_IP"  <<<"$wline" && ok "INTERNAL-IP is $WORKER_IP" || ko "wrong IP for $WORKER" "$wline"

# ---- TEST 5 · hostnames -----------------------------------------------------
title "TEST 5 · hostnames (login + S / SW)"
[[ "$(ssh_server hostname)" == "$SERVER" ]] && ok "server hostname is $SERVER" || ko "server hostname mismatch"
[[ "$(ssh_worker hostname)" == "$WORKER" ]] && ok "worker hostname is $WORKER" || ko "worker hostname mismatch"

# ---- TEST 6 · K3s services --------------------------------------------------
title "TEST 6 · K3s services"
[[ "$(ssh_server 'systemctl is-active k3s')"        == "active" ]] && ok "k3s (server) is active"       || ko "k3s server not active"
[[ "$(ssh_worker 'systemctl is-active k3s-agent')"  == "active" ]] && ok "k3s-agent (worker) is active" || ko "k3s-agent not active"

# ---- summary ----------------------------------------------------------------
title "SUMMARY"
printf '  %s%d passed%s   %s%d failed%s\n' "$G" "$PASS" "$X" "$R" "$FAIL" "$X"
if [[ "$FAIL" -eq 0 ]]; then
  printf '\n%s%s  ✔ Part 1 looks good — both nodes Ready.%s\n\n' "$BOLD" "$G" "$X"; exit 0
else
  printf '\n%s%s  ✗ Some checks failed — see above.%s\n' "$BOLD" "$R" "$X"
  printf '    %sworker not joining?  vagrant ssh %s -c "sudo journalctl -u k3s-agent | tail -30"%s\n\n' "$DIM" "$WORKER" "$X"
  exit 1
fi