# Trident Protect Migrate PVC Storage Class

A simple sample for setting up your application to be backed up by Trident Protect with an option for in place migration from EBS to FSx for ONTAP.

## Prerequisites:
The following items should be already be deployed before install Trident Protect.
- EKS cluster. If you don't already have one, refer to the [FSx for NetApp ONTAP as persistent storage](https://github.com/NetApp/FSx-ONTAP-samples-scripts/tree/main/EKS/FSxN-as-PVC-for-EKS) GitHub repo for an example of how to not only deploy an EKS cluster, but also deploy an FSx for ONTAP file system with Tident installed and its backend and storage classes configured.
- Trident installed. Please refer to this [Trident installation documentation](https://docs.netapp.com/us-en/trident/trident-get-started/kubernetes-deploy-helm.html) for the easiest way to do that.
- Configure Trident Backend. Refer to the NetApp Trident documentation for guidance on creating [TridentBackendConfig resources](https://docs.netapp.com/us-en/trident/trident-use/backend-kubectl.html)
- Install the Trident CSI drivers for SAN and NAS type storage. Refer to NetApp documentation for [installation instructions](https://docs.netapp.com/us-en/trident/trident-use/ontap-san-examples)
This guide provides steps to set up and configure a StorageClass using ONTAP NAS backends with Trident.
- kubectl installed - Refer to [this documentation](https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/) on how to install it.
- helm installed - Refer to [this documentation](https://helm.sh/docs/intro/install/) on how to install it.

## Preperation
The following are the steps required before you can use Trident Protect to backup your EKS application.

1. [Install Trident Protect](#1-install-trident-protect)
2. [Configure Trident Backend](#2-make-sure-trident-backend-is-configured-correctly)
3. [Install Trident CSI Drivers](#3-make-sure-trident-csi-drivers-for-nas-and-san-are-installed)
4. [Create S3 Bucket](#4-create-private-s3-bucket-for-backup-data-and-metadata)

### 1. Install Trident Protect
Execute the following commands to install Trident Protect. For more info please consult official [Trident Protect documentation](https://docs.netapp.com/us-en/trident/trident-protect/trident-protect-installation.html).

```markdown
helm repo add netapp-trident-protect https://netapp.github.io/trident-protect-helm-chart
helm install trident-protect-crds netapp-trident-protect/trident-protect-crds --version 100.2410.1 --create-namespace --namespace trident-protect
helm install trident-protect netapp-trident-protect/trident-protect --set autoSupport.enabled=false --set clusterName=<name_of_cluster> --version 100.2410.1 --create-namespace --namespace trident-protect
```

### 2. Make sure Trident Backend is configured correctly 

Run the follwing kubectl commands to check if TridentBackendConfig for ontap-san and ontap-nas exists and configured correctly, It outputs the name of any matching TridentBackendConfig:

#### SAN Backend
```bash
kubectl get tbc -n trident -o jsonpath='{.items[?(@.spec.storageDriverName=="ontap-san")].metadata.name}'
```

### NAS Backend
```bash
kubectl get tbc -n trident -o jsonpath='{.items[?(@.spec.storageDriverName=="ontap-san")].metadata.name}'
```

If no matching TridentBackendConfig resources are found, you may need to create one. Refer to the prerequisites section above for more information on how to do that.
### 3. Make Sure Trident CSI Drivers for NAS and SAN are Installed
Run the follwing kubectl commands to check that a storageclass exist for both SAN and NAS type storage.

#### SAN Driver
Checks for StorageClasses in Kubernetes that use 'ontap-san' as their backend type. It outputs the name of any matching StorageClass:
```bash
kubectl get storageclass -o jsonpath='{.items[?(@.parameters.backendType=="ontap-san")].metadata.name}'
```

#### NAS Driver
Checks for StorageClasses in Kubernetes that use 'ontap-nas' as their backend type. It outputs the name of any matching StorageClass:
```bash
kubectl get storageclass -o jsonpath='{.items[?(@.parameters.backendType=="ontap-nas")].metadata.name}'
```

If one or both are not found, you may need to create them. Refer to the prerequisites section above for more information on how to do that.


### 4. Create Private S3 Bucket for Backup Data and Metadata

```markdown
aws s3 mb s3://<bucket_name> --region <aws_region>
```

Replace:
- `<bucket_name>` with the name you want to assign to the bucket. Note it must be a unique name.
- `<aws_region>` the AWS region you want the bucket to reside.

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
      endpoint: <AWS REGION>
  providerCredentials:
    accessKeyID:
      valueFromSecret:
        key: <accessKeyID>
        name: s3
    secretAccessKey:
      valueFromSecret:
        key: <secretAccessKey>
        name: s3
```

Replace:
- `<APP VAULT NAME>` with the name you want assigned to the Trident Vault
- `<APP VAULT BUCKET NAME>` with the name of the bucket you created in step 5 above.
- `<AWS_REGION>` with the AWS region the s3 bucket was created in.
- `<accessKeyID>` with the access key ID that has access to the S3 bucket.
- `<secretAccessKey>` with the secret that is associated with the access key ID.

Now run the following command to create the Trident Vault:

```markdown
kubectl apply -f trident-vault.yaml
```

SECURITY NOTE:

If you want to avoid storing AWS credentials explicitly in Kubernetes secrets, a more secure approach would be to use IAM roles for service accounts (IRSA):
 - Create an IAM policy with minimal S3 access permissions for the specific bucket.
 - Create an IAM role and attach the policy to it.
 - Configure your EKS cluster to use IAM roles for service accounts (IRSA).
 - Create a Kubernetes service account in the trident-protect namespace and associate it with the IAM role

### Create a Trident Application
Create a Trident application to backup your application by first creating a file named `trident-application.yaml` with the following contents:

```markdown
apiVersion: protect.trident.netapp.io/v1
kind: Application
metadata:
  name: <APP NAME>
  namespace: trident-protect
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
To backup the application first create a backup configuration file named `trident-backup.yaml` with the following contents:

```markdown
apiVersion: protect.trident.netapp.io/v1
kind: Backup
metadata:
  namespace: trident-protect
  name: <APP BACKUP NAME>
spec:
  applicationRef: <APP NAME> 
  appVaultRef: <APP VAULT NAME>
  dataMover: Kopia
```

Replace:
- `<APP BACKUP NAME>` with the name you want assigned to the backup.
- `<APP NAME>` with the name of the application defined in the step above.
- `<APP VAULT NAME>` with the name of the Trident Vault created in the step above.

Now run the following command to start the backup:

```markdown
kubectl apply -f trident-backup.yaml
```

### Check Backup Status
To check the status of the backup run the following command:

```markdown
kubectl get snapshot -n trident-protect <APP BACKUP NAME> -o jsonpath='{.status.state}'
```

- If status is `Completed` Backup completed successfully 
- If status is `Running` run the command again in a few minutes to check status
- If status is `Failed` check the error message:

```markdown
kubectl get snapshot -n trident-protect <APP BACKUP NAME> -o jsonpath='{.status.error}'
```

## Perform an in place restore with volume migration (from gp3 to FSxN/trident-csi)
Before running the Restore command get appArchivePath by running:

```markdown
kubectl get backup -n trident-protect <APP BACKUP NAME> -o jsonpath='{.status.appArchivePath}'
```

Run the restore by first creating an in place restore configuration file named `backupinplacerestore.yaml` with the following contents:

```markdown
apiVersion: protect.trident.netapp.io/v1
kind: BackupInplaceRestore
metadata:
  name:  <APP BACKUP RESTORE NAME>
  namespace: trident-protect
spec:
  appArchivePath: <BACKUP PATH>
  appVaultRef: <APP VAULT NAME>
  storageClassMapping: [{"source": "gp3", "destination": "trident-csi-nas"}]
```

Replace:
- `<APP BACKUP RESTORE NAME>` with the name you want to assign the restore configuration
- `<BACKUP PATH>` with the appArchivePath obtained from the step above.
- `<APP VAULT NAME>` with the name of the backup configuration used to create the backup you want to restore from.

Run the following command to keep the application in place while migrating application's PVC from gp3 to trident-csi-nas

```markdown
kubectl apply -f backupinplacerestore.yaml
```

Verify application restore was successful and check PVC storage class:

```markdown
kubectl get <APP BACKUP RESTORE NAME> -n trident-protect -o jsonpath='{.status.state}'
kubectl get pvc <PVC NAME> -n <NAMESPACE> -o jsonpath='{.spec.storageClassName}'
```
