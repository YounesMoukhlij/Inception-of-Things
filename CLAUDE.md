# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

42 school "Inception-of-Things": an infrastructure exercise, not an application. There is no source code to build, no test suite, and no linter. "Running" the project means bringing up VMs with Vagrant and checking the resulting K3s cluster. Each part lives in its own top-level directory (`p1/`, `p2/`, `p3/`, `bonus/`); only **p2** is implemented so far.

Everything is driven by two things: a `Vagrantfile` that defines the VM(s), and a shell provisioning script that installs K3s and applies manifests from `confs/`.

## p2 — single K3s server + three apps behind one Ingress

One `ubuntu/jammy64` VM at `192.168.56.110` running K3s in server mode. Traefik (bundled with K3s) routes by HTTP `Host` header: `app1.com` → app1 (1 replica), `app2.com` → app2 (3 replicas), and a host-less rule catches everything else → app3 (1 replica). All three use the same `paulbouwer/hello-kubernetes:1.10` image, differing only by the `MESSAGE` env var and replica count.

The three pieces that must stay in sync are the IP in [Vagrantfile](p2/Vagrantfile), `NODE_IP` in [scripts/setup.sh](p2/scripts/setup.sh#L11), and the curl targets in [p2/README.md](p2/README.md). Changing the subnet means changing all three.

### Commands (run from `p2/`)

```bash
vagrant up                 # create + provision (provider is forced to virtualbox)
vagrant provision          # re-run setup.sh on a running VM
vagrant ssh                # then: kubectl get nodes -o wide / kubectl get all
vagrant destroy -f         # tear down
```

Verification from the **host** (this is how the project is evaluated):

```bash
curl 192.168.56.110                       # -> Hello from app3
curl -H "Host: app1.com" 192.168.56.110   # -> Hello from app1
curl -H "Host: app2.com" 192.168.56.110   # -> Hello from app2
```

### Things that bite

- **Synced folder is rsync, not a live mount.** Mandatory, not a preference: `ubuntu/jammy64` ships without VirtualBox Guest Additions, so `vboxsf` cannot mount `/vagrant` at all. Editing `confs/*.yaml` on the host does nothing until `vagrant rsync` (or `vagrant provision`, which rsyncs first). `setup.sh` applies the whole directory with `kubectl apply -f /vagrant/confs/`.
- **`setup.sh` must stay idempotent** — it is re-run in full by `vagrant provision`. The K3s installer and `kubectl apply` are both safe to repeat; the `.bashrc` KUBECONFIG line is guarded with `grep -q`.
- **The private network is the *second* NIC.** `setup.sh` resolves the interface owning `NODE_IP` and passes it as `--node-ip` and `--flannel-iface`. Without this the node's internal IP lands on the NAT interface and the evaluation fails. Do not hardcode `eth1`.
- **`192.168.56.0/24` is the one host-only range VirtualBox permits by default.** Moving to another subnet requires adding it to `/etc/vbox/networks.conf` on the host, or `vagrant up` fails when creating the interface.
- **Secure Boot blocks `vboxdrv`.** On a locked-down kernel the DKMS-built VirtualBox modules are unsigned and never load, so `/dev/vboxdrv` is missing and every `vagrant up` fails. See the Host setup section of [p2/README.md](p2/README.md) for the MOK-enrollment fix.
- **Machine name is `<42login>S`** (`ynassibiS`), derived from the `LOGIN` constant. The git branch matches. The subject requires this naming.
- `--write-kubeconfig-mode=644` is deliberate — it lets the `vagrant` user read the kubeconfig that `setup.sh` copies to `~/.kube/config`.

## Conventions for new parts

Follow the p2 layout when adding `p1/`, `p3/`, or `bonus/`: `Vagrantfile` at the part root, provisioning in `scripts/`, Kubernetes manifests in `confs/`, and a part-level `README.md` documenting IPs, expected outputs, and host prerequisites. Keep `.vagrant/` gitignored per part.
