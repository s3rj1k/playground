#!/bin/bash

# Copyright 2025 s3rj1k
# SPDX-License-Identifier: MIT

set -euo pipefail

echo -e "\n* Setting up environment variables..."
export CAPT_VERSION=v0.6.8
export KUBE_VERSION=v1.34.2
export KUBEVIP_VERSION=v1.0.2

export CLUSTER_NAME=capt
export NAMESPACE="tinkerbell"

export SSH_AUTH_KEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKLrIiGjB4nPsyKzgzY21asVi/HKlveRnNY77vOhRhOA"

KIND_NETWORK_INFO=$(docker network inspect kind)
KIND_GATEWAY=$(echo "$KIND_NETWORK_INFO" | jq -r '[.[0].IPAM.Config[] | select(.Gateway) | .Gateway | select(test("^[0-9]+\\."))] | first')
NETWORK_BASE=$(echo "$KIND_GATEWAY" | awk -F"." '{print $1"."$2"."$3}')

export TINKERBELL_IP="${NETWORK_BASE}.100"
export TINKERBELL_ARTIFACTS_SERVER="http://${NETWORK_BASE}.101:7173"
export IMAGE_FILENAME="ubuntu.raw.gz"

export CONTROL_PLANE_VIP="${NETWORK_BASE}.201"

echo -e "\n* Setting up clusterctl..."
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

echo -e "\n* Initializing clusterctl..."
clusterctl --v 1 --config ./clusterctl.yaml init --infrastructure tinkerbell

echo -e "\n* Generating cluster configuration..."
until clusterctl --v 1 generate cluster $CLUSTER_NAME \
	--config ./clusterctl.yaml \
	--kubernetes-version "$KUBE_VERSION" \
	--control-plane-machine-count="1" \
	--worker-machine-count="1" \
	--target-namespace=$NAMESPACE \
	--write-to ./prekustomization.yaml; do
	sleep 5
done

echo -e "\n* Applying kustomization..."
# shellcheck disable=SC2016
envsubst "$(printf '${%s} ' "$(env | cut -d'=' -f1)")" \
	< kustomization.tmpl |
	tee ./kustomization.yaml &&
	kubectl kustomize . -o ./$CLUSTER_NAME.yaml

echo -e "\n* Applying cluster configuration..."
until kubectl apply -f ./$CLUSTER_NAME.yaml --wait; do
	sleep 5
done

echo -e "\n* Watching for control plane node provisioning..."
while [ "$(kubectl get workflow -n $NAMESPACE -o name | wc -l)" -eq 0 ]; do
	sleep 5
done

echo -e "\n* Workflows detected. Press Ctrl+C to stop watching and continue with setup.\n"
kubectl get workflow -n $NAMESPACE --watch || true
echo -e "\n* Continuing with setup...\n"

# kubectl get tinkerbellcluster,kubeadmcontrolplane,tinkerbellmachine -A

echo -e "\n* Getting cluster kubeconfig..."
until clusterctl get kubeconfig -n $NAMESPACE $CLUSTER_NAME > ./$CLUSTER_NAME.kubeconfig; do
	sleep 5
done
export KUBECONFIG=./$CLUSTER_NAME.kubeconfig

echo -e "\n* Waiting for Kubernetes API server to be ready..."
until kubectl get node 2> /dev/null; do
	sleep 5
done

echo -e "\n* Applying kube-router networking..."
until kubectl apply -f https://raw.githubusercontent.com/cloudnativelabs/kube-router/master/daemonset/kubeadm-kuberouter.yaml; do
	sleep 5
done

echo -e "\n* Waiting for all nodes to be ready..."
kubectl wait --for=condition=Ready node --all --timeout=15m
kubectl get nodes -A
