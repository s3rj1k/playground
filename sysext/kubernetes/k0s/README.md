# k0s System Extension

Build and use a systemd sysext with k0s.

**Requirements:** systemd 257+

## Build

```bash
./build-k0s.sh
../download.sh
./build-sysext.sh
```

## Install

```bash
mkdir -p /var/lib/extensions/
cp -v output/k0s.sysext.raw /var/lib/extensions/
systemd-sysext refresh --mutable=yes
```

## Verify

```bash
systemd-sysext status
mount | grep sysext
k0s version
```

## Remove

```bash
systemd-sysext unmerge
rm -v /var/lib/extensions/k0s.sysext.raw
```

## Initialize k0s

```bash
k0s install controller --no-taints --enable-worker --enable-dynamic-config --disable-components=konnectivity-server
systemctl enable --now k0scontroller.service
```

## Links

- https://uapi-group.org/specifications/specs/extension_image/
- https://www.freedesktop.org/software/systemd/man/latest/systemd-sysext.html
- https://docs.k0sproject.io/
