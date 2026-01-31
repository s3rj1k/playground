#!/bin/bash
set -euo pipefail

# Standalone Tinkerbell VM provisioning script
# Usage: ./tink.sh <vm-name> [options]

# Defaults (extracted from running cluster)
NAMESPACE="${NAMESPACE:-tinkerbell-system}"
TINKERBELL_IP="${TINKERBELL_IP:-172.17.1.1}"
REDFISH_PORT="${REDFISH_PORT:-8000}"
BMC_SECRET="${BMC_SECRET:-bmc-credentials}"

# VM defaults
VM_NAME=""
VM_MAC="${VM_MAC:-52:54:00:12:34:01}"
VM_IP="${VM_IP:-172.17.1.201}"
VM_GATEWAY="${VM_GATEWAY:-172.17.1.1}"
VM_NETMASK="${VM_NETMASK:-255.255.255.0}"
VM_DISK="${VM_DISK:-/dev/vda}"
VM_ARCH="${VM_ARCH:-x86_64}"

# Boot mode: customboot, netboot, isoboot
BOOT_MODE="${BOOT_MODE:-customboot}"

# OS Image
OS_IMAGE="${OS_IMAGE:-ghcr.io/s3rj1k/playground/ubuntu-2404:v1.34.3.gz}"

# ISO URL for isoboot mode (optional override, defaults to Tinkerbell-served URL)
ISO_URL="${ISO_URL:-}"

# Flags
FORCE_CLEANUP=false
ACTION="create"

usage() {
    cat <<EOF
Usage: $0 <vm-name> [options]

Options:
  -m, --mode <mode>    Boot mode: customboot, netboot, isoboot (default: customboot)
  -f, --force          Force cleanup existing resources before create
  -d, --delete         Delete all resources for the VM
  -s, --status         Show status of VM provisioning
  -h, --help           Show this help

Boot Modes:
  customboot  Full control with preparing and post actions (PXE boot, then disk boot)
  netboot     Simple netboot mode (PXE boot only)
  isoboot     Boot from ISO image (Tinkerbell-served by default)

Environment variables:
  VM_MAC         MAC address (default: $VM_MAC)
  VM_IP          IP address (default: $VM_IP)
  VM_GATEWAY     Gateway (default: $VM_GATEWAY)
  VM_NETMASK     Netmask (default: $VM_NETMASK)
  VM_DISK        Disk device (default: $VM_DISK)
  OS_IMAGE       OS image URL (default: $OS_IMAGE)
  ISO_URL        ISO URL for isoboot mode (default: Tinkerbell-served)
  TINKERBELL_IP  Tinkerbell server IP (default: $TINKERBELL_IP)
  BOOT_MODE      Boot mode (default: $BOOT_MODE)

Examples:
  # Provision with customboot (default)
  ./tink.sh vm1

  # Provision with netboot
  ./tink.sh vm1 --mode netboot

  # Provision with ISO boot
  ISO_URL=http://example.com/boot.iso ./tink.sh vm1 --mode isoboot

  # Force recreate
  ./tink.sh vm1 --force

  # Delete resources
  ./tink.sh vm1 --delete
EOF
    exit "${1:-1}"
}

create_bmc_machine() {
    cat <<EOF | kubectl apply -f -
apiVersion: bmc.tinkerbell.org/v1alpha1
kind: Machine
metadata:
  name: ${VM_NAME}
  namespace: ${NAMESPACE}
spec:
  connection:
    host: ${TINKERBELL_IP}
    port: 623
    insecureTLS: true
    authSecretRef:
      name: ${BMC_SECRET}
      namespace: ${NAMESPACE}
    providerOptions:
      preferredOrder:
        - gofish
        - ipmitool
      redfish:
        port: ${REDFISH_PORT}
        systemName: ${VM_NAME}
        useBasicAuth: true
      ipmitool:
        port: 623
        cipherSuite: "3"
EOF
}

create_hardware() {
    cat <<EOF | kubectl apply -f -
apiVersion: tinkerbell.org/v1alpha1
kind: Hardware
metadata:
  name: ${VM_NAME}
  namespace: ${NAMESPACE}
  labels:
    tinkerbell.org/role: standalone
spec:
  bmcRef:
    apiGroup: bmc.tinkerbell.org
    kind: Machine
    name: ${VM_NAME}
  disks:
    - device: ${VM_DISK}
  interfaces:
    - dhcp:
        arch: ${VM_ARCH}
        hostname: ${VM_NAME}
        ip:
          address: ${VM_IP}
          gateway: ${VM_GATEWAY}
          netmask: ${VM_NETMASK}
        lease_time: 4294967294
        mac: "${VM_MAC}"
        name_servers:
          - 8.8.8.8
          - 1.1.1.1
        uefi: true
      netboot:
        allowPXE: true
        allowWorkflow: true
  metadata:
    instance:
      hostname: ${VM_NAME}
      id: "${VM_MAC}"
      operating_system:
        distro: ubuntu
        os_slug: ubuntu_24_04
        version: "24.04"
  userData: |
    #cloud-config
    users:
      - name: tink
        sudo: ALL=(ALL) NOPASSWD:ALL
        groups: sudo
        shell: /bin/bash
        passwd: '\$6\$ANFHbIxmWcLvxYP1\$EQGLSsa6Q3o5HkiM5aa56o32LW5I36WoamE8y7FQHZChbi/PCJYMffP2EAbsWlqjkID8.9ZYofPxwXmF7elZ90'
        lock_passwd: false
    ssh_pwauth: true
    chpasswd:
      expire: false
    runcmd:
      - sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
      - systemctl restart ssh
EOF
}

create_template() {
    cat <<EOF | kubectl apply -f -
apiVersion: tinkerbell.org/v1alpha1
kind: Template
metadata:
  name: ${VM_NAME}
  namespace: ${NAMESPACE}
spec:
  data: |
    version: "0.1"
    name: standalone-provision
    global_timeout: 9000
    tasks:
      - name: "provision"
        worker: "{{.device_1}}"
        volumes:
          - /dev:/dev
          - /dev/console:/dev/console
          - /lib/firmware:/lib/firmware:ro
        actions:
          - name: "Stream Ubuntu Image"
            image: quay.io/tinkerbell/actions/oci2disk:latest
            timeout: 3000
            environment:
              DEST_DISK: {{ index .Hardware.Disks 0 }}
              IMG_URL: ${OS_IMAGE}
              COMPRESSED: true
          - name: "Grow Partition"
            image: quay.io/tinkerbell/actions/cexec:latest
            timeout: 90
            environment:
              BLOCK_DEVICE: {{ index .Hardware.Disks 0 }}3
              FS_TYPE: ext4
              CHROOT: y
              DEFAULT_INTERPRETER: "/bin/sh -c"
              CMD_LINE: "growpart {{ index .Hardware.Disks 0 }} 3 && resize2fs {{ index .Hardware.Disks 0 }}3"
          - name: "Add Tink Cloud-Init Config"
            image: quay.io/tinkerbell/actions/writefile:latest
            timeout: 90
            environment:
              DEST_DISK: {{ formatPartition ( index .Hardware.Disks 0 ) 3 }}
              FS_TYPE: ext4
              DEST_PATH: /etc/cloud/cloud.cfg.d/10_tinkerbell.cfg
              UID: 0
              GID: 0
              MODE: 0600
              DIRMODE: 0700
              CONTENTS: |
                datasource:
                  Ec2:
                    metadata_urls: ["http://{{ (index .Hardware.Interfaces 0).DHCP.IP.Gateway }}:7172"]
                    strict_id: false
                manage_etc_hosts: localhost
                warnings:
                  dsid_missing_source: off
          - name: "Add Tink Cloud-Init DS-Identity"
            image: quay.io/tinkerbell/actions/writefile:latest
            timeout: 90
            environment:
              DEST_DISK: {{ formatPartition ( index .Hardware.Disks 0 ) 3 }}
              FS_TYPE: ext4
              DEST_PATH: /etc/cloud/ds-identify.cfg
              UID: 0
              GID: 0
              MODE: 0600
              DIRMODE: 0700
              CONTENTS: |
                datasource: Ec2
          - name: "Shutdown"
            image: ghcr.io/jacobweinstock/waitdaemon:latest
            timeout: 90
            pid: host
            command: ["sh", "-c", "echo o > /proc/sysrq-trigger"]
            environment:
              IMAGE: alpine
              WAIT_SECONDS: 5
            volumes:
              - /var/run/docker.sock:/var/run/docker.sock
EOF
}

create_workflow_customboot() {
    cat <<EOF | kubectl apply -f -
apiVersion: tinkerbell.org/v1alpha1
kind: Workflow
metadata:
  name: ${VM_NAME}
  namespace: ${NAMESPACE}
spec:
  hardwareRef: ${VM_NAME}
  templateRef: ${VM_NAME}
  hardwareMap:
    device_1: "${VM_MAC}"
  bootOptions:
    toggleAllowNetboot: true
    bootMode: customboot
    custombootConfig:
      preparingActions:
        - powerAction: "off"
        - bootDevice:
            device: pxe
            efiBoot: true
        - powerAction: "on"
      postActions:
        - powerAction: "off"
        - bootDevice:
            device: disk
            efiBoot: true
            persistent: true
        - powerAction: "on"
EOF
}

create_workflow_netboot() {
    cat <<EOF | kubectl apply -f -
apiVersion: tinkerbell.org/v1alpha1
kind: Workflow
metadata:
  name: ${VM_NAME}
  namespace: ${NAMESPACE}
spec:
  hardwareRef: ${VM_NAME}
  templateRef: ${VM_NAME}
  hardwareMap:
    device_1: "${VM_MAC}"
  bootOptions:
    toggleAllowNetboot: true
    bootMode: netboot
EOF
}

create_workflow_isoboot() {
    # Convert MAC address to dash-delimited format for ISO URL
    local mac_dashed
    mac_dashed=$(echo "${VM_MAC}" | tr ':' '-')

    # Use Tinkerbell-served ISO URL (smee serves on port 7171)
    local iso_url="${ISO_URL:-http://${TINKERBELL_IP}:7171/iso/${mac_dashed}/hook.iso}"

    cat <<EOF | kubectl apply -f -
apiVersion: tinkerbell.org/v1alpha1
kind: Workflow
metadata:
  name: ${VM_NAME}
  namespace: ${NAMESPACE}
spec:
  hardwareRef: ${VM_NAME}
  templateRef: ${VM_NAME}
  hardwareMap:
    device_1: "${VM_MAC}"
  bootOptions:
    toggleAllowNetboot: true
    bootMode: isoboot
    isoURL: "${iso_url}"
EOF
}

delete_resources() {
    echo "Deleting resources for ${VM_NAME}..."

    # Delete workflow first
    if kubectl get workflow "${VM_NAME}" -n "${NAMESPACE}" &>/dev/null; then
        kubectl patch workflow "${VM_NAME}" -n "${NAMESPACE}" -p '{"metadata":{"finalizers":null}}' --type=merge 2>/dev/null || true
        kubectl delete workflow "${VM_NAME}" -n "${NAMESPACE}" --ignore-not-found --wait=false
    fi

    # Delete template
    kubectl delete template "${VM_NAME}" -n "${NAMESPACE}" --ignore-not-found --wait=false

    # Delete hardware (remove finalizers first)
    if kubectl get hardware "${VM_NAME}" -n "${NAMESPACE}" &>/dev/null; then
        kubectl patch hardware "${VM_NAME}" -n "${NAMESPACE}" -p '{"metadata":{"finalizers":null}}' --type=merge 2>/dev/null || true
        kubectl label hardware "${VM_NAME}" -n "${NAMESPACE}" v1alpha1.tinkerbell.org/ownerName- v1alpha1.tinkerbell.org/ownerNamespace- 2>/dev/null || true
        kubectl delete hardware "${VM_NAME}" -n "${NAMESPACE}" --ignore-not-found --wait=false
    fi

    # Delete BMC jobs/tasks (job names contain VM name, e.g., iso-mount-vm1)
    # First collect job names, then delete tasks, then delete jobs
    local job_names
    job_names=$(kubectl get job.bmc -n "${NAMESPACE}" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || true)
    for job_name in $job_names; do
        if [[ "$job_name" == *"-${VM_NAME}" ]]; then
            kubectl delete task.bmc -n "${NAMESPACE}" -l "owner-name=${job_name}" --ignore-not-found 2>/dev/null || true
            kubectl delete job.bmc "${job_name}" -n "${NAMESPACE}" --ignore-not-found 2>/dev/null || true
        fi
    done

    # Delete BMC machine
    kubectl delete machine.bmc "${VM_NAME}" -n "${NAMESPACE}" --ignore-not-found --wait=false

    echo "Done."
}

show_status() {
    echo "=== Hardware ==="
    kubectl get hardware "${VM_NAME}" -n "${NAMESPACE}" -o wide 2>/dev/null || echo "Not found"
    echo
    echo "=== Workflow ==="
    kubectl get workflow "${VM_NAME}" -n "${NAMESPACE}" -o wide 2>/dev/null || echo "Not found"
    echo
    echo "=== BMC Machine ==="
    kubectl get machine.bmc "${VM_NAME}" -n "${NAMESPACE}" 2>/dev/null || echo "Not found"
    echo
    echo "=== BMC Jobs ==="
    kubectl get job.bmc,task.bmc -n "${NAMESPACE}" 2>/dev/null | grep -E "NAME|${VM_NAME}" || echo "None"
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -m|--mode)
            BOOT_MODE="$2"
            shift 2
            ;;
        -f|--force)
            FORCE_CLEANUP=true
            shift
            ;;
        -d|--delete)
            ACTION="delete"
            shift
            ;;
        -s|--status)
            ACTION="status"
            shift
            ;;
        -h|--help)
            usage 0
            ;;
        -*)
            echo "Unknown option: $1"
            usage
            ;;
        *)
            if [[ -z "${VM_NAME}" ]]; then
                VM_NAME="$1"
            fi
            shift
            ;;
    esac
done

# Validate
[[ -z "${VM_NAME}" ]] && usage

case "${BOOT_MODE}" in
    customboot|netboot|isoboot)
        ;;
    *)
        echo "ERROR: Invalid boot mode '${BOOT_MODE}'. Must be: customboot, netboot, or isoboot"
        exit 1
        ;;
esac

# Execute action
case "${ACTION}" in
    create)
        if [[ "${FORCE_CLEANUP}" == "true" ]]; then
            echo "Force cleanup enabled, deleting existing resources..."
            delete_resources
            echo
            sleep 2
        fi

        echo "Creating Tinkerbell resources for ${VM_NAME}..."
        echo "  Boot Mode: ${BOOT_MODE}"
        echo "  MAC: ${VM_MAC}"
        echo "  IP: ${VM_IP}"
        echo "  Disk: ${VM_DISK}"
        echo "  Image: ${OS_IMAGE}"
        if [[ "${BOOT_MODE}" == "isoboot" ]]; then
            echo "  ISO: ${ISO_URL:-http://${TINKERBELL_IP}:7171/iso/$(echo "${VM_MAC}" | tr ':' '-')/hook.iso}"
        fi
        echo

        create_bmc_machine
        create_hardware
        create_template

        case "${BOOT_MODE}" in
            customboot)
                create_workflow_customboot
                ;;
            netboot)
                create_workflow_netboot
                ;;
            isoboot)
                create_workflow_isoboot
                ;;
        esac

        echo
        echo "Resources created. Monitor with:"
        echo "  watch 'kubectl get workflow ${VM_NAME} -n ${NAMESPACE} ; virsh domstate ${VM_NAME} --reason'"
        ;;
    delete)
        delete_resources
        ;;
    status)
        show_status
        ;;
esac
