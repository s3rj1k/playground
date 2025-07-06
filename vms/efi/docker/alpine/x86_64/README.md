**Alpine EFI Virtual Machine specific OS Image.**

*Build rootfs using docker:*

	docker build --force-rm -t alpine:vm .

*[Optionally] Debug rootfs using docker:*

	docker run --interactive --network host --rm --tty alpine:vm sh

*Dump rootfs from docker image:*

	export LAYER=`docker image inspect alpine:vm --format '{{ index .RootFS.Layers 0 }}' | awk -F: '{print $2}'`

	rm -vf ${LAYER} && docker save alpine:vm | tar --strip-components=2 --strip-components=2 -xf - "blobs/sha256/${LAYER}" && mv -v ${LAYER} rootfs.tar

*Prepare empty raw disk image file:*

	fallocate -l 10G rootfs.img

*Associate disk image with loop device:*

	sudo losetup loop1 rootfs.img

*Create partitions inside disk image:*

	sudo parted /dev/loop1 mklabel gpt
	sudo parted -a opt /dev/loop1 mkpart ESP fat32 2MiB 1024MiB
	sudo parted -a opt /dev/loop1 mkpart root ext4 1025MiB 100%
	sudo parted /dev/loop1 set 1 esp on

*Format partitions inside disk image:*

	sudo mkfs.vfat -F 32 -n ESP /dev/loop1p1
	sudo mkfs.ext4 -O encrypt -O ^FEATURE_C12 -m 0 -L root /dev/loop1p2

*Mount partitions from disk image to local system:*

	sudo mount /dev/loop1p2 /mnt
	sudo mkdir -p /mnt/efi && sudo mount /dev/loop1p1 /mnt/efi

*Apply roots to mounted disk image:*

	sudo bsdtar -xvp -f rootfs.tar -C /mnt --numeric-owner

*Unmount disk image partitions from local system:*

	sudo umount -l /mnt/efi /mnt

*De-associate disk image from loop device:*

	sudo losetup -d /dev/loop1

*[Optionally] Test OS disk image using qemu:*

	qemu-system-x86_64 \
	  -machine q35 \
	  -cpu host \
	  -enable-kvm \
	  -m 4G \
	  -smp 2 \
	  -bios /usr/share/edk2-ovmf/x64/OVMF_CODE.fd \
	  -blockdev driver=file,filename=rootfs.img,node-name=hd0 \
	  -device virtio-blk-pci,drive=hd0,bootindex=0 \
	  -nographic \
	  -netdev user,id=vnet,hostfwd=:127.0.0.1:0-:22 \
	  -device virtio-net-pci,netdev=vnet,romfile= \
	  -boot menu=off,strict=on,order=c
