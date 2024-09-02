#!/bin/bash

# Function to check if NAS address is provided
check_nas_address() {
  if [ -z "$NAS_ADDRESS" ]; then
    echo "Please set the NAS_ADDRESS environment variable."
    exit 1
  fi
}

# Normalize NAS_ADDRESS to create NFS and SMB versions
normalize_nas_address() {
  # Create SMB version with leading '//' and no trailing slash
  if [[ "$NAS_ADDRESS" != //* ]]; then
    SMB_NAS_ADDRESS="//$NAS_ADDRESS"
  else
    SMB_NAS_ADDRESS="$NAS_ADDRESS"
  fi
  SMB_NAS_ADDRESS="${SMB_NAS_ADDRESS%/}"

  # Create NFS version without leading '//' and no trailing slash
  NFS_NAS_ADDRESS="${NAS_ADDRESS#//}"
  NFS_NAS_ADDRESS="${NFS_NAS_ADDRESS%/}"
}

# Function to get PVs that are dependent on NAS
get_pv_list_dependent_on_nas() {
  # Normalize the NAS address first
  normalize_nas_address

  # Query Kubernetes for PVs dependent on the NAS
  pv_list=$(kubectl get pv -A -o json | jq -r --arg SMB_NAS_ADDRESS "$SMB_NAS_ADDRESS" --arg NFS_NAS_ADDRESS "$NFS_NAS_ADDRESS" '
    .items[] |
    {
      name: .metadata.name,
      csi_source: .spec.csi.volumeAttributes.source,
      nfs_server: .spec.nfs.server,
      matches: (
        (.spec.csi.volumeAttributes.source != null and 
          (.spec.csi.volumeAttributes.source == $SMB_NAS_ADDRESS or .spec.csi.volumeAttributes.source == $SMB_NAS_ADDRESS + "/")) or
        (.spec.nfs.server != null and .spec.nfs.server == $NFS_NAS_ADDRESS)
      )
    } | select(.matches) | .name
  ')
}

get_namespaces() {
  # Ensure the pv_list is not empty
  if [ -z "$pv_list" ]; then
    echo "No PVs found to process."
    return
  fi

  # Convert pv_list into a jq array format
  jq_pv_list=$(echo "$pv_list" | jq -R -s -c 'split("\n") | map(select(. != ""))')

  # Use jq to filter and find namespaces
  namespaces=$(kubectl get pv -A -o json | jq -r --argjson pv_list "$jq_pv_list" '
    .items[] | select(.metadata.name as $name | $pv_list | index($name)) | .spec.claimRef.namespace' | sort | uniq)
}

# Function to login to ArgoCD if not already logged in
argocd_login() {
  if argocd account get-user-info | grep -q 'Logged In: false'; then
    echo "Logging into ArgoCD..."
    argocd login "$ARGOCD_SERVER" --username "$ARGOCD_USERNAME" --password "$ARGOCD_PASSWORD" --grpc-web
  fi
}

# Function to create or update an ArgoCD sync window
create_sync_window() {
  echo "Checking for existing ArgoCD sync window for affected namespaces: $namespaces"

  # Set the schedule, duration, and timezone parameters
  schedule="* * * * *"
  duration="24h"
  timeZone="America/Chicago"

  # Convert namespaces to a comma-separated list for the update command
  affected_namespaces=$(echo "$namespaces" | tr '\n' ',' | sed 's/,$//')

  # Check for existing sync windows that match the schedule, duration, and timezone
  existing_window=$(argocd proj windows list default -o json | jq -r --arg schedule "$schedule" --arg duration "$duration" --arg timeZone "$timeZone" '
    .[] | select(.schedule == $schedule and .duration == $duration and .timeZone == $timeZone)')

  if [ -n "$existing_window" ]; then
    # Extract existing namespaces and the window ID using the index of the window
    existing_namespaces=$(echo "$existing_window" | jq -r '.namespaces | join(",")')
    window_index=$(argocd proj windows list default -o json | jq -r --arg schedule "$schedule" --arg duration "$duration" --arg timeZone "$timeZone" '
      to_entries[] | select(.value.schedule == $schedule and .value.duration == $duration and .value.timeZone == $timeZone) | .key')

    # Combine existing namespaces with affected namespaces, ensuring no duplicates
    updated_namespaces=$(echo "$existing_namespaces,$affected_namespaces" | tr ',' '\n' | sort | uniq | tr '\n' ',' | sed 's/,$//')

    # Update the existing sync window with the combined namespaces
    echo "Updating existing sync window ID $window_index with namespaces: $updated_namespaces"
    argocd proj windows update default "$window_index" --namespaces "$updated_namespaces" --time-zone "$timeZone"
  else
    # Create a new sync window if no matching window exists
    echo "Creating a new sync window with namespaces: $affected_namespaces"
    argocd proj windows add default -k deny --schedule "$schedule" --duration "$duration" --namespaces "$affected_namespaces" --manual-sync --time-zone "$timeZone"
  fi
}

# Function to remove the ArgoCD sync window
remove_sync_window() {
  echo "Removing ArgoCD sync window"
  argocd proj windows delete default 0
}

# Function to get deployments and statefulsets using the specified PVCs
get_deployments_and_statefulsets() {
  deployments=()
  statefulsets=()

  for pvc in "${pvc_list[@]}"; do
    namespace=$(echo "$pvc" | cut -d/ -f1)
    claim=$(echo "$pvc" | cut -d/ -f2)

    echo "Searching for resources using PVC: $claim in namespace: $namespace"

    # Find the deployments that reference the PVC
    found_deployments=$(kubectl get deployments -n "$namespace" -o json | jq -r --arg claim "$claim" '
      .items[] | select(.spec.template.spec.volumes[]?.persistentVolumeClaim.claimName == $claim) | .metadata.name')
    
    # Add each found deployment to the deployments array
    while IFS= read -r deployment; do
      deployments+=("$namespace/$deployment")
    done <<< "$found_deployments"

    # Find the statefulsets that reference the PVC
    found_statefulsets=$(kubectl get statefulsets -n "$namespace" -o json | jq -r --arg claim "$claim" '
      .items[] | select(.spec.template.spec.volumes[]?.persistentVolumeClaim.claimName == $claim) | .metadata.name')
    
    # Add each found statefulset to the statefulsets array
    while IFS= read -r statefulset; do
      statefulsets+=("$namespace/$statefulset")
    done <<< "$found_statefulsets"
  done

  echo "Deployments using PVCs: ${deployments[*]}"
  echo "Statefulsets using PVCs: ${statefulsets[*]}"
}

# Function to scale down deployments and statefulsets
scale_down_replicas() {
  echo "Scaling down deployments and statefulsets..."

  # Scale down deployments
  for deployment in "${deployments[@]}"; do
    namespace=$(echo "$deployment" | cut -d/ -f1)
    name=$(echo "$deployment" | cut -d/ -f2)
    echo "Scaling down deployment: $name in namespace: $namespace"
    kubectl label deployment "$name" --namespace="$namespace" nas-dependent=scaled --overwrite
    kubectl scale deployment "$name" --namespace="$namespace" --replicas=0
  done

  # Scale down statefulsets
  for statefulset in "${statefulsets[@]}"; do
    namespace=$(echo "$statefulset" | cut -d/ -f1)
    name=$(echo "$statefulset" | cut -d/ -f2)
    echo "Scaling down statefulset: $name in namespace: $namespace"
    kubectl label statefulset "$name" --namespace="$namespace" nas-dependent=scaled --overwrite
    kubectl scale statefulset "$name" --namespace="$namespace" --replicas=0
  done

  echo "Scaling down complete."
}

# Function to scale down specific workloads
scale_down() {
  echo "Scaling down deployments and statefulsets dependent on NAS..."

  check_nas_address
  get_pv_list_dependent_on_nas
  get_namespaces
  argocd_login
  create_sync_window
  get_deployments_and_statefulsets
  scale_down_replicas
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
