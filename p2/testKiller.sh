#!/usr/bin/env bash
# ============================================================================
#  IoT · show-and-run tests  (native Ubuntu)
#  Prints each command, then runs it — so you can SEE every test.
#
#  Usage:   ./test.sh 1 [login]     # run inside your p1/ folder
#           ./test.sh 2 [login]     # run inside your p2/ folder
#           (login defaults to ynassibi)
# ============================================================================

PART="${1:-2}"
LOGIN="${2:-ynassibi}"
SERVER="${LOGIN}S"        # p1 server / p2 vm
WORKER="${LOGIN}SW"       # p1 worker
IP="192.168.56.110"

if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
  G=$'\e[32m'; B=$'\e[34m'; C=$'\e[36m'; BOLD=$'\e[1m'; DIM=$'\e[2m'; X=$'\e[0m'
else G=; B=; C=; BOLD=; DIM=; X=; fi

title() { printf '\n%s%s━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━%s\n' "$BOLD" "$B" "$X"
          printf '%s%s  %s%s\n' "$BOLD" "$B" "$1" "$X"
          printf '%s%s━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━%s\n' "$BOLD" "$B" "$X"; }
# run(): print the command in cyan, then execute it
run() { printf '\n%s$ %s%s\n' "$C" "$1" "$X"; eval "$1"; }

# ---------------------------------------------------------------- PART 1
p1() {
  title "PART 1 · two-node cluster ($SERVER + $WORKER)"
  run "vagrant status"
  run "vagrant ssh $SERVER -c 'kubectl get nodes -o wide'"
  run "vagrant ssh $SERVER  -c 'hostname'"
  run "vagrant ssh $WORKER  -c 'hostname'"
  run "vagrant ssh $SERVER  -c 'ip -4 addr show eth1 | grep inet'"
  run "vagrant ssh $WORKER  -c 'ip -4 addr show eth1 | grep inet'"
  run "vagrant ssh $SERVER  -c 'systemctl is-active k3s'"
  run "vagrant ssh $WORKER  -c 'systemctl is-active k3s-agent'"
  printf '\n%sExpect: 2 nodes Ready — %s=control-plane,master(.110), %s=<none>(.111)%s\n' \
         "$DIM" "$SERVER" "$WORKER" "$X"
}

# ---------------------------------------------------------------- PART 2
p2() {
  title "PART 2 · K3s + three apps ($SERVER)"
  run "vagrant status"
  run "vagrant ssh $SERVER -c 'kubectl get nodes -o wide'"
  run "vagrant ssh $SERVER -c 'kubectl get pods'"
  run "vagrant ssh $SERVER -c 'kubectl get deploy'"
  run "vagrant ssh $SERVER -c 'kubectl get svc'"
  run "vagrant ssh $SERVER -c 'kubectl get ingress'"

  title "PART 2 · routing (curl from the host — Ubuntu reaches $IP directly)"
  run "curl -s $IP;                       echo"
  run "curl -s -H 'Host: app1.com' $IP;   echo"
  run "curl -s -H 'Host: app2.com' $IP;   echo"

  title "PART 2 · app2 load-balancing (pod name should change)"
  run "for i in 1 2 3 4 5 6; do curl -s -H 'Host: app2.com' $IP | grep -i pod; done"
  printf '\n%sExpect: plain→app3, app1.com→app1, app2.com→app2 ; app2 hits different pods%s\n' "$DIM" "$X"
}

# ---------------------------------------------------------------- dispatch
[[ -f Vagrantfile ]] || { echo "No Vagrantfile here — run this from your p${PART}/ folder."; exit 1; }
case "$PART" in
  1) p1 ;;
  2) p2 ;;
  *) echo "Usage: ./test.sh [1|2] [login]"; exit 1 ;;
esac