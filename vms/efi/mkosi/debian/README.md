**Debian EFI Virtual Machine specific OS Image.**

*Install mkosi:*

    pipx install git+https://github.com/systemd/mkosi.git
    export PATH="$HOME/.local/bin:$PATH"
    mkosi --version

*Build RAW image (any Linux host, no Debian/systemd required):*

    mkosi --architecture=x86-64 --tools-tree=default --tools-tree-distribution=debian --tools-tree-release=trixie build
    mkosi --architecture=arm64  --tools-tree=default --tools-tree-distribution=debian --tools-tree-release=trixie build

*Build RAW image:*

    mkosi --architecture=x86-64 build
    mkosi --architecture=arm64 build

*Build (force) RAW image:*

    mkosi --architecture=x86-64 -f build

*Build (force, autologin) RAW image:*

    mkosi --architecture=x86-64 --force build --autologin=true

*Convert RAW image to QCOW2:*

    qemu-img convert -f raw -O qcow2 -c disk.vm.raw disk.vm.qcow2

*Convert RAW image to VDI:*

    VBoxManage convertfromraw disk.vm.raw --format vdi disk.vm.vdi

*Build (force) OCI directory layout image:*

    mkosi --force --format=oci build

*Run RAW image using qemu:*

    mkosi qemu

*Set console size:*

    stty rows 40 cols 160

---

**Cluster API (CAPI) usage**

When provisioning with CAPI, pass `ignorePreflightErrors` in both `initConfiguration` and `joinConfiguration` to bypass Debian-specific preflight failures (`SystemVerification`, missing bridge netfilter sysctl files).

*KubeadmControlPlane:*

```yaml
apiVersion: controlplane.cluster.x-k8s.io/v1beta1
kind: KubeadmControlPlane
spec:
  kubeadmConfigSpec:
    initConfiguration:
      nodeRegistration:
        criSocket: unix:///run/containerd/containerd.sock
      ignorePreflightErrors:
        - SystemVerification
        - FileContent--proc-sys-net-bridge-bridge-nf-call-iptables
        - FileContent--proc-sys-net-bridge-bridge-nf-call-ip6tables
    joinConfiguration:
      nodeRegistration:
        criSocket: unix:///run/containerd/containerd.sock
      ignorePreflightErrors:
        - SystemVerification
        - FileContent--proc-sys-net-bridge-bridge-nf-call-iptables
        - FileContent--proc-sys-net-bridge-bridge-nf-call-ip6tables
```

*KubeadmConfigTemplate (worker nodes):*

```yaml
apiVersion: bootstrap.cluster.x-k8s.io/v1beta1
kind: KubeadmConfigTemplate
spec:
  template:
    spec:
      joinConfiguration:
        nodeRegistration:
          criSocket: unix:///run/containerd/containerd.sock
        ignorePreflightErrors:
          - SystemVerification
          - FileContent--proc-sys-net-bridge-bridge-nf-call-iptables
          - FileContent--proc-sys-net-bridge-bridge-nf-call-ip6tables
```
