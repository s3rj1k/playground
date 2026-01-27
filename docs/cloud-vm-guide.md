# Running Ubuntu Cloud VM with Cloud-Init in libvirt

This guide shows how to create and run an Ubuntu cloud VM locally using libvirt with cloud-init configuration.

## Cloud-Init V1 Format

This guide uses cloud-init v1 network configuration format with a bridge interface.

## Steps

### Download Ubuntu Cloud Image

```bash
sudo mkdir -p /var/lib/libvirt/images
sudo wget https://cloud-images.ubuntu.com/releases/24.04/release/ubuntu-24.04-server-cloudimg-amd64.img \
  -O /var/lib/libvirt/images/ubuntu-24.04-server-cloudimg-amd64.img
```

### Create Cloud-Init Configuration

Create user-data file:
```bash
cat > /tmp/user-data << 'EOF'
#cloud-config
users:
 - name: ubuntu
   sudo: ALL=(ALL) NOPASSWD:ALL
   shell: /bin/bash
   lock_passwd: false
chpasswd:
  list: |
    ubuntu:ubuntu
  expire: False
ssh_pwauth: True
EOF
```

Create meta-data file:
```bash
cat > /tmp/meta-data << 'EOF'
instance-id: vm
local-hostname: vm
EOF
```

Create network-config file (v1 format with bridge):
```bash
cat > /tmp/network-config << 'EOF'
version: 1
config:
  - type: physical
    name: eth0
    mac_address: "52:54:00:12:34:01"
    subnets:
      - type: manual
  - type: bridge
    name: br0
    bridge_interfaces:
      - eth0
    subnets:
      - type: dhcp
EOF
```

### Create Cloud-Init ISO

```bash
genisoimage -output /tmp/cloud-init-vm.iso -volid cidata -joliet -rock /tmp/user-data /tmp/meta-data /tmp/network-config
```

### Prepare VM Disk

```bash
# Copy cloud image to VM disk
sudo cp /var/lib/libvirt/images/ubuntu-24.04-server-cloudimg-amd64.img /var/lib/libvirt/images/vm-disk.qcow2

# Resize disk to 20GB
sudo qemu-img resize /var/lib/libvirt/images/vm-disk.qcow2 20G
```

### Create and Start VM

Replace `virbr0` with your bridge network name if needed.
Use `virsh net-list` to see available networks.

```bash
sudo virt-install \
  --name vm \
  --description "Ubuntu Cloud VM" \
  --vcpus 4 \
  --ram 8192 \
  --os-variant ubuntu24.04 \
  --disk path=/var/lib/libvirt/images/vm-disk.qcow2,bus=virtio \
  --disk path=/tmp/cloud-init-vm.iso,device=cdrom \
  --network bridge=virbr0,mac=52:54:00:12:34:01 \
  --graphics vnc \
  --boot hd \
  --noautoconsole \
  --import
```

### Connect to VM

Login credentials: `ubuntu` / `ubuntu`

Connect via console:
```bash
virsh console vm
# Press Ctrl+] to disconnect
```

Or connect via VNC:
```bash
virt-viewer vm
```

### Cleanup (Optional)

To remove the VM and clean up:
```bash
# Stop and remove VM
virsh destroy vm
virsh undefine vm --remove-all-storage --nvram --snapshots-metadata --managed-save

# Remove temporary files
rm -f /tmp/user-data /tmp/meta-data /tmp/network-config /tmp/cloud-init-vm.iso
```

## Cloud-Init OpenStack Datasource Format

This section shows how to use the OpenStack ConfigDrive datasource format with `network_data.json`.

### Steps

#### Download Ubuntu Cloud Image

Use the same Ubuntu image from the V1 format section above.

#### Create OpenStack ConfigDrive Structure

Create directory structure:
```bash
mkdir -p /tmp/configdrive/openstack/latest
```

Create meta_data.json (only uuid is required):
```bash
cat > /tmp/configdrive/openstack/latest/meta_data.json << 'EOF'
{
  "uuid": "d8e02d56-2648-49a3-bf97-6be8f1204f38",
  "hostname": "vm-openstack"
}
EOF
```

Create user_data:
```bash
cat > /tmp/configdrive/openstack/latest/user_data << 'EOF'
#cloud-config
users:
 - name: ubuntu
   sudo: ALL=(ALL) NOPASSWD:ALL
   shell: /bin/bash
   lock_passwd: false
chpasswd:
  list: |
    ubuntu:ubuntu
  expire: False
ssh_pwauth: True
EOF
```

Create network_data.json (simple DHCP configuration with eth0):
```bash
cat > /tmp/configdrive/openstack/latest/network_data.json << 'EOF'
{
  "links": [
    {
      "id": "interface0",
      "name": "eth0",
      "type": "phy",
      "ethernet_mac_address": "52:54:00:12:34:02",
      "mtu": 1500
    }
  ],
  "networks": [
    {
      "id": "network0",
      "type": "ipv4_dhcp",
      "link": "interface0",
      "network_id": "da5bb487-5193-4a65-a3df-4a0055a8c0d7"
    }
  ],
  "services": [
    {
      "type": "dns",
      "address": "8.8.8.8"
    },
    {
      "type": "dns",
      "address": "8.8.4.4"
    }
  ]
}
EOF
```

#### Create ConfigDrive ISO

Create ISO with "config-2" label (required for OpenStack datasource):
```bash
genisoimage -R -V config-2 -o /tmp/cloud-init-vm-openstack.iso /tmp/configdrive
```

#### Prepare VM Disk

```bash
# Copy cloud image to VM disk
sudo cp /var/lib/libvirt/images/ubuntu-24.04-server-cloudimg-amd64.img /var/lib/libvirt/images/vm-openstack-disk.qcow2

# Resize disk to 20GB
sudo qemu-img resize /var/lib/libvirt/images/vm-openstack-disk.qcow2 20G
```

#### Create and Start VM

```bash
sudo virt-install \
  --name vm-openstack \
  --description "Ubuntu Cloud VM with OpenStack ConfigDrive" \
  --vcpus 4 \
  --ram 8192 \
  --os-variant ubuntu24.04 \
  --disk path=/var/lib/libvirt/images/vm-openstack-disk.qcow2,bus=virtio \
  --disk path=/tmp/cloud-init-vm-openstack.iso,device=cdrom \
  --network bridge=virbr0,mac=52:54:00:12:34:02 \
  --graphics vnc \
  --boot hd \
  --noautoconsole \
  --import
```

#### Connect to VM

Login credentials: `ubuntu` / `ubuntu`

Connect via console:
```bash
virsh console vm-openstack
# Press Ctrl+] to disconnect
```

Or connect via VNC:
```bash
virt-viewer vm-openstack
```

#### Cleanup (Optional)

To remove the VM and clean up:
```bash
# Stop and remove VM
virsh destroy vm-openstack
virsh undefine vm-openstack --remove-all-storage --nvram --snapshots-metadata --managed-save

# Remove temporary files
rm -rf /tmp/configdrive /tmp/cloud-init-vm-openstack.iso
```

