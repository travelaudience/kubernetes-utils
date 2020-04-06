#!/bin/bash

set -e

function output_help {
    echo "Usage: `basename $0` <kubernetes_namespace_to_clean>";
}

if [ "$#" -ne 1 ]; then
    echo "Illegal number of parameters, you need to specify k8s namespace"
    echo ""
    output_help
    exit 1
fi

namespace=$1

env_secrets=$(kubectl --namespace $namespace get pods -o jsonpath='{.items[*].spec.containers[*].env[*].valueFrom.secretKeyRef.name}' | xargs -n1)
volume_secrets=$(kubectl --namespace $namespace  get pods -o jsonpath='{.items[*].spec.volumes[*].secret.secretName}' | xargs -n1)
pull_secrets=$(kubectl --namespace $namespace  get pods -o jsonpath='{.items[*].spec.imagePullSecrets[*].name}' | xargs -n1)
tls_secrets=$(kubectl --namespace $namespace  get ingress -o jsonpath='{.items[*].spec.tls[*].secretName}' | xargs -n1)

unused_secrets=$(grep -vxFf \
<(echo "$env_secrets\n$volume_secrets\n$pull_secrets\n$tls_secrets" | sort | uniq) \
<(kubectl --namespace $namespace get secrets -o jsonpath='{.items[*].metadata.name}' | xargs -n1 | sort | uniq))

RED='\033[0;31m'
NC='\033[0m' # No Color

if [ ${#unused_secrets[@]} -eq 0 ]
then
    echo "No secrets to delete"
else
    printf "${RED}Going to delete the following secrets:\n"
    for c in "${unused_secrets[@]}"; do printf "${RED}$c${NC}\n"; done
    echo -n "Are you sure you want to clean these secrets... [ENTER]"
    read ready
    kubectl -n $NAMESPACE delete secrets ${unused_secrets[*]}	
fi
