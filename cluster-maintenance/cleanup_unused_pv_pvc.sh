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

NAMESPACE=$1

claims_in_use=$(kubectl get pods -n $NAMESPACE -o=json | jq -c '.items[] | {claimName: .spec.volumes[] | select( has ("persistentVolumeClaim") ).persistentVolumeClaim.claimName }.claimName')
all_claims=$(kubectl get pvc -n $NAMESPACE | tail -n +2 | awk '{print $1}')

claims_to_delete=()
for claim in $all_claims
do
    [[ $all_claims =~ (^|[[:space:]])"$claim"($|[[:space:]]) ]] && printf "" || claims_to_delete+=($claim)
done

RED='\033[0;31m'
NC='\033[0m' # No Color

if [ ${#claims_to_delete[@]} -eq 0 ]
then
    echo "No PersistentVolumeClaim to delete"
else
    printf "${RED}Going to delete the following claims:\n"
    for c in "${claims_to_delete[@]}"; do printf "${RED}$c${NC}\n"; done
    echo -n "Are you sure you want to clean this claims... [ENTER]"
    read ready
    kubectl -n $NAMESPACE delete pvc ${claims_to_delete[*]}	
fi

pv_to_delete=($(kubectl -n $NAMESPACE get pv | tail -n +2 | grep -v Bound | awk '{print $1}'))
if [ ${#pv_to_delete[@]} -eq 0 ]
then
	echo "No PersistentVolume to delete"
else
    printf "${RED}Going to clean up unbound PVs"
    for c in "${pv_to_delete[@]}"; do printf "${RED}$c${NC}\n"; done
    echo -n "Are you sure you want to clean this pvs... [ENTER]"
    read ready
    kubectl -n $NAMESPACE delete pv ${pv_to_delete[*]}
fi
