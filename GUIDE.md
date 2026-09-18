# Inception-of-Things (IoT) — Complete Defense Guide & Technical Q&A

This guide covers everything you need to run, evaluate, and defend the **Inception-of-Things** project (Part 1, Part 2, and Part 3). It is written from one student to another: practical, straight to the point, and focused on what evaluators actually look for during the peer evaluation.

---

## Table of Contents

1. [Workflow & Resource Management](#1-workflow--resource-management)
2. [Part 1: Multi-Node K3s Cluster with Vagrant](#2-part-1-multi-node-k3s-cluster-with-vagrant)
3. [Part 2: Three Applications & Ingress on K3s](#3-part-2-three-applications--ingress-on-k3s)
4. [Part 3: K3d and Argo CD GitOps (No Vagrant)](#4-part-3-k3d-and-argo-cd-gitops-no-vagrant)
5. [Comprehensive Defense Q&A](#5-comprehensive-defense-qa)
   - [Kubernetes & K3s Fundamentals](#kubernetes--k3s-fundamentals)
   - [K3s vs Standard K8s Architecture](#k3s-vs-standard-k8s-architecture)
   - [Networking, Services, and Ingress](#networking-services-and-ingress)
   - [K3d Internals](#k3d-internals)
   - [GitOps & Argo CD](#gitops--argo-cd)
   - [Troubleshooting Scenarios](#troubleshooting-scenarios)

---

## 1. Workflow & Resource Management

Virtual machines, especially when running inside another VM without nested hardware virtualization, consume significant RAM and CPU.

**Rule of thumb during evaluation:**
Always run **one part at a time**, test it thoroughly, and tear it down before moving to the next:
- After testing `p1`: run `vagrant destroy -f` in `p1/`.
- After testing `p2`: run `vagrant destroy -f` in `p2/`.
- After testing `p3`: run `k3d cluster delete iot-cluster` in `p3/`.

---

## 2. Part 1: Multi-Node K3s Cluster with Vagrant

### Objective
Deploy two virtual machines with Vagrant on private static IPs:
- **Server (Controller)**: `youmoukhS` at `192.168.56.110` running K3s in server mode.
- **Worker (Agent)**: `youmoukhSW` at `192.168.56.111` running K3s in agent mode connected to the controller.
- Passwordless SSH access to both machines.

### Commands

```bash
cd /home/ooulcaid/iot/p1

# 1. Start the cluster
vagrant up

# 2. Check VM statuses
vagrant status

# 3. SSH into the server node
vagrant ssh youmoukhS

# 4. Check cluster nodes from inside the server
kubectl get nodes -o wide
# Expected output:
# youmoukhS    Ready   control-plane,master   ...   192.168.56.110
# youmoukhSW   Ready   <none>                 ...   192.168.56.111

# 5. Run the automated verification test from the host:
./testingKiller.sh

# 6. Teardown when done
vagrant destroy -f
```

---

## 3. Part 2: Three Applications & Ingress on K3s

### Objective
Deploy a single VM (`ynassibiS` at `192.168.56.110`) running K3s with 3 web applications routed through Traefik Ingress:
- `Host: app1.com` -> routes to **app1** (1 replica)
- `Host: app2.com` -> routes to **app2** (3 replicas)
- Any other host / direct IP request -> routes to **app3** (default fallback, 1 replica)

### Commands

```bash
cd /home/ooulcaid/iot/p2

# 1. Start the VM and let provisioning deploy the apps & ingress
vagrant up

# 2. SSH into the VM
vagrant ssh

# 3. Inspect the running pods, services, and ingress
kubectl get pods -o wide
kubectl get svc
kubectl get ingress

# 4. Test routing from the host machine:
# Test app1
curl -H "Host: app1.com" http://192.168.56.110
# Test app2 (refresh multiple times to see load-balancing across the 3 replicas)
curl -H "Host: app2.com" http://192.168.56.110
# Test app3 (default fallback, without host header or unknown host)
curl http://192.168.56.110
curl -H "Host: random.org" http://192.168.56.110

# 5. Run automated test suite:
./testKiller.sh

# 6. Teardown when done
vagrant destroy -f
```

---

## 4. Part 3: K3d and Argo CD GitOps (No Vagrant)

### Objective
Deploy a continuous deployment pipeline natively on the host machine using **k3d** (K3s in Docker) and **Argo CD** without Vagrant:
- **`argocd` namespace**: Runs the complete Argo CD suite.
- **`dev` namespace**: Runs `wil-playground` continuously deployed by Argo CD from your public Git repo.
- The app listens on port `8888` and returns `{"status":"ok", "message": "v1"}`.
- Updating `confs/app/deployment.yaml` in the Git repo to `v2` automatically syncs and updates the running app to return `{"status":"ok", "message": "v2"}`.

### Commands

```bash
cd /home/ooulcaid/iot/p3

# 1. Run the installation script (installs docker/k3d/kubectl if needed, creates cluster & deploys Argo CD)
sudo ./scripts/setup.sh

# 2. Verify namespaces
kubectl get ns
# Must show 'argocd' and 'dev' active

# 3. Verify application pod
kubectl get pods -n dev
# Shows 'wil-playground-xxxx' running

# 4. Test version 1 via curl
curl http://localhost:8888/
# Expected: {"status":"ok", "message": "v1"}

# 5. Access Argo CD Web UI
# Open browser: https://localhost:8080
# Username: admin
# Password:
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo

# 6. Demonstrate GitOps continuous deployment (v1 -> v2)
# Edit the deployment manifest:
sed -i 's/wil42\/playground:v1/wil42\/playground:v2/g' confs/app/deployment.yaml

# Commit and push to your public GitHub repo:
git commit -am "chore: update wil-playground to v2"
git push

# Wait for Argo CD to detect and sync the update (or click 'Sync' in the UI)
# Verify the updated version:
curl http://localhost:8888/
# Expected: {"status":"ok", "message": "v2"}

# 7. Teardown
k3d cluster delete iot-cluster
```

---

## 5. Comprehensive Defense Q&A

### Kubernetes & K3s Fundamentals

#### Q1: What is K3s and why use it instead of vanilla Kubernetes (K8s)?
**Answer:**
K3s is a lightweight, fully compliant, certified Kubernetes distribution developed by Rancher (SUSE). It is packaged as a single binary (<100MB) designed for resource-constrained environments (IoT, edge computing, CI/CD, local development).
Key differences:
1. **Single binary**: Combines control plane components (`kube-apiserver`, `kube-controller-manager`, `kube-scheduler`, `kubelet`) into one process.
2. **Datastore**: Replaces heavy etcd with SQLite (via Kine) by default for single-node setups, though it supports external DBs (PostgreSQL, MySQL, external etcd).
3. **Batteries-included**: Comes bundled with Traefik (Ingress Controller), Flannel (CNI), CoreDNS, Local-path-provisioner (storage), and metrics-server.
4. **Stripped legacy code**: Removes deprecated in-tree cloud providers and alpha features to minimize memory footprint.

#### Q2: What is the difference between K3s server mode and agent mode?
**Answer:**
- **Server mode (Controller)**: Runs the complete Kubernetes control plane (API server, controller manager, scheduler, datastore) plus the local agent/kubelet. It manages the cluster state, accepts `kubectl` requests, and schedules workloads.
- **Agent mode (Worker)**: Runs only the `k3s-agent` process (which includes `kubelet` and `kube-proxy`). It does not store cluster state; it registers with the server using a secure join token (`--token`) and runs containers assigned to it by the control plane.

#### Q3: What is Kubeconfig and what does `--write-kubeconfig-mode 644` mean?
**Answer:**
The kubeconfig file (`/etc/rancher/k3s/k3s.yaml`) contains the cluster endpoint, CA certificate, and client credentials that `kubectl` uses to authenticate against the Kubernetes API.
By default, K3s creates this file with permissions `600` (readable only by `root`). Adding `--write-kubeconfig-mode 644` makes it world-readable so non-root users (like the default `vagrant` user) can run `kubectl` commands without prefixing every command with `sudo`.

#### Q4: Why must `--flannel-iface` and `--node-ip` be specified during installation?
**Answer:**
Vagrant VMs usually have at least two network interfaces:
1. `eth0`: Management / NAT adapter created by the hypervisor for SSH access and Internet egress (e.g. `10.0.2.15` or `192.168.121.x`).
2. `eth1`: Private host-only network adapter with the static IP required by the subject (`192.168.56.110`).

If you don't specify `--flannel-iface` and `--node-ip`, K3s auto-selects the first interface with a default route (`eth0`). The node internal IP and flannel VXLAN overlay traffic would then bind to the NAT network instead of the private subnet `192.168.56.0/24`, which breaks inter-node communication and fails the evaluation requirements.

---

### Networking, Services, and Ingress

#### Q5: What is the difference between a Pod, a Service, and an Ingress?
**Answer:**
- **Pod**: The smallest deployable computing unit in K8s. It contains one or more containers sharing network namespaces and storage. Pod IPs are ephemeral—when a pod restarts or scales, its IP changes.
- **Service**: An abstraction that defines a logical set of Pods and a policy to access them. It assigns a stable virtual IP (`ClusterIP`) and DNS name, load-balancing traffic across all matching pods defined by label selectors (`selector: app: my-app`).
- **Ingress**: An API object that manages external access to services inside the cluster, typically HTTP/HTTPS. It provides name-based virtual hosting, path-based routing, and SSL termination without exposing individual services on separate external IPs or high ports.

#### Q6: How does Host-based routing work in Part 2?
**Answer:**
The K3s Ingress Controller (Traefik) listens on ports 80 and 443 of the node.
When an HTTP request arrives, Traefik inspects the HTTP `Host` header:
- If `Host: app1.com`, Traefik forwards the request to `app1-service` on port 80.
- If `Host: app2.com`, Traefik forwards the request to `app2-service` on port 80, which distributes traffic across its 3 replicas.
- If the `Host` header is missing, unknown, or set to the IP itself (`http://192.168.56.110`), Traefik matches the host-less fallback rule in `ingress.yaml` and routes the traffic to `app3-service`.

#### Q7: How does Kubernetes handle `replicas: 3` for app2?
**Answer:**
The `Deployment` controller ensures that exactly 3 pod instances matching the template labels are running at all times (declarative desired state). If one container crashes or is killed, the controller immediately schedules a replacement pod.
The `Service` finds all active pods matching `app: app2` and registers their IP addresses as endpoints. Incoming HTTP requests to `app2.com` are distributed round-robin across the 3 replicas.

---

### K3d Internals

#### Q8: What is K3d and how does it differ from K3s?
**Answer:**
- **K3s** runs directly on an operating system (bare metal or virtual machines), managing containers via containerd.
- **K3d** is a client tool / wrapper created by Rancher that runs K3s nodes inside **Docker containers**. Each K3s "node" is actually a Docker container running `rancher/k3s`.
- Advantages: Spinning up a cluster takes under 15 seconds, requires zero hypervisor or VM overhead, and allows multi-node cluster topologies on a developer's laptop with minimal RAM.

#### Q9: How does port exposure work in K3d (`--port "8888:80@loadbalancer"`)?
**Answer:**
K3d automatically creates an auxiliary container called `k3d-<cluster>-serverlb` (running NGINX as a reverse proxy).
The flag `--port "8888:80@loadbalancer"` maps host port `8888` to port `80` inside this load balancer container. The load balancer forwards traffic to port 80 of the K3s server nodes where Traefik is listening. Traefik's Ingress then evaluates the routing rules and forwards the request to the application service (`wil-playground:8888`). As a result, `curl http://localhost:8888/` reaches the app directly.

---

### GitOps & Argo CD

#### Q10: What is GitOps?
**Answer:**
GitOps is an operational model where the entire infrastructure and application state is stored declaratively in a **Git repository**, which serves as the **single source of truth**.
Key principles:
1. **Declarative description**: The entire desired state is described in declarative files (YAML manifests, Helm charts, Kustomize).
2. **Versioned & immutable**: Any change is made via Git commits, pull requests, and code reviews, providing a full audit trail.
3. **Automated pull-based deployment**: An agent inside the cluster (Argo CD) continuously monitors the Git repository and automatically applies changes, pulling updates instead of an external CI pipeline pushing credentials into the cluster.
4. **Continuous reconciliation & self-healing**: If someone modifies the live cluster manually (`kubectl edit`), the GitOps controller detects the drift and resets the cluster back to the state committed in Git.

#### Q11: How does Argo CD reconcile state?
**Answer:**
Argo CD runs a control loop (reconciliation loop):
1. **Fetch Desired State**: Clones the Git repository at `targetRevision` and compiles the manifests in `path`.
2. **Fetch Live State**: Queries the Kubernetes API server for the actual state of resources in `destination.namespace`.
3. **Compare**: Calculates the diff between Desired State and Live State:
   - If identical -> Application status is `Synced` and `Healthy`.
   - If diff detected -> Application status is `OutOfSync`.
4. **Reconcile**: When automated sync is enabled (`syncPolicy.automated`), Argo CD applies the manifests to the cluster. If `selfHeal: true` is set, unauthorized manual cluster changes are overwritten. If `prune: true` is set, resources deleted from Git are removed from the cluster.

#### Q12: Walk through what happens when updating `wil42/playground:v1` to `v2`.
**Answer:**
1. Developer edits `p3/confs/app/deployment.yaml` and changes the container image tag from `v1` to `v2`.
2. Developer commits and pushes the change to the public GitHub repository.
3. Argo CD polls the Git repository (or receives a webhook notification). It detects that the live deployment uses `v1` while Git specifies `v2`.
4. Argo CD marks the app as `OutOfSync` and triggers an automated sync.
5. Argo CD applies the updated `Deployment` manifest via the Kubernetes API.
6. The Kubernetes Deployment controller performs a rolling update:
   - Spins up a new ReplicaSet running `wil42/playground:v2`.
   - Waits for the new pod's readiness probe to pass.
   - Updates service endpoints to the new pod.
   - Terminates the old `v1` pod.
7. Querying `curl http://localhost:8888/` seamlessly transitions from `{"status":"ok", "message": "v1"}` to `{"status":"ok", "message": "v2"}` with zero downtime.

---

### Troubleshooting Scenarios

#### Q13: What should you do if a pod is in `ImagePullBackOff` or `ErrImagePull`?
**Answer:**
- Inspect the error: `kubectl describe pod <pod-name> -n <namespace>`
- Common causes:
  1. Typo in image name or tag (e.g. `wil42/playground:v3` which does not exist).
  2. Private registry requiring `imagePullSecrets`.
  3. Network connectivity or DNS failure from the node to the container registry.

#### Q14: What should you do if a pod is stuck in `CrashLoopBackOff`?
**Answer:**
- Check application logs: `kubectl logs <pod-name> -n <namespace> --previous`
- Check events: `kubectl describe pod <pod-name> -n <namespace>`
- Common causes:
  1. Application startup failure (bad command, missing environment variables, config file error).
  2. Failed liveness or readiness probes.
  3. Insufficient memory/CPU leading to OOMKilled (exit code 137).

#### Q15: How do you verify K3s service health directly on a VM?
**Answer:**
- Check systemd service status:
  `sudo systemctl status k3s` (server) or `sudo systemctl status k3s-agent` (worker)
- View service logs in real time:
  `sudo journalctl -u k3s -f`
- Check flannel network status:
  `ip a` (look for `flannel.1` interface) and `ip route`

