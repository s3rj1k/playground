# Tinkerbell Lab

## Setup Lab

```bash
ansible-pull -U https://github.com/s3rj1k/playground.git playbooks/lab.yml
```

> **Note:** Use Debian/Ubuntu AMD64 VM

---

## Create VMs

```bash
create-vm 1 virbr0
create-vm 2 virbr0
```

> **Note:** Script is installed by Ansible playbook

---

## Install ResourceGraphDefinitions

```bash
kubectl apply -f https://raw.githubusercontent.com/s3rj1k/playground/refs/heads/main/tinkerbell/rgd/tinkerbell-kubeadm-stack.yml
kubectl apply -f https://raw.githubusercontent.com/s3rj1k/playground/refs/heads/main/tinkerbell/rgd/tinkerbell-node.yml
kubectl apply -f https://raw.githubusercontent.com/s3rj1k/playground/refs/heads/main/tinkerbell/rgd/tinkerbell-kubeadm-cluster.yml
```

---

## Install CAPI Stack

```bash
kubectl apply -f - <<EOF
apiVersion: kro.run/v1alpha1
kind: TinkerbellKubeadmStack
metadata:
  name: tinkerbell-capi
  namespace: kro-system
spec:
  tinkerbellIP: "172.17.1.1"
  sourceInterface: virbr0
  trustedProxies: "10.244.0.0/16"
  versions:
    clusterAPI: v1.11.3
    addonHelm: v0.5.3
    tinkerbellProvider: v0.6.8
    tinkerbellChart: v0.22.0
    kubeVip: v1.0.3
    kubeVipCloudProvider: "0.2.9"
  # isoURL: https://github.com/tinkerbell/hook/releases/download/latest/hook-x86_64-efi-initrd.iso
EOF

kubectl wait tinkerbellkubeadmstack/tinkerbell-capi -n kro-system --for=condition=Ready --timeout=10m
```

---

## Create Nodes

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: bmc-credentials
  namespace: capi-system
type: Opaque
stringData:
  username: admin
  password: "$(cat /root/.redfish_password)"
---
apiVersion: kro.run/v1alpha1
kind: TinkerbellNode
metadata:
  name: vm1
  namespace: kro-system
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
  namespace: kro-system
spec:
  name: vm2
  role: worker
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
EOF
```

---

## Create Cluster

```bash
kubectl apply -f - <<EOF
apiVersion: kro.run/v1alpha1
kind: TinkerbellKubeadmCluster
metadata:
  name: capt
  namespace: kro-system
spec:
  name: capt
  controlPlaneEndpoint:
    host: 172.17.1.201
  controlPlane:
    replicas: 1
  workers:
    replicas: 1
  user:
    name: tink
    passwordHash: /k.Njafoq3ND3PteLDYiOyRfQuVr8Zd67aFIuvJt/BRt8Tq
    sshAuthorizedKeys:
      - ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKLrIiGjB4nPsyKzgzY21asVi/HKlveRnNY77vOhRhOA
EOF
```

---

## Watch provisioning progress

```bash
watch kubectl get tinkerbellcluster,kubeadmcontrolplane,tinkerbellmachine,workflow -A
```

## Extract child cluster kubeconfig

```bash
kubectl -n capi-system get secret capt-kubeconfig -o jsonpath='{.data.value}' | base64 -d > capt.kubeconfig
```

## Test connectivity

```bash
kubectl --kubeconfig=capt.kubeconfig get nodes -o wide
```
