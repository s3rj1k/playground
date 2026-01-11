# Tinkerbell Lab

## Setup Lab

```bash
ansible-pull -U https://github.com/s3rj1k/playground.git playbooks/lab.yml \
  -e "HCP_MODE=true" \
  -e "SUSHY_HACKS=true" \
  -e "CILIUM_BRIDGE_HACKS=true"
```

> **Note:** Use Debian/Ubuntu AMD64 VM.
>
> **Note:** `CILIUM_BRIDGE_HACKS=true` disables `bridge-nf-call-iptables` which is required
> for VMs on libvirt bridges to reach Cilium LoadBalancer services (e.g., HCP API server).

---

## Create VMs

```bash
create-vm 1 virbr0
create-vm 2 virbr0
create-vm 3 virbr0
create-vm 4 virbr0
create-vm 5 virbr0
```

> **Note:** Script is installed by Ansible playbook.

---

## Install ResourceGraphDefinitions

```bash
kubectl apply -f https://raw.githubusercontent.com/s3rj1k/playground/refs/heads/main/lab/rgd/kubeadm-stack.yml
kubectl apply -f https://raw.githubusercontent.com/s3rj1k/playground/refs/heads/main/lab/rgd/tinkerbell-kubeadm-stack.yml
kubectl apply -f https://raw.githubusercontent.com/s3rj1k/playground/refs/heads/main/lab/rgd/tinkerbell-node.yml
kubectl apply -f https://raw.githubusercontent.com/s3rj1k/playground/refs/heads/main/lab/rgd/tinkerbell-kubeadm-cluster.yml
kubectl apply -f https://raw.githubusercontent.com/s3rj1k/playground/refs/heads/main/lab/rgd/tinkerbell-kubeadm-hosted-cluster.yml
```

---

## Install CAPI Stack

```bash
kubectl create namespace capi-system || true
kubectl create namespace tinkerbell-system || true

kubectl apply -f - <<EOF
apiVersion: kro.run/v1alpha1
kind: KubeadmStack
metadata:
  name: capi
  namespace: capi-system
spec:
  enableIgnition: true
  hostedControlPlane:
    enabled: true
---
apiVersion: kro.run/v1alpha1
kind: TinkerbellKubeadmStack
metadata:
  name: tinkerbell
  namespace: tinkerbell-system
spec:
  tinkerbellIP: "172.17.1.1"
  sourceInterface: virbr0
  trustedProxies: "10.244.0.0/16"
  # isoURL: https://github.com/tinkerbell/hook/releases/download/latest/hook-x86_64-efi-initrd.iso
EOF

kubectl wait kubeadmstack/capi -n capi-system --for=condition=Ready --timeout=10m
kubectl wait tinkerbellkubeadmstack/tinkerbell -n tinkerbell-system --for=condition=Ready --timeout=10m
```

---

## Create Nodes

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: bmc-credentials
  namespace: tinkerbell-system
type: Opaque
stringData:
  username: admin
  password: "$(cat /root/.redfish_password)"
---
apiVersion: kro.run/v1alpha1
kind: TinkerbellNode
metadata:
  name: vm1
  namespace: tinkerbell-system
spec:
  name: vm1
  role: control-plane
  bmc:
    secretName: bmc-credentials
    host: 172.17.1.1
    port: 623
    redfish:
      port: 8000
  network:
    ip: 172.17.1.201
    gateway: 172.17.1.1
    mac: "52:54:00:12:34:01"
---
apiVersion: kro.run/v1alpha1
kind: TinkerbellNode
metadata:
  name: vm2
  namespace: tinkerbell-system
spec:
  name: vm2
  role: control-plane
  bmc:
    secretName: bmc-credentials
    host: 172.17.1.1
    port: 623
    redfish:
      port: 8000
  network:
    ip: 172.17.1.202
    gateway: 172.17.1.1
    mac: "52:54:00:12:34:02"
---
apiVersion: kro.run/v1alpha1
kind: TinkerbellNode
metadata:
  name: vm3
  namespace: tinkerbell-system
spec:
  name: vm3
  role: control-plane
  bmc:
    secretName: bmc-credentials
    host: 172.17.1.1
    port: 623
    redfish:
      port: 8000
  network:
    ip: 172.17.1.203
    gateway: 172.17.1.1
    mac: "52:54:00:12:34:03"
---
apiVersion: kro.run/v1alpha1
kind: TinkerbellNode
metadata:
  name: vm4
  namespace: tinkerbell-system
spec:
  name: vm4
  role: worker
  bmc:
    secretName: bmc-credentials
    host: 172.17.1.1
    port: 623
    redfish:
      port: 8000
  network:
    ip: 172.17.1.204
    gateway: 172.17.1.1
    mac: "52:54:00:12:34:04"
---
apiVersion: kro.run/v1alpha1
kind: TinkerbellNode
metadata:
  name: vm5
  namespace: tinkerbell-system
spec:
  name: vm5
  role: worker
  bmc:
    secretName: bmc-credentials
    host: 172.17.1.1
    port: 623
    redfish:
      port: 8000
  network:
    ip: 172.17.1.205
    gateway: 172.17.1.1
    mac: "52:54:00:12:34:05"
EOF
```

---

## Create Cluster

### Traditional Kubeadm Cluster (HA)

```bash
kubectl apply -f - <<'EOF'
apiVersion: kro.run/v1alpha1
kind: TinkerbellKubeadmCluster
metadata:
  name: capt
  namespace: tinkerbell-system
spec:
  name: capt
  controlPlaneEndpoint:
    host: 172.17.1.200
  controlPlane:
    replicas: 3
  workers:
    replicas: 1
  user:
    name: tink
    passwordHash: '$6$ANFHbIxmWcLvxYP1$EQGLSsa6Q3o5HkiM5aa56o32LW5I36WoamE8y7FQHZChbi/PCJYMffP2EAbsWlqjkID8.9ZYofPxwXmF7elZ90'
    sshAuthorizedKeys:
      - ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKLrIiGjB4nPsyKzgzY21asVi/HKlveRnNY77vOhRhOA
EOF
```

### Hosted Control Plane

Control plane runs as pods in the management cluster.

```bash
kubectl apply -f - <<'EOF'
apiVersion: kro.run/v1alpha1
kind: TinkerbellKubeadmHostedCluster
metadata:
  name: capt-hcp
  namespace: tinkerbell-system
spec:
  name: capt-hcp
  kubernetesVersion: v1.34.3
  gateway:
    name: hcp
    namespace: tinkerbell-system
    ip: "172.17.1.225"
  ciliumLB:
    ipRangeStart: "172.17.1.225"
    ipRangeStop: "172.17.1.250"
  controlPlane:
    replicas: 1
  workers:
    replicas: 1
  konnectivityClient:
    replicas: 1
  user:
    name: tink
    passwordHash: '$6$ANFHbIxmWcLvxYP1$EQGLSsa6Q3o5HkiM5aa56o32LW5I36WoamE8y7FQHZChbi/PCJYMffP2EAbsWlqjkID8.9ZYofPxwXmF7elZ90'
    sshAuthorizedKeys:
      - ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKLrIiGjB4nPsyKzgzY21asVi/HKlveRnNY77vOhRhOA
EOF
```

---

## Watch provisioning progress

```bash
watch kubectl get tinkerbellkubeadmcluster,tinkerbellkubeadmhostedcluster,cluster,tinkerbellcluster,kubeadmcontrolplane,hostedcontrolplane,tinkerbellmachine,workflow -A
```

## Extract child cluster kubeconfig

```bash
kubectl -n tinkerbell-system get secret capt-kubeconfig -o jsonpath='{.data.value}' | base64 -d > capt.kubeconfig
kubectl -n tinkerbell-system get secret capt-hcp-kubeconfig -o jsonpath='{.data.value}' | base64 -d > capt-hcp.kubeconfig
```

## Test connectivity

```bash
kubectl --kubeconfig=capt.kubeconfig get nodes -o wide
kubectl --kubeconfig=capt-hcp.kubeconfig get nodes -o wide
```
