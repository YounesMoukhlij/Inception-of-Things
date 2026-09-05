#!/usr/bin/env bash
set -eu

SERVER_IP="$1"

# Find the name of the interface that carries our static private-network IP
# (modern distros use predictable names like enp0s8, not eth1).
IFACE=$(ip -4 -o addr show | awk -v ip="$SERVER_IP" '$0 ~ ip {print $2}')

echo ">>> Finalizing K3s config (iface: $IFACE)"
sed -i "s/__IFACE__/$IFACE/" /tmp/config.yaml
mkdir -p /etc/rancher/k3s
mv /tmp/config.yaml /etc/rancher/k3s/config.yaml

echo ">>> Installing K3s in SERVER mode on $SERVER_IP"
curl -sfL https://get.k3s.io | sh -s - server

# Wait until k3s has generated the node-token, then share it with the worker
# node through the /vagrant synced folder (mounted on both VMs).
echo ">>> Waiting for node-token..."
until [ -f /var/lib/rancher/k3s/server/node-token ]; do
  sleep 2
done
cp /var/lib/rancher/k3s/server/node-token /vagrant/token

# Install a standalone kubectl binary (k3s already ships one, but the
# subject explicitly asks for kubectl to be installed).
if ! command -v kubectl >/dev/null 2>&1; then
  echo ">>> Installing kubectl"
  curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
  install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
  rm -f kubectl
fi

# Make kubeconfig usable straight away for the vagrant user.
mkdir -p /home/vagrant/.kube
cp /etc/rancher/k3s/k3s.yaml /home/vagrant/.kube/config
chown -R vagrant:vagrant /home/vagrant/.kube
echo "export KUBECONFIG=/home/vagrant/.kube/config" >> /home/vagrant/.bashrc

echo ">>> K3s server ready."
