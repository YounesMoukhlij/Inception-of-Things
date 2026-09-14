# P3 - k3d and ArgoCD with Vagrant

## Prerequisites

Before testing this project, ensure you have the following installed on your host machine:
* [Vagrant]
* [VirtualBox]

## How to Test

### 1. Start the Virtual Machine

Navigate to this `p3` directory and bring up the Vagrant box:

```bash
cd p3
vagrant up
```

This command will download the Ubuntu 22.04 image (if not cached), start the VM, and execute the provisioning script (`scripts/argocd.sh`). 

The script will automatically:
- Install Docker, kubectl, and k3d.
- Spin up a k3d cluster named `demo`.
- Install ArgoCD.
- Apply the application manifests located in the `confs` directory.
- Port-forward the ArgoCD UI.

*Note: Provisioning may take a few minutes to complete.*

### 2. Access the ArgoCD UI

Once the Vagrant machine finishes provisioning, the ArgoCD interface is exposed on your host machine.

1. **URL:** Open your browser and navigate to `https://192.168.56.110:8080`.
   *(Note: You will likely see a self-signed certificate warning; you can safely proceed/bypass it).*
2. **Username:** `admin`
3. **Password:** You can retrieve the auto-generated admin password by SSHing into the Vagrant machine and extracting it from the cluster:

   ```bash
   vagrant ssh
   kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
   ```

### 3. Verify the Deployment

Inside the ArgoCD UI, you should see the application automatically syncing (or already synced) based on the configurations specified in `confs/argocd/application.yaml`.

You can also verify everything from within the VM:

```bash
vagrant ssh

# Check namespaces and pods
kubectl get all -n dev
kubectl get all -n argocd
```

### 4. Cleanup

When you are finished testing, you can stop and completely destroy the Vagrant virtual machine to free up resources:

```bash
vagrant destroy -f
```
