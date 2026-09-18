#!/bin/bash

# Setup script for K3s Server (Controller mode)
# This script installs K3s in server mode and configures kubectl

set -e

# Define the server IP
SERVER_IP="192.168.56.110"

# ------------------------------------------------------------------
# Detect the interface that already carries the private-network IP instead
# of hardcoding a name like enp0s8, which can vary across base boxes.
# ------------------------------------------------------------------

IFACE=$(ip -4 -o addr show | awk -v ip="$SERVER_IP" '$0 ~ ip {print $2; exit}')

echo "=== Installing K3s in Server (Controller) mode ==="
echo "Using network interface: ${IFACE}"

ALL_IFACES=$(ip -o link show | awk -F': ' '{print $2}' | grep -v '^lo$')
for iface in ${ALL_IFACES}; do
    ethtool -K "${iface}" tx off rx off gso off gro off tso off 2>/dev/null || true
    ip link set dev "${iface}" mtu 1400 2>/dev/null || true
done
{
    echo "[Unit]"
    echo "Description=Disable NIC offload and cap MTU on all interfaces (nested virtualization workaround)"
    echo "After=network-online.target"
    echo "Wants=network-online.target"
    echo
    echo "[Service]"
    echo "Type=oneshot"
    for iface in ${ALL_IFACES}; do
        echo "ExecStart=/sbin/ethtool -K ${iface} tx off rx off gso off gro off tso off"
        echo "ExecStart=/sbin/ip link set dev ${iface} mtu 1400"
    done
    echo
    echo "[Install]"
    echo "WantedBy=multi-user.target"
} > /etc/systemd/system/disable-nic-offload.service
systemctl daemon-reload
systemctl enable --now disable-nic-offload.service

# Install K3s in server mode
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server \
    --write-kubeconfig-mode 644 \
    --node-ip ${SERVER_IP} \
    --bind-address ${SERVER_IP} \
    --flannel-iface ${IFACE} \
    --disable traefik \
    --disable servicelb \
    --disable metrics-server \
    --token ${K3S_TOKEN}" sh -



# ------------------------------------------------------------------
# Wait for K3s to be ready. The API can take longer to initialize while the
# control-plane components and embedded datastore start on the VM.
# ------------------------------------------------------------------


echo "=== Waiting for K3s API at ${SERVER_IP}:6443 ==="
for attempt in $(seq 1 60); do
    if curl -sk --max-time 2 "https://${SERVER_IP}:6443/readyz" >/dev/null 2>&1; then
        break
    fi

    if ! systemctl is-active --quiet k3s; then
        echo "K3s stopped before its API became ready. Recent service log:"
        journalctl -u k3s --no-pager -n 40
        exit 1
    fi

    if [ "${attempt}" -eq 60 ]; then
        echo "Timed out waiting for the K3s API. Recent service log:"
        journalctl -u k3s --no-pager -n 40
        exit 1
    fi

    sleep 5
done
echo "=== K3s API is ready ✅==="


# ------------------------------------------------------------------
# Wait for the server node to register with the API. The API can be ready
# before the local kubelet has completed its first registration.
# ------------------------------------------------------------------


echo "=== Waiting for the K3s server node to register ==="
for attempt in $(seq 1 60); do
    nodes=$(kubectl get nodes --no-headers 2>/dev/null || true)
    if [ -n "${nodes}" ]; then
        break
    fi

    if ! systemctl is-active --quiet k3s; then
        echo "K3s stopped before the server node registered. Recent service log:"
        journalctl -u k3s --no-pager -n 60
        exit 1
    fi

    if [ "${attempt}" -eq 60 ]; then
        echo "Timed out waiting for the K3s server node to register. Recent service log:"
        journalctl -u k3s --no-pager -n 60
        exit 1
    fi

    echo "Server node not registered yet, retrying (${attempt}/60)..."
    sleep 5
done
echo "=== K3s server node registered Successfully ✅==="


# ------------------------------------------------------------------
# Verify K3s installation.
# ------------------------------------------------------------------

echo "=== Verifying K3s installation ==="
kubectl get nodes -o wide

echo ""
echo "=== K3s Server setup complete ✅==="
echo "=== K3s Server kubeconfig is at /etc/rancher/k3s/k3s.yaml ==="
echo ""