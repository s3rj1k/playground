# Metal3 Lab

## Setup Lab

```bash
ansible-pull -U https://github.com/s3rj1k/playground.git -e "SUSHY_HACKS=false" playbooks/lab.yml
```

> **Note:** Use Debian/Ubuntu AMD64 VM

---

## Create VMs

```bash
create-vm 1 virbr0
create-vm 2 virbr0
create-vm 3 virbr0
create-vm 4 virbr0
create-vm 5 virbr0
```

> **Note:** Script is installed by Ansible playbook

---

## Install ResourceGraphDefinitions

```bash
kubectl apply -f https://raw.githubusercontent.com/s3rj1k/playground/refs/heads/main/lab/rgd/metal3-kubeadm-stack.yml
kubectl apply -f https://raw.githubusercontent.com/s3rj1k/playground/refs/heads/main/lab/rgd/metal3-ironic.yml
kubectl apply -f https://raw.githubusercontent.com/s3rj1k/playground/refs/heads/main/lab/rgd/metal3-kubeadm-cluster.yml
```

---

## Install CAPI Stack and Configure Ironic

> **Note:** The `ironic-credentials-source` secret is user-managed and referenced by KRO to create a managed copy. This ensures credentials persist across Ironic CR recreations.

```bash
kubectl create namespace baremetal-operator-system || true

kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Secret
metadata:
  name: ironic-credentials-source
  namespace: baremetal-operator-system
type: Opaque
stringData:
  username: admin
  password: change-me-in-production
---
apiVersion: kro.run/v1alpha1
kind: Metal3KubeadmStack
metadata:
  name: metal3
  namespace: kro-system
spec: {}
EOF

until kubectl apply -f - <<'EOF'
apiVersion: kro.run/v1alpha1
kind: Metal3Ironic
metadata:
  name: ironic
  namespace: kro-system
spec:
  networking:
    ipAddress: "172.17.1.1"
    interface: virbr0
    dhcp:
      networkCIDR: "172.17.1.0/24"
      rangeBegin: "172.17.1.100"
      rangeEnd: "172.17.1.199"
      gatewayAddress: "172.17.1.1"
      serveDNS: true
  deployRamdisk:
    sshKey: "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKLrIiGjB4nPsyKzgzY21asVi/HKlveRnNY77vOhRhOA"
EOF
do echo "Waiting for Metal3Ironic CRD..."; sleep 5; done

kubectl wait metal3kubeadmstack/metal3 -n kro-system --for=condition=Ready --timeout=10m
kubectl wait metal3ironic/ironic -n kro-system --for=condition=Ready --timeout=10m
```

---

## Create BareMetalHosts

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: vm1-bmc
  namespace: baremetal-operator-system
type: Opaque
stringData:
  username: admin
  password: "$(cat /root/.redfish_password)"
---
apiVersion: v1
kind: Secret
metadata:
  name: vm2-bmc
  namespace: baremetal-operator-system
type: Opaque
stringData:
  username: admin
  password: "$(cat /root/.redfish_password)"
---
apiVersion: v1
kind: Secret
metadata:
  name: vm3-bmc
  namespace: baremetal-operator-system
type: Opaque
stringData:
  username: admin
  password: "$(cat /root/.redfish_password)"
---
apiVersion: v1
kind: Secret
metadata:
  name: vm4-bmc
  namespace: baremetal-operator-system
type: Opaque
stringData:
  username: admin
  password: "$(cat /root/.redfish_password)"
---
apiVersion: v1
kind: Secret
metadata:
  name: vm5-bmc
  namespace: baremetal-operator-system
type: Opaque
stringData:
  username: admin
  password: "$(cat /root/.redfish_password)"
---
apiVersion: metal3.io/v1alpha1
kind: BareMetalHost
metadata:
  name: vm1
  namespace: baremetal-operator-system
  labels:
    cluster.x-k8s.io/control-plane: capm3-demo
spec:
  automatedCleaningMode: disabled
  bmc:
    address: "redfish-virtualmedia://172.17.1.1:8000/redfish/v1/Systems/$(virsh domuuid vm1)/"
    disableCertificateVerification: true
    credentialsName: vm1-bmc
  bootMACAddress: "52:54:00:12:34:01"
  bootMode: UEFI
  online: true
  rootDeviceHints:
    serialNumber: "vm-disk-001"
---
apiVersion: metal3.io/v1alpha1
kind: BareMetalHost
metadata:
  name: vm2
  namespace: baremetal-operator-system
  labels:
    cluster.x-k8s.io/control-plane: capm3-demo
spec:
  automatedCleaningMode: disabled
  bmc:
    address: "redfish-virtualmedia://172.17.1.1:8000/redfish/v1/Systems/$(virsh domuuid vm2)/"
    disableCertificateVerification: true
    credentialsName: vm2-bmc
  bootMACAddress: "52:54:00:12:34:02"
  bootMode: UEFI
  online: true
  rootDeviceHints:
    serialNumber: "vm-disk-002"
---
apiVersion: metal3.io/v1alpha1
kind: BareMetalHost
metadata:
  name: vm3
  namespace: baremetal-operator-system
  labels:
    cluster.x-k8s.io/control-plane: capm3-demo
spec:
  automatedCleaningMode: disabled
  bmc:
    address: "redfish-virtualmedia://172.17.1.1:8000/redfish/v1/Systems/$(virsh domuuid vm3)/"
    disableCertificateVerification: true
    credentialsName: vm3-bmc
  bootMACAddress: "52:54:00:12:34:03"
  bootMode: UEFI
  online: true
  rootDeviceHints:
    serialNumber: "vm-disk-003"
---
apiVersion: metal3.io/v1alpha1
kind: BareMetalHost
metadata:
  name: vm4
  namespace: baremetal-operator-system
  labels:
    cluster.x-k8s.io/worker: capm3-demo
spec:
  automatedCleaningMode: disabled
  bmc:
    address: "redfish://172.17.1.1:8000/redfish/v1/Systems/$(virsh domuuid vm4)/"
    disableCertificateVerification: true
    credentialsName: vm4-bmc
  bootMACAddress: "52:54:00:12:34:04"
  bootMode: UEFI
  online: true
  rootDeviceHints:
    serialNumber: "vm-disk-004"
---
apiVersion: metal3.io/v1alpha1
kind: BareMetalHost
metadata:
  name: vm5
  namespace: baremetal-operator-system
  labels:
    cluster.x-k8s.io/worker: capm3-demo
spec:
  automatedCleaningMode: disabled
  bmc:
    address: "redfish://172.17.1.1:8000/redfish/v1/Systems/$(virsh domuuid vm5)/"
    disableCertificateVerification: true
    credentialsName: vm5-bmc
  bootMACAddress: "52:54:00:12:34:05"
  bootMode: UEFI
  online: true
  rootDeviceHints:
    serialNumber: "vm-disk-005"
EOF
```

---

## Create Cluster

> **Note:** Images are from [Nordix Metal3 Artifactory](https://artifactory.nordix.org/artifactory/metal3/images/). The `hostSelector.matchLabels` must match labels on your BareMetalHosts.

```bash
kubectl apply -f - <<'EOF'
apiVersion: kro.run/v1alpha1
kind: Metal3KubeadmCluster
metadata:
  name: capm3-demo
  namespace: kro-system
spec:
  name: capm3-demo
  namespace: baremetal-operator-system
  kubernetesVersion: v1.35.0
  controlPlaneEndpoint:
    host: 172.17.1.200
  controlPlane:
    replicas: 3
    hostSelector:
      matchLabels:
        cluster.x-k8s.io/control-plane: capm3-demo
  workers:
    replicas: 1
    hostSelector:
      matchLabels:
        cluster.x-k8s.io/worker: capm3-demo
  image:
    url: "https://artifactory.nordix.org/artifactory/metal3/images/k8s_v1.35.0/UBUNTU_24.04_NODE_IMAGE_K8S_v1.35.0.qcow2"
    checksum: "c848088bf104bbd29a15ef88d503e83c4c21bf50b1f2cd3a0d3e3553b2d0cff6"
    checksumType: sha256
    format: qcow2
  user:
    name: metal3
    passwordHash: '$6$4T0c76yU/h2z6D/G$xXvWk/J8AzTmctkOK2wnAv9LtcBrBMEwksnP3CaXMBYPYM8pjqSFgTcuWfuNc./csMFRknnbFq6v1z4QtGTtj1'
    sshAuthorizedKeys:
      - ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKLrIiGjB4nPsyKzgzY21asVi/HKlveRnNY77vOhRhOA
EOF
```

---

## Debug

```bash
kubectl get rgd
kubectl get metal3kubeadmstack,metal3ironic -A
kubectl get coreprovider,bootstrapprovider,controlplaneprovider,infrastructureprovider,ipamprovider -A
kubectl get ironic -A
kubectl get baremetalhost -A
```

---

## Watch provisioning progress

```bash
watch kubectl get metal3cluster,kubeadmcontrolplane,metal3machine,baremetalhost -A
```

## Extract child cluster kubeconfig

```bash
kubectl -n baremetal-operator-system get secret capm3-demo-kubeconfig -o jsonpath='{.data.value}' | base64 -d > capm3-demo.kubeconfig
```

## Test connectivity

```bash
kubectl --kubeconfig=capm3-demo.kubeconfig get nodes -o wide
```
