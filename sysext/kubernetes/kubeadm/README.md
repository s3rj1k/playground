# Kubernetes System Extension

Build and use a systemd sysext with Kubernetes tools.

**Requirements:** systemd 257+

## Build

```bash
./download.sh
./build-sysext.sh
./build-confext.sh
```

## Install

```bash
mkdir -p /var/lib/extensions/ /var/lib/confexts/
cp -v output/kubeadm.sysext.raw /var/lib/extensions/
cp -v output/kubeadm.confext.raw /var/lib/confexts/
systemd-sysext refresh --mutable=yes
systemd-confext refresh --mutable=yes
```

## Verify

```bash
systemd-sysext status
systemd-confext status
mount | grep -E "(sysext|confext)"
```

## Remove

```bash
systemd-sysext unmerge
systemd-confext unmerge
rm -v /var/lib/extensions/kubeadm.sysext.raw
rm -v /var/lib/confexts/kubeadm.confext.raw
```

## Initialize Single-Node Kubernetes

```bash
source /etc/profile.d/kubernetes.sh
systemctl enable --now containerd.service
systemctl enable kubelet.service
k8s-init
```

## Links

- https://uapi-group.org/specifications/specs/extension_image/
- https://www.freedesktop.org/software/systemd/man/latest/systemd-sysext.html
