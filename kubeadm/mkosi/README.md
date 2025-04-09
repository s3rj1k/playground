**Kubernetes OS Image.**

*Build RAW image:*

    mkosi build

*Build (force) RAW image:*

    mkosi -f build

*Build (force, autologin) RAW image:*

    mkosi --force --autologin build

*Convert RAW image to QCOW2:*

    qemu-img convert -f raw -O qcow2 -c os-image.vm.raw os-image.vm.qcow2

*Convert RAW image to VDI:*

    VBoxManage convertfromraw os-image.vm.raw --format vdi os-image.vm.vdi

*Build (force) OCI directory layout image:*

    mkosi --force --format=oci build

*Run RAW image using qemu:*

    mkosi qemu

*Set console size:*

    stty rows 40 cols 1000
