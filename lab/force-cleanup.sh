#!/bin/bash
set -euo pipefail

force_delete() {
    local type="$1"
    kubectl get "$type" -A -o jsonpath='{range .items[*]}{.metadata.namespace}/{.metadata.name}{"\n"}{end}' 2>/dev/null | while read -r item; do
        [[ -z "$item" ]] && continue
        ns="${item%/*}"; name="${item#*/}"
        echo "Deleting $type $name in $ns"
        kubectl patch "$type" "$name" -n "$ns" --type=json -p='[{"op":"remove","path":"/metadata/finalizers"}]' 2>/dev/null || true
        kubectl delete "$type" "$name" -n "$ns" --wait=false 2>/dev/null || true
    done
}

RESOURCES=(
    "clusters.cluster.x-k8s.io"
    "helmchartproxies.addons.cluster.x-k8s.io"
    "hostedcontrolplanes.controlplane.cluster.x-k8s.io"
    "kubeadmconfigs.bootstrap.cluster.x-k8s.io"
    "kubeadmconfigtemplates.bootstrap.cluster.x-k8s.io"
    "kubeadmcontrolplanes.controlplane.cluster.x-k8s.io"
    "machinedeployments.cluster.x-k8s.io"
    "machines.cluster.x-k8s.io"
    "machinesets.cluster.x-k8s.io"
    "metal3clusters.infrastructure.cluster.x-k8s.io"
    "metal3datas.infrastructure.cluster.x-k8s.io"
    "metal3datatemplates.infrastructure.cluster.x-k8s.io"
    "metal3kubeadmclusters.kro.run"
    "metal3machine.infrastructure.cluster.x-k8s.io"
    "metal3machines.infrastructure.cluster.x-k8s.io"
    "metal3machinetemplates.infrastructure.cluster.x-k8s.io"
    "tinkerbellclusters.infrastructure.cluster.x-k8s.io"
    "tinkerbellkubeadmclusters.kro.run"
    "tinkerbellkubeadmhostedclusters.kro.run"
    "tinkerbellmachinetemplates.infrastructure.cluster.x-k8s.io"
)

for r in "${RESOURCES[@]}"; do force_delete "$r"; done
