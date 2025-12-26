#!/bin/bash

# Copyright 2025 s3rj1k
# SPDX-License-Identifier: MIT

set -euo pipefail

echo -e "\n* Setting up environment variables..."
export CAPT_VERSION=v0.6.8
export KUBE_VERSION=v1.34.2
export ENVOY_GATEWAY_VERSION=v1.4.0

export CLUSTER_NAME=capt-hcp
export NAMESPACE="tinkerbell"

export SSH_AUTH_KEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKLrIiGjB4nPsyKzgzY21asVi/HKlveRnNY77vOhRhOA"

KIND_NETWORK_INFO=$(docker network inspect kind)
KIND_GATEWAY=$(echo "$KIND_NETWORK_INFO" | jq -r '[.[0].IPAM.Config[] | select(.Gateway) | .Gateway | select(test("^[0-9]+\\."))] | first')
NETWORK_BASE=$(echo "$KIND_GATEWAY" | awk -F"." '{print $1"."$2"."$3}')

export TINKERBELL_IP="${NETWORK_BASE}.100"
export TINKERBELL_ARTIFACTS_SERVER="http://${NETWORK_BASE}.101:7173"
export IMAGE_FILENAME="ubuntu.raw.gz"

# LoadBalancer IPs for Gateway and HCP services
export GATEWAY_LB_IP="${NETWORK_BASE}.102"
export HCP_LB_IP="${NETWORK_BASE}.103"

echo -e "\n* Installing Envoy Gateway (includes Gateway API CRDs v1.3.0)..."
if ! helm status envoy-gateway -n envoy-gateway-system &>/dev/null; then
    helm install envoy-gateway oci://docker.io/envoyproxy/gateway-helm \
        --version "${ENVOY_GATEWAY_VERSION}" \
        --create-namespace \
        --namespace envoy-gateway-system \
        --wait
fi
kubectl wait --for=condition=Available deployment/envoy-gateway -n envoy-gateway-system --timeout=300s

echo -e "\n* Creating Gateway for HCP..."
cat <<EOF | kubectl apply -f -
apiVersion: gateway.envoyproxy.io/v1alpha1
kind: EnvoyProxy
metadata:
  name: ${CLUSTER_NAME}-proxy-config
  namespace: ${NAMESPACE}
spec:
  provider:
    type: Kubernetes
    kubernetes:
      envoyService:
        type: LoadBalancer
        annotations:
          kube-vip.io/loadbalancerIPs: "${GATEWAY_LB_IP}"
---
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: envoy
spec:
  controllerName: gateway.envoyproxy.io/gatewayclass-controller
  parametersRef:
    group: gateway.envoyproxy.io
    kind: EnvoyProxy
    name: ${CLUSTER_NAME}-proxy-config
    namespace: ${NAMESPACE}
---
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: capi
  namespace: ${NAMESPACE}
spec:
  gatewayClassName: envoy
  listeners:
    - name: tls-passthrough
      protocol: TLS
      port: 443
      hostname: "*.${GATEWAY_LB_IP}.nip.io"
      tls:
        mode: Passthrough
      allowedRoutes:
        namespaces:
          from: Same
        kinds:
          - kind: TLSRoute
EOF

echo -e "\n* Setting up clusterctl for CAPT..."
# shellcheck disable=SC2016
LOCATION="https://github.com/tinkerbell/cluster-api-provider-tinkerbell/releases" \
    envsubst '$LOCATION $CAPT_VERSION' << 'EOF' |
providers:
  - name: tinkerbell
    url: "$LOCATION/$CAPT_VERSION/infrastructure-components.yaml"
    type: InfrastructureProvider
images:
  infrastructure-tinkerbell:
    tag: $CAPT_VERSION
EOF
    tee ./clusterctl.yaml

echo -e "\n* Initializing clusterctl with CAPT..."
clusterctl --v 1 --config ./clusterctl.yaml init --infrastructure tinkerbell

echo -e "\n* Installing cluster-api-provider-hosted-control-plane..."
kubectl apply -f https://github.com/teutonet/cluster-api-provider-hosted-control-plane/releases/latest/download/control-plane-components.yaml
kubectl wait --for=condition=Available deployment -l control-plane=controller-manager -n cluster-api-provider-hosted-control-plane-system --timeout=300s || true

echo -e "\n* Creating cluster manifests..."
cat <<EOF > ./$CLUSTER_NAME.yaml
---
apiVersion: cluster.x-k8s.io/v1beta1
kind: Cluster
metadata:
  name: ${CLUSTER_NAME}
  namespace: ${NAMESPACE}
spec:
  clusterNetwork:
    pods:
      cidrBlocks:
        - 192.168.0.0/18
    services:
      cidrBlocks:
        - 10.96.0.0/12
  controlPlaneRef:
    apiVersion: controlplane.cluster.x-k8s.io/v1alpha1
    kind: HostedControlPlane
    name: ${CLUSTER_NAME}
  infrastructureRef:
    apiVersion: infrastructure.cluster.x-k8s.io/v1beta1
    kind: TinkerbellCluster
    name: ${CLUSTER_NAME}
---
apiVersion: infrastructure.cluster.x-k8s.io/v1beta1
kind: TinkerbellCluster
metadata:
  name: ${CLUSTER_NAME}
  namespace: ${NAMESPACE}
spec:
  imageLookupFormat: "{{.BaseRegistry}}/{{.OSDistro}}-{{.OSVersion}}:{{.KubernetesVersion}}.gz"
  imageLookupBaseRegistry: ghcr.io/s3rj1k/playground
  imageLookupOSDistro: ubuntu
  imageLookupOSVersion: "2404"
---
apiVersion: controlplane.cluster.x-k8s.io/v1alpha1
kind: HostedControlPlane
metadata:
  name: ${CLUSTER_NAME}
  namespace: ${NAMESPACE}
spec:
  version: ${KUBE_VERSION}
  replicas: 1
  gateway:
    namespace: ${NAMESPACE}
    name: capi
  deployment:
    controllerManager:
      args:
        allocate-node-cidrs: "true"
  konnectivityClient:
    replicas: 1
  kubeProxy: {}
  coredns: {}
---
apiVersion: infrastructure.cluster.x-k8s.io/v1beta1
kind: TinkerbellMachineTemplate
metadata:
  name: ${CLUSTER_NAME}-worker
  namespace: ${NAMESPACE}
spec:
  template:
    spec:
      hardwareAffinity:
        required:
          - labelSelector:
              matchLabels:
                tinkerbell.org/role: hcp-worker
      bootOptions:
        bootMode: customboot
        custombootConfig:
          preparingActions:
            - powerAction: "off"
            - bootDevice:
                device: "pxe"
                efiBoot: true
            - powerAction: "on"
          postActions:
            - powerAction: "off"
            - bootDevice:
                device: "disk"
                persistent: true
                efiBoot: true
            - powerAction: "on"
      templateOverride: |
        version: "0.1"
        name: hcp-worker
        global_timeout: 3600
        tasks:
          - name: "hcp-worker"
            worker: "{{.device_1}}"
            volumes:
              - /dev:/dev
              - /dev/console:/dev/console
              - /lib/firmware:/lib/firmware:ro
            actions:
              - name: "Stream Ubuntu Image"
                image: quay.io/tinkerbell/actions/image2disk:latest
                timeout: 600
                environment:
                  DEST_DISK: {{ index .Hardware.Disks 0 }}
                  IMG_URL: ${TINKERBELL_ARTIFACTS_SERVER}/${IMAGE_FILENAME}
                  COMPRESSED: true

              - name: "Sync and Grow Partition"
                image: quay.io/tinkerbell/actions/cexec:latest
                timeout: 90
                environment:
                  BLOCK_DEVICE: {{ index .Hardware.Disks 0 }}3
                  FS_TYPE: ext4
                  CHROOT: y
                  DEFAULT_INTERPRETER: "/bin/sh -c"
                  CMD_LINE: "sync && growpart {{ index .Hardware.Disks 0 }} 3 && resize2fs {{ index .Hardware.Disks 0 }}3 && sync"

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
                        metadata_urls: ["http://${TINKERBELL_IP}:7172"]
                        strict_id: false
                    system_info:
                      default_user:
                        name: tink
                        plain_text_passwd: tink
                        lock_passwd: false
                        groups: [wheel, adm, sudo]
                        sudo: ["ALL=(ALL) NOPASSWD:ALL"]
                        shell: /bin/bash
                        ssh_authorized_keys:
                          - ${SSH_AUTH_KEY}
                    ssh_pwauth: false
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

              - name: "Shutdown host"
                image: ghcr.io/jacobweinstock/waitdaemon:latest
                timeout: 90
                pid: host
                command: ["poweroff"]
                environment:
                  IMAGE: alpine
                  WAIT_SECONDS: 10
                volumes:
                  - /var/run/docker.sock:/var/run/docker.sock
---
apiVersion: bootstrap.cluster.x-k8s.io/v1beta1
kind: KubeadmConfigTemplate
metadata:
  name: ${CLUSTER_NAME}-worker
  namespace: ${NAMESPACE}
spec:
  template:
    spec:
      joinConfiguration:
        nodeRegistration:
          kubeletExtraArgs:
            provider-id: "tinkerbell://{{ ds.meta_data.instance_id }}"
      preKubeadmCommands:
        - systemctl enable --now containerd
        - sleep 10
---
apiVersion: cluster.x-k8s.io/v1beta1
kind: MachineDeployment
metadata:
  name: ${CLUSTER_NAME}-worker
  namespace: ${NAMESPACE}
  labels:
    cluster.x-k8s.io/cluster-name: ${CLUSTER_NAME}
    nodepool: worker-pool
spec:
  clusterName: ${CLUSTER_NAME}
  replicas: 1
  selector:
    matchLabels:
      cluster.x-k8s.io/cluster-name: ${CLUSTER_NAME}
      nodepool: worker-pool
  template:
    metadata:
      labels:
        cluster.x-k8s.io/cluster-name: ${CLUSTER_NAME}
        nodepool: worker-pool
    spec:
      clusterName: ${CLUSTER_NAME}
      version: ${KUBE_VERSION}
      bootstrap:
        configRef:
          apiVersion: bootstrap.cluster.x-k8s.io/v1beta1
          kind: KubeadmConfigTemplate
          name: ${CLUSTER_NAME}-worker
      infrastructureRef:
        apiVersion: infrastructure.cluster.x-k8s.io/v1beta1
        kind: TinkerbellMachineTemplate
        name: ${CLUSTER_NAME}-worker
EOF

echo -e "\n* Applying cluster configuration..."
until kubectl apply -f ./$CLUSTER_NAME.yaml --wait; do
    sleep 5
done

echo -e "\n* Annotating HCP service for kube-vip IP assignment..."
until kubectl get svc "s-${CLUSTER_NAME}" -n $NAMESPACE &>/dev/null; do
    echo "Waiting for HCP service..."
    sleep 5
done
kubectl annotate svc "s-${CLUSTER_NAME}" -n $NAMESPACE "kube-vip.io/loadbalancerIPs=${HCP_LB_IP}" --overwrite

echo -e "\n* Waiting for HostedControlPlane to be ready..."
until kubectl get hostedcontrolplane -n $NAMESPACE $CLUSTER_NAME -o jsonpath='{.status.ready}' 2>/dev/null | grep -q "true"; do
    echo "Waiting for HCP to initialize..."
    kubectl get hostedcontrolplane -n $NAMESPACE 2>/dev/null || true
    sleep 10
done

echo -e "\n* Watching for worker node provisioning..."
while [ "$(kubectl get workflow -n $NAMESPACE -o name | wc -l)" -eq 0 ]; do
    sleep 5
done

echo -e "\n* Workflows detected. Press Ctrl+C to stop watching and continue with setup.\n"
kubectl get workflow -n $NAMESPACE --watch || true
echo -e "\n* Continuing with setup...\n"

echo -e "\n* Getting cluster kubeconfig..."
until kubectl get secret ${CLUSTER_NAME}-kubeconfig -n $NAMESPACE &>/dev/null; do
    echo "Waiting for kubeconfig secret..."
    sleep 5
done
kubectl get secret ${CLUSTER_NAME}-kubeconfig -n $NAMESPACE -o jsonpath='{.data.value}' | base64 -d > ./$CLUSTER_NAME.kubeconfig
export KUBECONFIG=./$CLUSTER_NAME.kubeconfig

echo -e "\n* Waiting for Kubernetes API server to be ready..."
until kubectl get node 2> /dev/null; do
    sleep 5
done

echo -e "\n* Installing Cilium CNI..."
CILIUM_CLI_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt)
curl -L --fail --remote-name-all "https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-amd64.tar.gz{,.sha256sum}"
sha256sum --check cilium-linux-amd64.tar.gz.sha256sum
tar xzvfC cilium-linux-amd64.tar.gz /usr/local/bin
rm cilium-linux-amd64.tar.gz{,.sha256sum}
cilium install \
    --set ipam.mode=kubernetes \
    --set k8sServiceHost=${CLUSTER_NAME}.${NAMESPACE}.${GATEWAY_LB_IP}.nip.io \
    --set k8sServicePort=443 \
    --set tolerations[0].key=node.cluster.x-k8s.io/uninitialized \
    --set tolerations[0].operator=Exists \
    --set tolerations[0].effect=NoSchedule \
    --set tolerations[1].key=node.kubernetes.io/not-ready \
    --set tolerations[1].operator=Exists \
    --set tolerations[1].effect=NoSchedule \
    --set operator.tolerations[0].key=node.cluster.x-k8s.io/uninitialized \
    --set operator.tolerations[0].operator=Exists \
    --set operator.tolerations[0].effect=NoSchedule \
    --set operator.tolerations[1].key=node.kubernetes.io/not-ready \
    --set operator.tolerations[1].operator=Exists \
    --set operator.tolerations[1].effect=NoSchedule

echo -e "\n* Removing node taints..."
kubectl taint nodes --all node.cluster.x-k8s.io/uninitialized:NoSchedule- 2>/dev/null || true
kubectl taint nodes --all node.kubernetes.io/not-ready:NoSchedule- 2>/dev/null || true

echo -e "\n* Waiting for nodes to join..."
until kubectl get nodes 2>/dev/null | grep -q .; do
    sleep 5
done

echo -e "\n* Waiting for all nodes to be ready..."
kubectl wait --for=condition=Ready node --all --timeout=15m
kubectl get nodes -A

echo -e "\n* Setup complete!"
echo "Kubeconfig: ./$CLUSTER_NAME.kubeconfig"
echo "HCP endpoint: ${CLUSTER_NAME}.${NAMESPACE}.${GATEWAY_LB_IP}.nip.io"
echo "kubectl --kubeconfig=./$CLUSTER_NAME.kubeconfig get nodes"
