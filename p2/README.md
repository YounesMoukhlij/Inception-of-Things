# IoT - Part 2: K3s and three simple applications (libvirt/KVM)

Single VM running K3s (server mode) at `192.168.56.110`, serving three apps
routed by HTTP Host header via a Traefik Ingress.

| Host        | App  | Replicas |
|-------------|------|----------|
| app1.com    | app1 | 1        |
| app2.com    | app2 | 3        |
| *(anything else / default)* | app3 | 1 |

## Host setup (one time)
```
# Debian/Ubuntu host:
sudo apt install -y qemu-kvm libvirt-daemon-system libvirt-dev \
                    ebtables dnsmasq-base ruby-dev gcc make pkg-config
sudo usermod -aG libvirt,kvm $USER      # then log out/in
vagrant plugin install vagrant-libvirt
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

Layout:
```
p2/
├── Vagrantfile
├── scripts/setup.sh
└── confs/{app1,app2,app3,ingress}.yaml
```
