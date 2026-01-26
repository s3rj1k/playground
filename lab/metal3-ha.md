# Metal3 Lab (High Availability)

## Setup Lab

```bash
ansible-pull -U https://github.com/s3rj1k/playground.git \
  -e "SUSHY_HACKS=false" \
  -e "LB_IP_RANGE_START=172.17.1.200" \
  -e "LB_IP_RANGE_STOP=172.17.1.210" \
  playbooks/lab.yml
```

> **Note:** Use Debian/Ubuntu AMD64 VM. The `LB_IP_RANGE_*` variables configure Cilium LoadBalancer IP pool on the provisioning network for CoreDNS.

---

## Install ResourceGraphDefinitions

```bash
kubectl apply -f https://raw.githubusercontent.com/s3rj1k/playground/refs/heads/main/lab/rgd/kubeadm-stack.yml
kubectl apply -f https://raw.githubusercontent.com/s3rj1k/playground/refs/heads/main/lab/rgd/metal3-kubeadm-stack.yml
kubectl apply -f https://raw.githubusercontent.com/s3rj1k/playground/refs/heads/main/lab/rgd/metal3-ironic-ha.yml
kubectl apply -f https://raw.githubusercontent.com/s3rj1k/playground/refs/heads/main/lab/rgd/metal3-kubeadm-cluster.yml
```

---

## Install CAPI Stack and Configure Ironic HA

> **Note:** The `ironic-credentials-source` secret is user-managed and referenced by KRO to create a managed copy. This ensures credentials persist across Ironic CR recreations.

```bash
kubectl create namespace capi-system || true
kubectl create namespace metal3-system || true

kubectl apply -f - <<'EOF'
apiVersion: kro.run/v1alpha1
kind: KubeadmStack
metadata:
  name: capi
  namespace: capi-system
spec: {}
---
apiVersion: v1
kind: Secret
metadata:
  name: ironic-credentials-source
  namespace: metal3-system
type: Opaque
stringData:
  username: admin
  password: change-me-in-production
---
apiVersion: kro.run/v1alpha1
kind: Metal3KubeadmStack
metadata:
  name: metal3
  namespace: metal3-system
spec:
  mariadbOperator:
    enabled: true
  kyverno:
    enabled: true
EOF

until kubectl apply -f - <<'EOF'
apiVersion: kro.run/v1alpha1
kind: Metal3IronicHA
metadata:
  name: ironic
  namespace: metal3-system
spec:
  networking:
    interface: virbr0
  dns:
    ipAddress: "172.17.1.1"
    # Get clusterDNS with: kubectl get svc -n kube-system -l k8s-app=kube-dns -o jsonpath='{.items[0].spec.clusterIP}'
    clusterDNS: "172.21.0.10"
  tftp:
    enabled: true
    ipAddress: "172.17.1.1"
    binaries: |
      https://boot.ipxe.org/ipxe.efi
        out=ipxe.efi
      https://boot.ipxe.org/ipxe.efi
        out=ipxe-x86_64.efi
      https://boot.ipxe.org/snponly.efi
        out=snponly.efi
      https://boot.ipxe.org/snponly.efi
        out=snponly-x86_64.efi
      https://boot.ipxe.org/undionly.kpxe
        out=undionly.kpxe
  dhcp:
    bindAddr: "0.0.0.0"
    bindInterface: virbr0
    serverIdentifier: "172.17.1.1"
    tftpServer: "172.17.1.1"
    bootFileUefi: "ipxe.efi"
  provisionPool:
    enabled: true
    namePrefix: provision
    gateway: "172.17.1.1"
    prefix: 24
    start: "172.17.1.100"
    end: "172.17.1.199"
    dnsServers: "172.17.1.200"
  deployRamdisk:
    sshKey: "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKLrIiGjB4nPsyKzgzY21asVi/HKlveRnNY77vOhRhOA"
  downloader:
    config: |
      https://s3rj1k.github.io/ironic-python-agent/ipa-amd64.kernel
        out=ironic-python-agent.kernel
        checksum=sha-256=0537a168cd6ff36253f5db40c4b8ed5daa541bad262f4ec8a99357ae24cb2c25
      https://s3rj1k.github.io/ironic-python-agent/ipa-amd64.initramfs
        out=ironic-python-agent.initramfs
        checksum=sha-256=d24ee12e83d7cab515cb171aeab5f6c8a131a46e321975d9ccb67e75f425995b
      https://artifactory.nordix.org/artifactory/metal3/images/k8s_v1.35.0/UBUNTU_24.04_NODE_IMAGE_K8S_v1.35.0.qcow2
        out=ironic-UBUNTU_24.04_NODE_IMAGE_K8S_v1.35.0.qcow2
        checksum=sha-256=bd5fffac09b576ffdc4fdb1ecb5ae1368793a184835c6caae685da33241e7795
EOF
do echo "Waiting for Metal3IronicHA CRD..."; sleep 5; done

kubectl wait kubeadmstack/capi -n capi-system --for=condition=Ready --timeout=10m
kubectl wait metal3kubeadmstack/metal3 -n metal3-system --for=condition=Ready --timeout=10m
kubectl wait metal3ironicha/ironic -n metal3-system --for=condition=Ready --timeout=10m
```

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

## Create BareMetalHosts

> **Note:** The `ipam.metal3.io/ip-pool` annotation triggers automatic IPClaim creation via Kyverno policy. Once set, this annotation is immutable.

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: vm1-bmc
  namespace: metal3-system
type: Opaque
stringData:
  username: admin
  password: "$(cat /root/.redfish_password)"
---
apiVersion: v1
kind: Secret
metadata:
  name: vm2-bmc
  namespace: metal3-system
type: Opaque
stringData:
  username: admin
  password: "$(cat /root/.redfish_password)"
---
apiVersion: v1
kind: Secret
metadata:
  name: vm3-bmc
  namespace: metal3-system
type: Opaque
stringData:
  username: admin
  password: "$(cat /root/.redfish_password)"
---
apiVersion: v1
kind: Secret
metadata:
  name: vm4-bmc
  namespace: metal3-system
type: Opaque
stringData:
  username: admin
  password: "$(cat /root/.redfish_password)"
---
apiVersion: v1
kind: Secret
metadata:
  name: vm5-bmc
  namespace: metal3-system
type: Opaque
stringData:
  username: admin
  password: "$(cat /root/.redfish_password)"
---
apiVersion: metal3.io/v1alpha1
kind: BareMetalHost
metadata:
  name: vm1
  namespace: metal3-system
  labels:
    cluster.x-k8s.io/control-plane: capm3-demo
  annotations:
    ipam.metal3.io/ip-pool: provision
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
  namespace: metal3-system
  labels:
    cluster.x-k8s.io/control-plane: capm3-demo
  annotations:
    ipam.metal3.io/ip-pool: provision
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
  namespace: metal3-system
  labels:
    cluster.x-k8s.io/control-plane: capm3-demo
  annotations:
    ipam.metal3.io/ip-pool: provision
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
  namespace: metal3-system
  labels:
    cluster.x-k8s.io/worker: capm3-demo
  annotations:
    ipam.metal3.io/ip-pool: provision
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
  namespace: metal3-system
  labels:
    cluster.x-k8s.io/worker: capm3-demo
  annotations:
    ipam.metal3.io/ip-pool: provision
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
