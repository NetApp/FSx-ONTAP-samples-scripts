# :warning: **NOTICE:**

This repository is no longer being maintained. However, all the code found here has been relocated to a new NetApp managed GitHub repository found here [https://github.com/NetApp/FSx-ONTAP-utils/tree/main/EKS/PV-Migrate-with-Trident-Protect](https://github.com/NetApp/FSx-ONTAP-utils/tree/main/EKS/PV-Migrate-with-Trident-Protect) where it is continually updated. Please refer to that repository for the latest updates.

# Migrate Kubernetes PVs with Trident Protect

This is a sample for setting up your Kubernetes application to be migrated from one storage class to another using Trident Protect.

## Prerequisites:
The following items should already be deployed before installing Trident Protect.
- An AWS EKS cluster. If you don't already have one, refer to the [FSx for NetApp ONTAP as persistent storage](https://github.com/NetApp/FSx-ONTAP-samples-scripts/tree/main/EKS/FSxN-as-PVC-for-EKS)
GitHub repo for an example of how to not only deploy an EKS cluster, but also deploy an FSx for ONTAP file system with
Trident installed with its backend and storage classes configured. If you follow it, it will provide the rest of the prerequisites listed below.
- Trident installed. Please refer to this [Trident installation documentation](https://docs.netapp.com/us-en/trident/trident-get-started/kubernetes-deploy-helm.html) for the easiest way to do that.
- Configure Trident Backend. Refer to the NetApp Trident documentation for guidance on creating [TridentBackendConfig resources](https://docs.netapp.com/us-en/trident/trident-use/backend-kubectl.html).
- Install the Trident CSI drivers for SAN and NAS type storage. Refer to NetApp documentation for [installation instructions](https://docs.netapp.com/us-en/trident/trident-use/trident-fsx-storage-backend.html).
- Configure a StorageClass Trident for SAN and/or NAS type storage. Refer to NetApp documentation for [instructions](https://docs.netapp.com/us-en/trident/trident-use/trident-fsx-storageclass-pvc.html).
- kubectl installed - Refer to [this documentation](https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/) on how to install it.
- helm installed - Refer to [this documentation](https://helm.sh/docs/intro/install/) on how to install it.

## Preparation
The following are the steps required before you can use Trident Protect to backup or migrate your EKS application.

1. [Configure Trident Backend](#1-make-sure-trident-backend-is-configured-correctly)
1. [Configure Storage Classes for Trident storage types](#2-make-sure-trident-csi-drivers-for-nas-and-san-are-installed)
1. [Install the Kubernetes external snapshotter](#3-install-the-kubernetes-external-snapshotter)
1. [Create VolumeStorageClass for Storage Provider](#4-create-volumestorageclasses-for-your-storage-provider)
1. [Install Trident Protect](#5-install-trident-protect)
1. [Create S3 Bucket](#6-create-private-s3-bucket-for-backup-data-and-metadata)
1. [Create Kubernetes secret for S3 bucket](#7-create-a-kubernetes-secret-for-the-s3-bucket)

### 1. Make sure Trident Backend is configured correctly 

Depending on whether you are using block (SAN), or NAS (NFS), or both, will dictate which TridentBackendConfig you need configured.

#### SAN Backend
Run the following command to confirm that the TridentBackendConfig for ontap-san exists and is configured correctly:
```bash
kubectl get tbc -n trident -o jsonpath='{.items[?(@.spec.storageDriverName=="ontap-san")].metadata.name}'
```

### NAS Backend
Run the following command to confirm that the TridentBackendConfig for ontap-nas exists and is configured correctly:
```bash
kubectl get tbc -n trident -o jsonpath='{.items[?(@.spec.storageDriverName=="ontap-nas")].metadata.name}'
```

If no matching TridentBackendConfig resources are found, you will need to create the ones you need. Refer to the prerequisites section above for more information on how to do that.

### 2. Make Sure the required Trident Storage Classes are installed
Depending on whether you are using block (SAN), or NAS (NFS), or both, will dictate which Storage Classes you need to have configured.

#### SAN StorageClass
Run the following command to check that the storage class in Kubernetes that use 'ontap-san' as their backend type has been installed. It outputs the name of any matching StorageClass:
```bash
kubectl get storageclass -o jsonpath='{.items[?(@.parameters.backendType=="ontap-san")].metadata.name}'
```

#### NAS Driver
Run the following command to check that the storage class in Kubernetes that use 'ontap-nas' as their backend type has been installed. It outputs the name of any matching StorageClass:
```bash
kubectl get storageclass -o jsonpath='{.items[?(@.parameters.backendType=="ontap-nas")].metadata.name}'
```

If one, or both, are not found, you will need to create them. Refer to the prerequisites section above for more information on how to do that.

### 3. Install the Kubernetes External Snapshotter
Trident Protect depends on the Snapshotter CRDs and controller. Please run the following commands to install the Kubernetes External Snapshotter.
For more information, please consult the official [external-snapshotter documentation](https://github.com/kubernetes-csi/external-snapshotter).

```bash
git clone https://github.com/kubernetes-csi/external-snapshotter
cd external-snapshotter/
kubectl kustomize client/config/crd | kubectl create -f -
kubectl -n kube-system kustomize deploy/kubernetes/snapshot-controller | kubectl create -f -
kubectl kustomize deploy/kubernetes/csi-snapshotter | kubectl create -f -
cd ..
```

### 4. Create VolumeSnapshotClasses for your storage provider.
Trident Protect requires a VolumeSnapshotClass to be created for the storage CSI driver you are using. You can use the following command to see if you already have one defined:
```
kubectl get VolumeSnapshotClass
```
If you don't have one defined, you'll need to create one. Here is an example of a yaml file that defines a VolumeSnapshotClass for Trident CSI driver:
```
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshotClass
metadata:
  name: trident-csi-snapclass
  annotations:
    snapshot.storage.kubernetes.io/is-default-class: "true"
driver: csi.trident.netapp.io
deletionPolicy: Delete
```

Here is an example of a yaml file that defines a VolumeSnapshotClass for EBS CSI driver:
```
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshotClass
metadata:
  name: ebs-csi-snapclass
driver: ebs.csi.aws.com
deletionPolicy: Delete
```

After creating the yaml file with the VolumeSnapshotClass for your CSI driver, run the following command to create the VolumeSnapshotClass:

```bash
kubectl apply -f <VolumeSnapshotClass.yaml>
```

### 5. Install Trident Protect
Execute the following commands to install Trident Protect. For more information please consult official [Trident Protect documentation](https://docs.netapp.com/us-en/trident/trident-protect/trident-protect-installation.html).

```markdown
helm repo add netapp-trident-protect https://netapp.github.io/trident-protect-helm-chart
helm install trident-protect-crds netapp-trident-protect/trident-protect-crds --create-namespace --namespace trident-protect
helm install trident-protect netapp-trident-protect/trident-protect --set autoSupport.enabled=false --set clusterName=trident-protect-cluster --namespace trident-protect
```
Note that the above commands should install the latest version. If you want to install a specific version add the --version option and provide the version you want to use. Please use version `100.2410.1` or later.

### 6. Create Private S3 Bucket for Backup Data and Metadata

If you don't already have an S3 bucket, you can create one with the following command:

```markdown
aws s3 mb s3://<bucket_name> --region <aws_region>
```

Replace:
- `<bucket_name>` with the name you want to assign to the bucket. Note it must be a unique name.
- `<aws_region>` the AWS region you want the bucket to reside.

### 7. Create a Kubernetes secret for the S3 bucket
If required, create a service account within AWS IAM that has rights to read and write to the S3 bucket created above. Then, create an access key.
Once you have the Access Key Id and Secret Access Key, create a Kubernetes secret with the following command:

```markdown
kubectl create secret generic -n trident-protect s3 --from-literal=accessKeyID=<AccessKeyID> --from-literal=secretAccessKey=<secretAccessKey>
```

Replace:
- `<AccessKeyID>` with the Access Key ID.
- `<secretAccessKey>` with the Secret Access Key.

## Configure Trident Protect to backup your application
Preform these steps to configure Trident Protect to backup your application:
- [Define Trident Vault](#define-a-trident-vault-to-store-the-backup)
- [Create Trident Application](#create-a-trident-application)
- [Run Backup](#run-backup-for-application)
- [Check Backup Status](#check-backup-status)

### Define a Trident Vault to store the backup

First create a file name `trident-vault.yaml` with the following contents:

```markdown
apiVersion: protect.trident.netapp.io/v1
kind: AppVault
metadata:
  name: <APP VAULT NAME>
  namespace: trident-protect
spec:
  providerType: AWS
  providerConfig:
    s3:
      bucketName: <APP VAULT BUCKET NAME>
      endpoint: <S3 ENDPOINT>
  providerCredentials:
    accessKeyID:
      valueFromSecret:
        key: accessKeyID
        name: s3
    secretAccessKey:
      valueFromSecret:
        key: secretAccessKey
        name: s3
```

Replace:
- `<APP VAULT NAME>` with the name you want assigned to the Trident Vault.
- `<APP VAULT BUCKET NAME>` with the name of the bucket you created in step 6 above.
- `<S3 ENDPOINT>` the hostname of the S3 endpoint. For example: `s3.us-west-2.amazonaws.com`.

Now run the following command to create the Trident Vault:

```markdown
kubectl apply -f trident-vault.yaml
```

### Create a Trident Application
You create a Trident application with the specification of your application in order to back it up. You do that by creating a file named `trident-application.yaml` with the following contents:

```markdown
apiVersion: protect.trident.netapp.io/v1
kind: Application
metadata:
  name: <APP NAME>
  namespace: <APP NAMESPACE>
spec:
  includedNamespaces:
    - namespace:  <APP NAMESPACE>
```

Replace:
- `<APP NAME>` with the name you want to assign to the Trident Application
- `<APP NAMESPACE>` with the namespace where the application that you want to backup resides.

Run the following command to create the Trident Application:

```markdown
kubectl apply -f trident-application.yaml
```

### Run Backup for Application
To perform an on-demand backup of the application, first create a backup configuration file named `trident-backup.yaml` with the following contents:

```markdown
apiVersion: protect.trident.netapp.io/v1
kind: Backup
metadata:
  namespace: <APP NAMESPACE>
  name: <APP BACKUP NAME>
spec:
  applicationRef: <APP NAME> 
  appVaultRef: <APP VAULT NAME>
```

Replace:
- `<APP NAMESPACE>` with the namespace where the application resides.
- `<APP BACKUP NAME>` with the name you want assigned to the backup. This has to be different from any other backup ever run.
- `<APP NAME>` with the name of the application defined in the step above.
- `<APP VAULT NAME>` with the name of the Trident Vault created in the step above.

Now run the following command to start the backup:

```markdown
kubectl apply -f trident-backup.yaml
```

### Check Backup Status
To check the status of the backup run the following command:

```markdown
kubectl get backup -n <APP NAMESPACE> <APP BACKUP NAME>
```

- If status is `Completed` Backup completed successfully .
- If status is `Running` run the command again in a few minutes to check status.
- If status is `Failed` the error message will give you a clue as to what went wrong. If you need more information, try using `kubectl describe` instead of `kubectl get` to get more information.

## Perform the migration
To restore the backup to a different storage class, you first need to create a restore configuration file named `trident-restore-diff-sc.yaml` with the following contents:

```markdown
apiVersion: protect.trident.netapp.io/v1
kind: BackupRestore
metadata:
  name: <APP RESTORE NAME>
  namespace: <DESTINATION NAMESPACE>
spec:
  appArchivePath: <APP ARCHIVE PATH>
  appVaultRef: <APP VAULT NAME>
  namespaceMapping: 
    - source: <SOURCE NAMESPACE>
      destination: <DESTINATION NAMESPACE>
  storageClassMapping:
    - source: <SOURCE STORAGE CLASS>
      destination: <DESTINATION STORAGE CLASS>
```

Replace:
- `<APP RESTORE NAME>` with the name you want to assign the restore configuration.
- `<DESTINATION NAMESPACE>` with the namespace where you want to restore the application.
- `<APP VAULT NAME>` with the name of the Trident Vault used when creating the backup.
- `<SOURCE NAMESPACE>` with the namespace where the application was backed up from.
- `<DESTINATION NAMESPACE>` with the namespace where you want the application to be restored to.
- `<SOURCE STORAGE CLASS>` with the storage class that the application was backed up from.
- `<DESTINATION STORAGE CLASS>` with the storage class that you want the application to be restored to.
- `<APP ARCHIVE PATH>` with the path to the backup archive. You can get this by running the following command:

```markdown
kubectl get backup -n <APP NAMESPACE> <APP BACKUP NAME> -o jsonpath='{.status.appArchivePath}'
```

Once the yaml file has been created, run the following command to start the restore:

```markdown
kubectl apply -f trident-restore-diff-ns.yaml
```

You can check the status of the restore by running the following command:

```markdown
kubectl get backuprestore -n <DESTINATION NAMESPACE> <APP RESTORE NAME>
```

## Final Notes
There are a lot of other features and options available with Trident Protect that are not covered here, for example:
- Creating zero space snapshots of your application.
- Scheduling backups.
- Replicating backups to another FSxN file system with SnapMirror.

For more information please refer to the official [Trident Protect documentation](https://docs.netapp.com/us-en/trident/trident-protect/trident-protect-installation.html).

## Author Information

This repository is maintained by the contributors listed on [GitHub](https://github.com/NetApp/FSx-ONTAP-samples-scripts/graphs/contributors).

## License

Licensed under the Apache License, Version 2.0 (the "License").

You may obtain a copy of the License at [apache.org/licenses/LICENSE-2.0](http://www.apache.org/licenses/LICENSE-2.0).

Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an _"AS IS"_ basis, without WARRANTIES or conditions of any kind, either express or implied.

See the License for the specific language governing permissions and limitations under the License.

© 2025 NetApp, Inc. All Rights Reserved.
