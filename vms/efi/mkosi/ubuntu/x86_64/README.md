**Kubernetes OS Image.**

*Install mkosi:*

    pipx install git+https://github.com/systemd/mkosi.git
    export PATH="$HOME/.local/bin:$PATH"
    mkosi --version

*Build RAW image:*

    mkosi build

*Build (force) RAW image:*

    mkosi -f build

*Build (force, autologin) RAW image:*

    mkosi --force build --autologin=true

*Convert RAW image to QCOW2:*

    qemu-img convert -f raw -O qcow2 -c image.vm.raw image.vm.qcow2

*Convert RAW image to VDI:*

    VBoxManage convertfromraw image.vm.raw --format vdi image.vm.vdi

*Build (force) OCI directory layout image:*

    mkosi --force --format=oci build

*Build nspawn directory image:*

    mkosi --format=directory build

*Run nspawn directory image:*

    systemd-nspawn --boot --directory=image.vm [--network-macvlan=eth0 | --network-veth]

*Run RAW image using qemu:*

    mkosi qemu

*Set console size:*

    stty rows 40 cols 160
