#!/bin/bash

# Setup script for K3s Worker (Agent mode)
# This script installs K3s in agent mode and joins the cluster

set -e

# Define IPs
SERVER_IP="192.168.56.110"
WORKER_IP="192.168.56.111"


# ------------------------------------------------------------------
# Detect the interface that already carries the private-network IP instead
# of hardcoding a name like enp0s8, which can vary across base boxes.
# ------------------------------------------------------------------

IFACE=$(ip -4 -o addr show | awk -v ip="$WORKER_IP" '$0 ~ ip {print $2; exit}')

echo "=== Installing K3s in Agent (Worker) mode ==="
echo "Using network interface: ${IFACE}"


# ------------------------------------------------------------------
# FIX Nested virtualization for networking problems
# ------------------------------------------------------------------


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

echo "=== Disabled NIC offload and capped MTU on all interfaces ✅==="


# ------------------------------------------------------------------
# Wait until the server's API reports ready, instead of polling forever for a
# TCP connection that may never become usable.
# ------------------------------------------------------------------

API_WAIT_INTERVAL=5     # seconds between polls
API_WAIT_ATTEMPTS=240   # 240 x 5s = 20 minutes
API_WAIT_MINUTES=$((API_WAIT_ATTEMPTS * API_WAIT_INTERVAL / 60))

echo "=== Waiting up to ${API_WAIT_MINUTES}m for the K3s server API at ${SERVER_IP}:6443 ==="
sleep 5 
for attempt in $(seq 1 "${API_WAIT_ATTEMPTS}"); do
    http_code=$(curl -sk --max-time 2 -o /dev/null -w '%{http_code}' \
        "https://${SERVER_IP}:6443/readyz" || true)
    if [ "${http_code}" = "200" ] || [ "${http_code}" = "401" ]; then
        break
    fi

    if [ "${attempt}" -eq "${API_WAIT_ATTEMPTS}" ]; then
        echo "Timed out after ${API_WAIT_MINUTES}m waiting for the K3s server API."
        echo "Is the server VM up and fully provisioned? Network diagnostics:"
        ip route
        curl -vk --max-time 5 "https://${SERVER_IP}:6443/readyz" || true
        exit 1
    fi

    if [ "$((attempt % 6))" -eq 1 ]; then
        echo "Server not ready yet, still retrying ($((attempt * API_WAIT_INTERVAL))s elapsed)..."
    fi
    sleep "${API_WAIT_INTERVAL}"
done
echo "=== K3s server API is ready ✅==="

# ------------------------------------------------------------------
# Install K3s in agent mode
# ------------------------------------------------------------------

curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="agent \
    --server https://${SERVER_IP}:6443 \
    --token ${K3S_TOKEN} \
    --node-ip ${WORKER_IP} \
    --flannel-iface ${IFACE}" sh -


echo ""
echo "=== K3s Worker setup complete ✅==="
echo "=== K3s Worker kubeconfig is at /etc/rancher/k3s/k3s.yaml ==="
echo ""