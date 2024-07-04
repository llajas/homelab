#!/bin/bash

# Check if NAS address is provided
if [ -z "$NAS_ADDRESS" ]; then
  echo "Please set the NAS_ADDRESS environment variable."
  exit 1
fi

# Function to login to ArgoCD if not already logged in
argocd_login() {
  if argocd account get-user-info | grep -q 'Logged In: false'; then
    echo "Logging into ArgoCD..."
    argocd login "$ARGOCD_SERVER" --username "$ARGOCD_USERNAME" --password "$ARGOCD_PASSWORD" --grpc-web
  fi
}

# Function to create or update an ArgoCD sync window
create_sync_window() {
  echo "Creating ArgoCD sync window for affected namespaces: $affected_namespaces"
  argocd proj windows add default -k deny --schedule "* * * * *" --duration 24h --namespaces "$affected_namespaces" --manual-sync || \
  argocd proj windows update default -k deny --schedule "* * * * *" --duration 24h --namespaces "$affected_namespaces" --manual-sync
}

# Function to remove the ArgoCD sync window
remove_sync_window() {
  echo "Removing ArgoCD sync window"
  argocd proj windows delete default 0
}

# Function to scale down specific workloads
scale_down() {
  echo "Scaling down deployments and statefulsets dependent on NAS..."

  # Get PVs that are dependent on NAS
  pv_list=$(kubectl get pv -A --no-headers | grep -v longhorn | awk '{print $1}')

  namespaces=()
  pvc_list=()

  # Normalize NAS_ADDRESS to ensure it doesn't have a trailing slash
  NAS_ADDRESS="${NAS_ADDRESS%/}"

  # Check each PV to see if it's using the NAS
  for pv in $pv_list; do
    source=$(kubectl get pv "$pv" -o json | jq -r '.spec.csi.volumeAttributes.source // .spec.nfs.server')
    echo "Checking PV: $pv with source: $source"  # Debug output
    normalized_source="${source%/}"
    if [[ "$normalized_source" == "//$NAS_ADDRESS" || "$normalized_source" == "$NAS_ADDRESS" ]]; then
      echo "Source matched: $normalized_source == //$NAS_ADDRESS or $NAS_ADDRESS"  # Debug output
      claim=$(kubectl get pv "$pv" -o json | jq -r '.spec.claimRef.name')
      namespace=$(kubectl get pv "$pv" -o json | jq -r '.spec.claimRef.namespace')
      echo "Identified NAS-dependent PV: $pv in namespace: $namespace with claim: $claim"  # Debug output
      pvc_list+=("${namespace}/${claim}")
      namespaces+=("$namespace")
    else
      echo "Source did not match: $normalized_source != //${NAS_ADDRESS} and $normalized_source != $NAS_ADDRESS"  # Debug output
    fi
  done

  # Remove duplicates from namespaces array
  mapfile -t namespaces < <(printf "%s\n" "${namespaces[@]}" | sort -u)
  mapfile -t pvc_list < <(printf "%s\n" "${pvc_list[@]}" | sort -u)

  echo "Namespaces array: ${namespaces[*]}"  # Debug output
  echo "PVC List array: ${pvc_list[*]}"  # Debug output

  if [ ${#namespaces[@]} -eq 0 ]; then
    echo "No namespaces found with NAS-dependent PVs."
    return
  fi

  echo "Affected namespaces: ${namespaces[*]}"  # Debug output

  # Create ArgoCD sync window for affected namespaces
  affected_namespaces=$(IFS=, ; echo "${namespaces[*]}")
  echo "Creating sync window for namespaces: $affected_namespaces"  # Debug output
  create_sync_window

  # Scale down deployments and statefulsets using the PVCs
  for pvc in "${pvc_list[@]}"; do
    namespace=$(echo "$pvc" | cut -d/ -f1)
    claim=$(echo "$pvc" | cut -d/ -f2)
    echo "Scaling down workloads in namespace $namespace using PVC $claim"

    # Scale down deployments
    deployments=$(kubectl get deployment -n "$namespace" -o=json | jq -r ".items[] | select(.spec.template.spec.volumes[]?.persistentVolumeClaim.claimName == \"$claim\") | .metadata.name")
    echo "Deployments in namespace $namespace using PVC $claim: $deployments"  # Debug output
    if [ -n "$deployments" ]; then
      echo "Found deployments using PVC $claim in namespace $namespace: $deployments"  # Debug output
      for deployment in $deployments; do
        echo "Scaling down deployment: $deployment in namespace: $namespace"  # Debug output
        kubectl scale deployment "$deployment" --namespace="$namespace" --replicas=0
      done
    else
      echo "No deployments found using PVC $claim in namespace $namespace"  # Debug output
    fi

    # Scale down statefulsets
    statefulsets=$(kubectl get statefulset -n "$namespace" -o=json | jq -r ".items[] | select(.spec.template.spec.volumes[]?.persistentVolumeClaim.claimName == \"$claim\") | .metadata.name")
    echo "Statefulsets in namespace $namespace using PVC $claim: $statefulsets"  # Debug output
    if [ -n "$statefulsets" ]; then
      echo "Found statefulsets using PVC $claim in namespace $namespace: $statefulsets"  # Debug output
      for statefulset in $statefulsets; do
        echo "Scaling down statefulset: $statefulset in namespace: $namespace"  # Debug output
        kubectl scale statefulset "$statefulset" --namespace="$namespace" --replicas=0
      done
    else
      echo "No statefulsets found using PVC $claim in namespace $namespace"  # Debug output
    fi

    kubectl label namespace "$namespace" nas-dependent=scaled --overwrite
  done

  echo "Scaling down complete."
}

# Function to revert workloads using ArgoCD
revert_workloads() {
  echo "Reverting workloads using ArgoCD..."

  # Get namespaces labeled as scaled down
  mapfile -t namespaces < <(kubectl get namespaces -l nas-dependent=scaled -o jsonpath='{.items[*].metadata.name}')

  if [ ${#namespaces[@]} -eq 0 ]; then
    echo "No namespaces found with nas-dependent=scaled label."
    exit 1
  fi

  echo "Namespaces to revert: ${namespaces[*]}"  # Debug output

  # Login to ArgoCD if not already logged in
  argocd_login

  # Remove the ArgoCD sync window
  remove_sync_window

  # Sync the workloads back to their desired state
  for namespace in "${namespaces[@]}"; do
    echo "Reverting workloads in namespace $namespace"
    sync_command="argocd app sync $namespace"
    echo "Executing: $sync_command"
    $sync_command || { echo "Failed to sync ArgoCD app for namespace $namespace"; exit 1; }

    label_command="kubectl label namespace $namespace nas-dependent- --overwrite"
    echo "Executing: $label_command"
    $label_command || { echo "Failed to remove label from namespace $namespace"; exit 1; }
  done

  echo "Reversion complete."
}

# Main logic
if [ "$1" == "down" ]; then
  if [ -z "$ARGOCD_SERVER" ] || [ -z "$ARGOCD_USERNAME" ] || [ -z "$ARGOCD_PASSWORD" ]; then
    echo "Please set ARGOCD_SERVER, ARGOCD_USERNAME, and ARGOCD_PASSWORD environment variables."
    exit 1
  fi
  argocd_login
  scale_down
elif [ "$1" == "up" ]; then
  if [ -z "$ARGOCD_SERVER" ] || [ -z "$ARGOCD_USERNAME" ] || [ -z "$ARGOCD_PASSWORD" ]; then
    echo "Please set ARGOCD_SERVER, ARGOCD_USERNAME, and ARGOCD_PASSWORD environment variables."
    exit 1
  fi
  argocd_login
  revert_workloads
else
  echo "Usage: $0 [down|up]"
  echo "  down: Scale down all NAS-dependent workloads to 0 replicas and create ArgoCD sync window."
  echo "  up: Revert all NAS-dependent workloads using ArgoCD and remove the sync window."
  exit 1
fi
