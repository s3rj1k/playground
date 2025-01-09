#!/bin/bash

# Based on `capt` from https://github.com/tinkerbell/playground.git
# clone: git clone https://github.com/s3rj1k/k8s-playground.git && cd k8s-playground/capt

# code formatter: shfmt -s -w -sr -kp -fn -bn auto.sh
# commit to gist: git commit --allow-empty-message -S -am ''

set -euo pipefail

echo -e "\n* Stopping all running containers..."
docker ps -q | xargs -r docker stop -t 0

echo -e "\n* Deleting all kind clusters..."
kind delete clusters --all || true

echo -e "\n* Cleaning up Docker system..."
docker system prune -af

for vm in $(virsh list --all --name | grep "^node"); do
	echo -e "\n* Force destroying VM: $vm"
	virsh destroy "$vm" || true

	echo -e "\n* Undefining VM: $vm with complete cleanup"
	virsh undefine "$vm" --remove-all-storage --nvram --snapshots-metadata --managed-save || true
done

echo -e "\n* Creating output directory..."
mkdir -vp ~/output/

echo -e "\n* Setting up environment variables..."
export CAPT_VERSION=v0.6.2
export CHART_VERSION=0.6.2
export KUBE_VERSION=v1.29.4
export KUBEVIP_VERSION=0.8.7

export CLUSTER_NAME=capt
export NAMESPACE="tink"

export OS_REGISTRY=ghcr.io/tinkerbell/cluster-api-provider-tinkerbell
export OS_DISTRO=ubuntu
export VERSIONS_OS=20.04
export OS_VERSION=$(echo $VERSIONS_OS | sed 's/\.//')
export SSH_AUTH_KEY=

export NODE1_MAC="02:7f:92:bd:2d:57"
export NODE2_MAC="02:f3:eb:c1:aa:2b"

echo -e "\n* Creating kind cluster..."
kind create cluster --verbosity 1 --wait 5m --name $CLUSTER_NAME --kubeconfig ~/output/kind.kubeconfig
export KUBECONFIG=~/output/kind.kubeconfig

echo -e "\n* Setting up network configuration..."
export BRIDGE_NAME="br-$(docker network inspect -f '{{.Id}}' kind | cut -c1-12)"
export GATEWAY_IP=$(docker inspect -f '{{ .NetworkSettings.Networks.kind.Gateway }}' $CLUSTER_NAME-control-plane)
export TRUSTED_PROXIES=$(kubectl get nodes -o jsonpath='{.items[*].spec.podCIDR}')
export NODE_IP_BASE=$(awk -F"." '{print $1"."$2".10.20"}' <<< "$GATEWAY_IP")
export TINKERBELL_IP=$(echo "$NODE_IP_BASE" | awk -F"." '{print $1"."$2"."$3"."($4+54)}')
export CONTROL_PLANE_VIP=$(echo "$TINKERBELL_IP" | awk -F"." '{print $1"."$2"."$3"."($4+1)}')
export POD_CIDR=$(awk -F"." '{print $1".100.0.0/16"}' <<< "$GATEWAY_IP")

export BMC_IP=$GATEWAY_IP
export BMC_PASS_BASE64=$(cat /root/.ipmi_password | base64)

echo -e "\n* Installing tink-stack..."
helm install tink-stack oci://ghcr.io/tinkerbell/charts/stack \
	--version $CHART_VERSION \
	--create-namespace \
	--namespace $NAMESPACE \
	--wait \
	--timeout 15m \
	--set "global.trustedProxies={$TRUSTED_PROXIES}" \
	--set "global.publicIP=$TINKERBELL_IP" \
	--set "stack.image=public.ecr.aws/nginx/nginx:latest" \
	--set "stack.hook.image=public.ecr.aws/docker/library/bash:latest"

create_vm()
{
	local node_name=$1
	local mac_address=$2

	echo -e "\n* Creating VM: $node_name with MAC: $mac_address"
	virt-install \
		--description "CAPT VM" \
		--ram "2048" --vcpus "2" \
		--os-variant "ubuntu20.04" \
		--graphics "vnc" \
		--boot "uefi,firmware.feature0.name=enrolled-keys,firmware.feature0.enabled=no,firmware.feature1.name=secure-boot,firmware.feature1.enabled=yes" \
		--noautoconsole \
		--noreboot \
		--import \
		--connect "qemu:///system" \
		--name "$node_name" \
		--disk "path=/var/lib/libvirt/images/${node_name}-disk.img,bus=virtio,size=10,sparse=yes" \
		--network "bridge:$BRIDGE_NAME,mac=$mac_address"
}

create_vm "node1" $NODE1_MAC
create_vm "node2" $NODE2_MAC

create_bmc_secret()
{
	local node_name=$1

	echo -e "\n* Creating BMC secret: $node_name"
	NODE_NAME="$node_name" \
		BMC_USER_BASE64=$(echo -n "$node_name" | base64) \
		envsubst '$NODE_NAME $NAMESPACE $BMC_USER_BASE64 $BMC_PASS_BASE64' \
		< templates/bmc-secret.tmpl \
		| tee ~/output/bmc-secret-${node_name}.yaml \
		&& until kubectl apply -f ~/output/bmc-secret-${node_name}.yaml; do
			sleep 3
		done
}

create_bmc_secret "node1"
create_bmc_secret "node2"

create_bmc_machine()
{
	local node_name=$1
	local bmc_port=$2

	echo -e "\n* Creating BMC machine: $node_name with port: $bmc_port"
	NODE_NAME="$node_name" \
		BMC_PORT="$bmc_port" \
		envsubst '$NODE_NAME $NAMESPACE $BMC_IP $BMC_PORT' \
		< templates/bmc-machine.tmpl \
		| tee ~/output/bmc-machine-${node_name}.yaml \
		&& until kubectl apply -f ~/output/bmc-machine-${node_name}.yaml; do
			sleep 3
		done
}

create_bmc_machine "node1" "623"
create_bmc_machine "node2" "623"

create_hardware()
{
	local node_role=$1
	local node_name=$2
	local node_mac=$3
	local ip_offset=$4

	echo -e "\n* Creating hardware configuration for $node_name (role: $node_role)"
	NODE_ROLE="$node_role" \
		NODE_NAME="$node_name" \
		NODE_IP="$(echo "$NODE_IP_BASE" | awk -F"." '{print $1"."$2"."$3"."($4+'$ip_offset')}')" \
		NODE_MAC="$node_mac" \
		envsubst '$NODE_ROLE $NODE_NAME $NAMESPACE $NODE_IP $GATEWAY_IP $NODE_MAC' \
		< templates/hardware.tmpl \
		| tee ~/output/hardware-${node_name}.yaml \
		&& until kubectl apply -f ~/output/hardware-${node_name}.yaml; do
			sleep 3
		done
}

create_hardware "control-plane" "node1" $NODE1_MAC "1"
create_hardware "worker" "node2" $NODE2_MAC "2"

echo -e "\n* Setting up clusterctl..."
LOCATION="https://github.com/tinkerbell/cluster-api-provider-tinkerbell/releases" \
	envsubst '$LOCATION $CAPT_VERSION' \
	< templates/clusterctl.tmpl \
	| tee ~/output/clusterctl.yaml

echo -e "\n* Initializing clusterctl..."
clusterctl --v 1 --config ~/output/clusterctl.yaml init --infrastructure tinkerbell

echo -e "\n* Generating cluster configuration..."
until clusterctl --v 1 generate cluster $CLUSTER_NAME \
	--config ~/output/clusterctl.yaml \
	--kubernetes-version "$KUBE_VERSION" \
	--control-plane-machine-count="1" \
	--worker-machine-count="1" \
	--target-namespace=tink \
	--write-to ~/output/prekustomization.yaml 2> /dev/null; do
	sleep 5
done

echo -e "\n* Applying kustomization..."
envsubst "$(printf '${%s} ' $(env | cut -d'=' -f1))" \
	< templates/kustomization-netboot.tmpl \
	| tee ~/output/kustomization.yaml \
	&& kubectl kustomize ~/output -o ~/output/$CLUSTER_NAME.yaml

echo -e "\n* Applying cluster configuration..."
until kubectl apply -f ~/output/$CLUSTER_NAME.yaml --wait 2> /dev/null; do
	sleep 5
done

echo -e "\n* Watching for control plane node provisioning..."
while [ "$(kubectl get workflow -n tink -o name | wc -l)" -eq 0 ]; do
	sleep 5
done
kubectl wait --for=jsonpath='{.status.state}'=STATE_SUCCESS workflow --all -n tink --timeout=1h

echo -e "\n* Getting cluster kubeconfig..."
until clusterctl get kubeconfig -n tink $CLUSTER_NAME > ~/output/$CLUSTER_NAME.kubeconfig 2> /dev/null; do
	sleep 5
done
export KUBECONFIG=~/output/$CLUSTER_NAME.kubeconfig

echo -e "\n* Waiting for Kubernetes API server to be ready..."
until kubectl get node 2> /dev/null; do
	sleep 5
done

echo -e "\n* Applying kube-router networking..."
until kubectl apply -f https://raw.githubusercontent.com/cloudnativelabs/kube-router/master/daemonset/kubeadm-kuberouter.yaml 2> /dev/null; do
	sleep 5
done

echo -e "\n* Waiting for all nodes to be ready..."
kubectl wait --for=condition=Ready node --all --timeout=15m
kubectl get nodes -A
