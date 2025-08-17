FROM alpine:latest AS base
CMD ["/bin/sh"]

RUN apk --no-cache update && \
    apk --no-cache upgrade && \
    apk --no-cache add \
    e2fsprogs \
    linux-virt \
    openrc \
    secureboot-hook

RUN echo "root:root" | chpasswd && \
    rc-update add root

RUN sed -i \
    -e 's/^wipe_tmp="NO"/wipe_tmp="YES"/' \
    -e 's/^#previous_dmesg=no/previous_dmesg=no/' \
    /etc/conf.d/bootmisc && \
    sed -i \
    -e 's/^fsck_abort_on_errors="YES"/fsck_abort_on_errors="NO"/' \
    /etc/conf.d/fsck && \
    sed -i \
    -e 's/^#ttyS0::/ttyS0::/' \
    -e 's/^tty2::/#tty2::/' \
    -e 's/^tty3::/#tty3::/' \
    -e 's/^tty4::/#tty4::/' \
    -e 's/^tty5::/#tty5::/' \
    -e 's/^tty6::/#tty6::/' \
    /etc/inittab && \
    sed -i \
    -e 's/^#unicode="NO"/unicode="YES"/' \
    /etc/rc.conf && \
    truncate -s0 /etc/motd && \
    printf 'alpine-vm\n' | tee /etc/hostname

# https://wiki.alpinelinux.org/wiki/UEFI_Secure_Boot
RUN sed -i \
    -e 's/^#signing_disabled=no/signing_disabled=yes/' \
    -e 's/^cmdline=/cmdline="rw root=LABEL=root modules=ext4 rootfstype=ext4"/' \
    -e 's/^#backup_old=yes/backup_old=no/' \
    -e 's|^#output_dir=.*$|output_dir="/efi/EFI/BOOT/"|' \
    -e 's|^#output_name=.*$|output_name="BOOTX64.EFI"|' \
    /etc/kernel-hooks.d/secureboot.conf && \
    printf 'LABEL=ESP  /efi vfat defaults,noatime 0 2\n' | tee /etc/fstab && \
    printf 'LABEL=root /    ext4 defaults,noatime 0 1\n' | tee -a /etc/fstab && \
    apk --no-cache fix kernel-hooks

FROM scratch
COPY --from=base . .
