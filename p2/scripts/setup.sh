#!/bin/bash
# ============================================================================
#  Provisioning script - runs once, as root, inside the VM.
#  1. Installs K3s (latest stable) in server mode on the private-network IP.
#  2. Waits for the node to be Ready.
#  3. Applies the three apps + the ingress.
#  4. Makes kubectl usable for the "vagrant" user (no sudo needed).
# ============================================================================
set -e

NODE_IP="192.168.56.110"

echo "==> Detecting the private-network interface that owns ${NODE_IP}"
# The first NIC (eth0 / enp0s3) is the management network (SSH + internet);
# the private network is the second NIC. We must tell K3s + flannel to use THAT
# interface, otherwise the node internal IP will be wrong and the evaluation fails.
IFACE=$(ip -o -4 addr show | awk -v ip="${NODE_IP}" '$4 ~ ip {print $2; exit}')
echo "    interface = ${IFACE}"

echo "==> Installing K3s (server mode)"
export INSTALL_K3S_EXEC="server --node-ip=${NODE_IP} --flannel-iface=${IFACE} --write-kubeconfig-mode=644"
curl -sfL https://get.k3s.io | sh -

echo "==> Waiting for the node to become Ready"
until k3s kubectl get nodes 2>/dev/null | grep -q " Ready"; do
  sleep 5
done

echo "==> Deploying the three applications + ingress"
k3s kubectl apply -f /vagrant/confs/

echo "==> Making kubectl usable for the vagrant user"
mkdir -p /home/vagrant/.kube
cp /etc/rancher/k3s/k3s.yaml /home/vagrant/.kube/config
chown -R vagrant:vagrant /home/vagrant/.kube
grep -q 'KUBECONFIG' /home/vagrant/.bashrc || \
  echo 'export KUBECONFIG=/home/vagrant/.kube/config' >> /home/vagrant/.bashrc

echo "==> Done. Current cluster state:"
k3s kubectl get all
