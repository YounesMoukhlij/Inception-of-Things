# IoT - Part 2: K3s and three simple applications (VirtualBox)

Single `ubuntu/jammy64` VM running K3s (server mode) at `192.168.56.110`, serving
three apps routed by HTTP Host header via a Traefik Ingress.

| Host        | App  | Replicas |
|-------------|------|----------|
| app1.com    | app1 | 1        |
| app2.com    | app2 | 3        |
| *(anything else / default)* | app3 | 1 |

## Host setup (one time)
```
# Debian/Ubuntu host:
sudo apt install -y virtualbox virtualbox-dkms linux-headers-$(uname -r) \
                    vagrant rsync
```
No Vagrant plugin is needed - the VirtualBox provider ships with Vagrant.

### If Secure Boot is enabled
VirtualBox's kernel modules are built by DKMS but are unsigned, so a locked-down
kernel refuses to load them and `/dev/vboxdrv` never appears. Check with:
```
mokutil --sb-state
ls -l /dev/vboxdrv
```
If Secure Boot is on, either turn it off in the BIOS/UEFI setup, or enroll a
signing key:
```
sudo mokutil --import /var/lib/shim-signed/mok/MOK.der   # set a one-time password
sudo reboot                                             # enroll the key in the MOK manager
sudo modprobe vboxdrv                                   # should now succeed
```

## Before you run
Open `Vagrantfile` and replace `login` with your 42 login (machine name = `<login>S`).

## Run
```
vagrant up
vagrant ssh
kubectl get nodes -o wide
kubectl get all
```

## Test (from the HOST machine)
```
curl 192.168.56.110                       # -> Hello from app3
curl -H "Host: app1.com" 192.168.56.110   # -> Hello from app1
curl -H "Host: app2.com" 192.168.56.110   # -> Hello from app2
```

## System design (PDF)
`k3s-system-design.pdf` -- 7 hand-drawn pages: the whole stack on one page, what the
three files do, why server mode, why an Ingress, how `replicas: 3` becomes 3 pods,
one request end to end, and the failures worth knowing in advance.

Regenerate it with:
```
python3 docs/build.py k3s-system-design.pdf     # needs reportlab
```

Layout:
```
p2/
├── Vagrantfile
├── k3s-system-design.pdf
├── docs/           # generator for the PDF
├── scripts/setup.sh
└── confs/{app1,app2,app3,ingress}.yaml
```
