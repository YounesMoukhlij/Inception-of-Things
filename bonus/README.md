# Bonus - Part 3 with a local GitLab

## Overview

The bonus re-plays Part 3, but the Git repository Argo CD pulls from is no
longer GitHub: it is a **GitLab instance running inside the cluster**.

| Namespace | Content |
|-----------|---------|
| `gitlab`  | GitLab CE (official omnibus image, latest release) |
| `argocd`  | Argo CD, cloning the repository hosted by the local GitLab |
| `dev`     | `wil-playground`, continuously deployed by Argo CD |

Ports published by the k3d load balancer (both reach Traefik):

| Host port | Used by | Route |
|-----------|---------|-------|
| `80`      | GitLab  | Ingress with `Host: gitlab.local` |
| `8888`    | Application | catch-all Ingress (no host rule) |

### Why the omnibus image and not the Helm chart

The subject suggests Helm, and the official chart was the natural choice — but
since **chart v10.0.0 it no longer bundles PostgreSQL, Redis and object
storage**, and refuses to render without external ones:

```text
redis:      You must configure a Redis connection [...] Since chart v10.0.0,
            external Redis became required.
postgresql: You must configure a PostgreSQL connection [...] Since chart v10.0.0,
            external PostgreSQL became required.
```

The chart is therefore no longer self-contained: it would mean running and
wiring a separate database, cache and S3-compatible storage for a local lab.
The official `gitlab/gitlab-ce` image ships that whole stack (Puma, Workhorse,
Gitaly, PostgreSQL, Redis, NGINX) and always is the latest GitLab release, so
it is what [confs/gitlab/statefulset.yaml](confs/gitlab/statefulset.yaml)
deploys. (Pinning the chart to 9.x would work too, but that is an older GitLab.)

### One URL, on the host and inside the cluster

Argo CD clones `http://gitlab.local/root/iot.git` — the very URL GitLab shows
in its UI. It resolves on both sides:

- **host**: `setup.sh` adds `127.0.0.1 gitlab.local` to `/etc/hosts`, host port
  `80` is mapped to Traefik and the GitLab Ingress matches that host;
- **cluster**: a CoreDNS `rewrite`
  ([confs/gitlab/coredns-custom.yaml](confs/gitlab/coredns-custom.yaml)) maps
  `gitlab.local` to the `gitlab` Service
  ([confs/gitlab/service.yaml](confs/gitlab/service.yaml)).

The project is created **public**, so Argo CD clones it anonymously: no
credentials stored in the cluster, exactly like the GitHub repo of Part 3.

## Requirements

Linux host with Docker; `kubectl`, `k3d` and `git` are installed by the script
if missing. GitLab needs about **4 GB of free RAM**, ~5 GB of disk and **15 to
25 minutes on the first boot**: the image is 1.5 GB, then omnibus runs
`gitlab-ctl reconfigure` and the database migrations. Later boots take ~5 min.
Follow it with `kubectl -n gitlab get pods -w`.

Host ports `80` and `8888` must be free — delete the Part 3 cluster first:

```bash
k3d cluster delete iot-cluster
```

## How to run

```bash
cd bonus
sudo ./scripts/setup.sh
```

It installs the dependencies, creates the `iot-bonus` cluster and the three
namespaces, deploys GitLab, creates the public `root/iot` project seeded with
[confs/app](confs/app), then installs Argo CD and its
[Application](confs/argocd/application.yaml). Both UIs and their credentials
are printed at the end.

## Verification

### 1. Namespaces and pods

```bash
kubectl get ns
kubectl get pods -n gitlab
kubectl get pods -n dev
```

### 2. GitLab

`http://gitlab.local/` — login `root`, password `Iot42-Bonus-Pass` (set at the
top of [scripts/setup.sh](scripts/setup.sh)). The repository is
`http://gitlab.local/root/iot`.

### 3. Argo CD

`https://localhost:8080` — login `admin`, password:

```bash
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d; echo
```

The `wil-playground` Application must be **Synced / Healthy**, with
`http://gitlab.local/root/iot.git` as its source.

### 4. The application (v1)

```bash
curl http://localhost:8888/
# {"status":"ok", "message": "v1"}
```

### 5. Continuous deployment from the local GitLab (v1 -> v2)

Either from the GitLab web IDE (edit `confs/app/deployment.yaml`, change
`wil42/playground:v1` into `wil42/playground:v2`, commit), or:

```bash
sudo ./scripts/switch_version.sh v2
```

which clones the GitLab repository, changes the tag, pushes, refreshes Argo CD
and waits for the rollout:

```bash
curl http://localhost:8888/
# {"status":"ok", "message": "v2"}
```

`sudo ./scripts/switch_version.sh v1` rolls back the same way.

## Cleanup

```bash
sudo ./scripts/cleanup.sh
```

## Layout

```text
bonus/
├── confs/
│   ├── app/                    # manifests hosted by GitLab, synced by Argo CD
│   │   ├── deployment.yaml     # wil42/playground:v1
│   │   ├── service.yaml
│   │   └── ingress.yaml
│   ├── argocd/
│   │   └── application.yaml    # source = http://gitlab.local/root/iot.git
│   └── gitlab/
│       ├── statefulset.yaml    # GitLab CE omnibus + its 3 volumes
│       ├── service.yaml        # gitlab.gitlab.svc.cluster.local:80
│       ├── ingress.yaml        # Host: gitlab.local
│       └── coredns-custom.yaml # gitlab.local resolvable inside the cluster
└── scripts/
    ├── setup.sh                # everything
    ├── seed_gitlab.sh          # public project + first commit + token
    ├── switch_version.sh       # v1 <-> v2 demo
    └── cleanup.sh
```
