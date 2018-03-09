# Tips on upgrading a cluster's Kubernetes version

The basis of this documentation is built around the post here on zero downtime upgrades:
https://medium.com/retailmenot-engineering/zero-downtime-kubernetes-cluster-upgrades-aab4cac943d2

At the moment, terraform doesn't provide much help in managing K8S versions, and this bug in particular can be referenced for why:
https://github.com/terraform-providers/terraform-provider-google/issues/633

## Steps

* First thing you will want to do is upgrade the master version. You can do this through the UI, or via the console: https://cloud.google.com/kubernetes-engine/docs/how-to/upgrading-a-container-cluster#upgrade_master
```bash
# get the possible versions
gcloud container get-server-config
# update to the specific version
gcloud container clusters upgrade [CLUSTER_NAME] --master --cluster-version [CLUSTER_VERSION]
```
> **TIP** `gcloud beta container operations list` to see the actions running on the cluster
* Using terraform, create new node pool with naming that matches the version you want to upgrade to. _(for example, if there is a `master-pool` running version `1.8.5`, and you're updating to `1.9.2`, create a new node pool named `master-pool-1-9`)_
* If there is autoscaling on the existing node pools (the ones that will be removed), turn autoscaling `off`
```bash
# list the node pools available in this cluster
gcloud container node-pools list --cluster [CLUSTER_NAME]
# turn OFF autoscaling for a particular node pool
gcloud container clusters update [CLUSTER_NAME] --no-enable-autoscaling --node-pool [POOL_NAME]
```
* If the new nodes should be tainted, apply the taints before proceeding
> **TIP** check which taints exist: `kubectl get nodes -o yaml | grep taint -A 4`
* run the script `./drain-nodes.sh -h`
* use terraform to delete the old node
* drain the default node pool and upgrade it to the same version as the master node.
