# Kubernetes Cluster Maintenance Scripts

## Clean up unused PVs & PVCs

PVs and PVCs can stay unsused forever. This utility script will clean up all that PVs and related PVCs

**Usage:**

```bash
bash cleanup_unused_pv_pvc.sh <kubernetes_namespace>
```
