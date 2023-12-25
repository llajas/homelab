# Accessing CIFS/Windows Shares

This document provides a guide on how to use CIFS/SMB file systems in a Kubernetes cluster using the CSI Driver. It covers the deployment of the CSI Driver as a DaemonSet, creating new mounts, and accessing existing shares.

## SMB Configuration

While this article won't cover how to setup SMB, it does cover some items that are worth checking to be sure that things are working properly

- Keep the following in mind for your setup:

    - Ensure that the 'File and Printer Sharing (SMB-In)' rule on your server device allows access from your nodes if they are on another network/VLAN.
    - Additionally, be sure that your router has a rule in place to allow access to your SMB server via port '445'.
    - Always use a separate account for accessing your shares.

## Accessing Shares

The `csi-smb-driver` is installed using a helm chart placed in the `/csi-driver-smb/csi-driver-smb/` location. It is sourced from ['kubernetes-csi/csi-driver-smb'](https://github.com/kubernetes-csi/csi-driver-smb)

## Existing Shares Versus New Shares

When creating a new PVC using the SMB CSI Driver without any existing backing PV, the driver will create a new PV that itself creates a _new_ folder at the share location that will effectively be the PVC for the pod. This allows SMB backing for new PVC's, but doesn't address use cases when attempting to access existing data using the driver. This is feasible by creating a new PV that points towards the share, then using it to back the PVC for the new pod. See below for an example of this.

!!! example

    ```yaml
    apiVersion: v1
    kind: PersistentVolume
    metadata:
      annotations:
        pv.kubernetes.io/provisioned-by: smb.csi.k8s.io
      name: pv-smb
    spec:
      capacity:
        storage: 100Gi
      accessModes:
        - ReadWriteMany
      persistentVolumeReclaimPolicy: Retain
      storageClassName: smb
      mountOptions:
        - dir_mode=0777
        - file_mode=0777
        - uid=1001
        - gid=1001
        - noperm
        - mfsymlinks
        - cache=strict
        - noserverino  # required to prevent data corruption
      csi:
        driver: smb.csi.k8s.io
        # volumeHandle format: {smb-server-address}#{sub-dir-name}#{share-name}
        # make sure this value is unique for every share in the cluster
        volumeHandle: smb-server.default.svc.cluster.local/share##
        volumeAttributes:
          source: //smb-server.default.svc.cluster.local/share
        nodeStageSecretRef:
          name: smbcreds
          namespace: default
    ```
