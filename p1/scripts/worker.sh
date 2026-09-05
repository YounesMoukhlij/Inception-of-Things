#!/usr/bin/env bash
set -eu

SERVER_IP="$1"
WORKER_IP="$2"

IFACE=$(ip -4 -o addr show | awk -v ip="$WORKER_IP" '$0 ~ ip {print $2}')

echo ">>> Waiting for the server's node-token to be shared via /vagrant..."
until [ -f /vagrant/token ]; do
  sleep 2
done
TOKEN=$(cat /vagrant/token)

echo ">>> Finalizing K3s config (iface: $IFACE)"
sed -i "s/__IFACE__/$IFACE/" /tmp/config.yaml
# '#' delimiter: the token can contain characters like ':' that would
# collide with the usual '/' sed delimiter.
sed -i "s#__TOKEN__#$TOKEN#" /tmp/config.yaml
mkdir -p /etc/rancher/k3s
mv /tmp/config.yaml /etc/rancher/k3s/config.yaml

echo ">>> Installing K3s in AGENT mode on $WORKER_IP, joining $SERVER_IP"
curl -sfL https://get.k3s.io | sh -s - agent

echo ">>> K3s agent ready."
