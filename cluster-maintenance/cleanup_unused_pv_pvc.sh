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

CLAIMS_IN_USE=$(kubectl get pods -n $NAMESPACE -o=json | jq -c '.items[] | {claimName: .spec.volumes[] | select( has ("persistentVolumeClaim") ).persistentVolumeClaim.claimName }.claimName')
ALL_CLAIMS=$(kubectl get pvc -n $NAMESPACE | tail -n +2 | awk '{print $1}')

echo "--------- CLAIMS IN USE ---------"
echo $CLAIMS_IN_USE

echo "> Going to delete claims"
for claim_to_delete in $ALL_CLAIMS
do
	to_delete=true
    for claim_in_use in $CLAIMS_IN_USE
	do
		if [[ "\""$claim_to_delete"\"" == $claim_in_use ]]
		then
			echo "Skipping claim "$claim_to_delete
	    	to_delete=false
    	fi 
	done

	if $to_delete
	then
    	echo "Going to delete "$claim_to_delete
    	kubectl -n $NAMESPACE delete pvc $claim_to_delete
	fi 
done

echo "> Going to clean up unbound PVs"
kubectl -n $NAMESPACE get pv | tail -n +2 | grep -v Bound | \
  awk '{print $1}' | xargs -I{} kubectl -n $NAMESPACE delete pv {}

