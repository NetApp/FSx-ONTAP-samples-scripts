# FSx for NetApp ONTAP as persistent storage

## Introduction

In this sample you'll find the instructions, and the code necessary, to deploy an AWS EKS
cluster with an Amazon FSx for NetApp ONTAP File System (FSxN) to provide persistent storage
for it. It will leverage NetApp's Astra Trident to provide the interface between EKS to FSxN.

## Prerequisites

A Linux based EC2 instance with the following installed:
- HashiCorp's Terraform
- AWS CLI, authenticated with an account that has privileges necessary to:
	- Deploy an EKS cluster
	- Deploy an FSx for Netapp ONTAP File System
	- Create security groups
	- Create a VPC and subnets
	- Create a NAT Gateway
	- Create an EC2 instance

## Installation Overview
The overall process is as follows:
- Ensure the prerequisites have been installed and configured.
- Clone this repo from GitHub.
- Make changes to the variables.tf file.
- Run 'terraform init' to initialize the terraform environment.
- Run 'terraform apply -auto-approve' to:
  - Create a new VPC with public and private subnets.
  - Deploy a FSx for NetApp ONTAP File System.
  - Deploy an EKS cluster.
  - Deploy an EC2 Linux based instance.
- SSH to the Linux based instance to complete the setup:
  - Install the FSx for NetApp ONTAP Trident CSI driver.
  - Configure the Trident CSI driver.
  - Create a Kubernetes storage class.
- Deploy a sample application to test the storage with.

## Detailed Instructions
## Clone the "NetApp/FSx-ONTAP-samples-scripts" repo from GitHub
```bash
git clone https://github.com/NetApp/FSx-ONTAP-samples-scripts.git
cd FSx-ONTAP-samples-scripts/Solutions/FSxN-as-PVC-for-EKS/terraform
```
### Make any desired changes to the variables.tf file.
Variables that can be changed include:
- aws_region - The AWS region where you want to deploy the resources.
- fsx_name - The name you want applied to the FSx for NetApp ONTAP File System.
- fsx_password_secret_name - The name of the AWS SecretsManager secret that will hold the FSxN password.
Note that a random password will be generated and stored in the secret.
- fsx_throughput_capacity - The throughput capacity of the FSx for NetApp ONTAP File System.
Read the "description" of the variable to see valid values.
- fsx_storage_capacity - The storage capacity of the FSx for NetApp ONTAP File System.
Read the "description" of the variable to see the valid range.
- key_pair_name - The name of the EC2 key pair to use to access the jump server.
- secure_ips - The IP address ranges to allow SSH access to the jump server. The default is wide open.

Note that you must set the key_pair_name, otherwise the deployment will fail.

### Initialize the Terraform environment
Run 'terraform init' to initialize the terraform environment.
```bash
terraform init
```

### Deploy the resources
Run 'terraform apply -auto-approve' to deploy:
```bash
terraform apply -auto-approve
```
There will be a lot of output, and it will take 20 to 40 minutes to complete. Once done,
the following is an example of last part of the output of a successful deployment:
```bash
Outputs:

eks-cluster-name = "fsx-eks-Do8AOE8U"
eks-jump-server = "Instance ID: i-088a83a6deeabc18b, Public IP: 54.184.236.183"
fsx-management-ip = "198.19.255.11"
fsx-password-secret-name = "fsx-password"
fsx-svm-data-LIF = "198.19.255.197"
fsx-svm-name = "ekssvm"
region = "us-west-2"
vpc-id = "vpc-0a915e6ad76daf5d9"
zz_update_kubeconfig_command = "aws eks update-kubeconfig --name fsx-eks-Do8AOE8U --region us-west-2"
```
You will use the values in the commands below, so probably a good idea to copy the output somewhere
so you can easily reference it later.

### SSH to the jump server to complete the setup
Use the following command to 'ssh' to the jump start server:
```bash
ssh -i <path_to_key_pair> ubuntu@<jump_server_public_ip>
```
Where:
- <path_to_key_pair> is the path to where you have stored the key_pair that you
referenced in the variables.tf file.
- <jump_server_public_ip> is the IP address of the jump start server that was displayed
in the output from the `terraform apply` command.

### Configure the 'aws' CLI
Run the following command to configure the 'aws' command:
```bash
aws configure
```
It will prompt you for an access key and secret. See above for the required permissions.
It will also prompt you for a default region and output format. I would recommend setting
the region to the same region you set in the variables.tf file. It doesn't matter what
you set the default output format to.

### Allow access to the EKS cluster for your user id
AWS's EKS clusters have a secondary form for permissions. As such, you have to add an "access-entry"
to your EKS configuration and associate it with Cluster Admin policy to be able to view and
configure the EKS cluster. The first step to do this is to find out your IAM ARN.
You can do that via this command:
```bash
aws iam get-user --output=text --query User.Arn
```
Once you have your ARN, add it as a access-entry with this command:
```bash
aws eks create-access-entry --cluster-name <EKS_CLUSTER_NAME> --principal-arn <USER_ARN>
```
Of course, replace <EKS_CLUSTER_NAME> with the name of your EKS cluster. You can get that from the
output from the `terraform apply` command. And replace <USER_ARN> with
IAM ARN obtained from the command above.

The final step is to associate the Cluster Admin policy to that access-entry with this command:
```bash
aws eks associate-access-policy --cluster-name <EKS_CLUSTER_NAME> --principal-arn <USER_ARN> --policy-arn arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy --access-scope type=cluster
```
Like above, replace <EKS_CLUSTER_NAME> with the name of your EKS cluster. And replace <USER_ARN> with
IAM ARN obtained from the command above. Leave the rest of the arguments as is.

### Configure kubectl to use the EKS cluster
You'll notice from the output of the `terraform apply` command a "zz_update_kubeconfig_command"
variable. The output of that variable shows the command to run to configure kubectl to use
the AWS EKS cluster.

Here's an example based on the "terraform apply" output shown above:
```bash
aws eks update-kubeconfig --name fsx-eks-Do8AOE8U --region us-west-2
```
Run the following command to confirm you can communicate with the EKS cluster:
```bash
kubectl get nodes
```
You should get output like this:
```bash
NAME                                       STATUS   ROLES    AGE   VERSION
ip-10-0-1-210.us-west-2.compute.internal   Ready    <none>   57m   v1.29.3-eks-ae9a62a
ip-10-0-2-243.us-west-2.compute.internal   Ready    <none>   57m   v1.29.3-eks-ae9a62a
```

### Install the Kubernetes Snapshot CRDs and Snapshot Controller:
Run these commands to install the CRDs:
```bash
git clone https://github.com/kubernetes-csi/external-snapshotter 
cd external-snapshotter/ 
kubectl kustomize client/config/crd | kubectl create -f - 
kubectl -n kube-system kustomize deploy/kubernetes/snapshot-controller | kubectl create -f - 
kubectl kustomize deploy/kubernetes/csi-snapshotter | kubectl create -f - 
cd ..
```

### Install the FSx for NetApp ONTAP Trident CSI driver
Note that Trident CSI driver is constantly being updated so I would recommend going to this website
to see what the latest version is: [Releases Netapp/trident](https://github.com/NetApp/trident/releases/).
The latest version will always be at the top of that page. The below example is downloading the
latest version as of June 11th, 2024.
```bash
wget https://github.com/NetApp/trident/releases/download/v24.02.0/trident-installer-24.02.0.tar.gz
tar -xf trident-installer-24.02.0.tar.gz
helm install trident -n trident --create-namespace  trident-installer/helm/trident-operator-*.tgz
```

### Confirm Trident is up and running
Confirm that the Trident operator is up and running by running this command:
```bash
kubectl get pods -n trident
```
The output should look something like this:
```bash
NAME                                  READY   STATUS    RESTARTS   AGE
trident-controller-569f47fc59-hx2vn   6/6     Running   0          20h
trident-node-linux-pgcw9              2/2     Running   0          20h
trident-node-linux-zr8n7              2/2     Running   0          20h
trident-operator-67d6fd899b-jrnt2     1/1     Running   0          20h
```
Note that it might take a minute before all four of those pods show up.

### Configure the Trident CSI backend to use FSx for NetApp ONTAP
For the example below we are going to set up an iSCSI LUN for a MySQL
database. Because of that, we are going to setup a Trident backend
to use the `ontap-san` driver. You can read more about the different driver types in the
[Astra Trident documentation](https://docs.netapp.com/us-en/trident/trident-use/trident-fsx.html#fsx-for-ontap-driver-details) documentation.

As you go through the steps below, you will noticed that all the files have "-san" in the
name. If you want to see an example of using NFS instead of iSCSI, there are equivalent
files that have "-nas" in the name that leverage a NFS volume instead of an iSCSI LUN.
You can even create two mysql databases, one using iSCSI and the other using NFS.

The first step is to define a backend provider and in the process give it the information
it needs to make changes (e.g. create volumes, and LUNs) to the FSxN file system.

In the command below you're going to need the FSxN Management IP, the data LIF IP (only
needed if you are going to use NFS storage), the AWS Secrets Manager
secret that is holding the FSxN password, and the name of the SVM that was created.
All of that information can be obtained from the output
from the `terraform apply` command. If you have lost that output, you can always log back
into the server where you ran `terraform apply` and simply run it again. It should
state that there aren't any changes to be made and simply show the output again.

Note that a copy of this repo has been put into ubuntu's home directory on the jumpserver for you.
Don't be confused with this copy and the one you used to create the
environment with earlier. This copy will not have the terraform state information,
nor your changes to the variables.tf file, but it does have other files you'll need
to complete the setup.

Execute the following commands to configure Trident to use the `ontap-san` driver.
```bash
cd ~/FSx-ONTAP-samples-scripts/Solutions/FSxN-as-PVC-for-EKS
mkdir temp
export FSX_MANAGEMENT_IP=<fsx-management-ip>
export FSX_SVM_NAME=<fsx-svm-name>
export FSX_SVM_DATA_LIF=<fsx-svm-data-lif>
export FSX_PASSWORD="$(aws secretsmanager get-secret-value --secret-id <fsx-password-secret-name> --output=text --query=SecretString | jq -r '.password')"
envsubst < manifests/backend-tbc-ontap-san.tmpl > temp/backend-tbc-ontap-san.yaml
kubectl create -n trident -f temp/backend-tbc-ontap-san.yaml
```
Of course replace:
- <fsx-management-ip> with the FSxN Management IP address.
- <fsx-svm-data-lif> with the data LIF IP address.
- <fsx-svm-name> with the name of the SVM that was created.
- <fsx-password-secret-name> with the name of the AWS SecretsManager secret that holds the FSxN password.

Feel free to look at the `temp/backend-tbc-ontap-san.yaml` file that was used to
configure the Trident backend.

As mentioned above, if you want to use NFS storage, instead of iSCSI, you can use the
`manifests/backend-tbc-ontap-nas.tmpl` file instead of the `manifests/backend-tbc-ontap-san.tmpl` file.

To confirm that the backend has been appropriately configured, run this command:
```bash
kubectl get tridentbackendconfig -n trident
```
The output should look similar to this:
```bash
NAME                    BACKEND NAME            BACKEND UUID                           PHASE   STATUS
backend-fsx-ontap-san   backend-fsx-ontap-san   7a551921-997c-4c37-a1d1-f2f4c87fa629   Bound   Success
```

### Create a Kubernetes storage class
The next step is to create a Kubernetes store class by executing:
```bash
kubectl create -f manifests/storageclass-fsxn-san.yaml
```
To confirm it worked execute this command:
```bash
kubectl get storageclass
```
The output should be similar to this:
```bash
NAME            PROVISIONER             RECLAIMPOLICY   VOLUMEBINDINGMODE      ALLOWVOLUMEEXPANSION   AGE
fsx-basic-san   csi.trident.netapp.io   Delete          Immediate              true                   9s
gp2 (default)   kubernetes.io/aws-ebs   Delete          WaitForFirstConsumer   false                  76m
```
Feel free to look at the `manifests/storageclass-fsxn-san.yaml` file to see
how the storage class was configured.

## Create a stateful application
Now that you have set up Kubernetes to use Trident to interface with FSxN for persistent
storage, you are ready to create an application that will use it. In the example below,
we are setting up a MySQL database that will use a iSCSI LUN configured on the FSxN file system.

### Create a Persistent Volume Claim
The first step is to create an iSCSI LUN for the database by executing:

```bash
kubectl create -f manifests/pvc-fsxn-san.yaml
```
To check that it worked, execute:
```bash
kubectl get pvc
```
The output should look similar to this:
```bash
NAME               STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS    VOLUMEATTRIBUTESCLASS   AGE
mysql-volume-san   Bound    pvc-b094e040-23d6-45ee-9801-924fec3264d1   50Gi       RWO            fsx-basic-san   <unset>                 8s
```

### Deploy a MySQL database using the storage created above
Now you can deploy a MySQL database by executing:
```bash
kubectl create -f manifests/mysql-san.yaml
```
To check that it is up run:
```bash
kubectl get pods
```
The output should look similar to this:
```bash
NAME                             READY   STATUS    RESTARTS   AGE
csi-snapshotter-0                3/3     Running   0          13m
mysql-fsx-san-79cdb57b58-gjjtn   1/1     Running   0          26s
```
To see how the MySQL was configured, check out the `manifests/mysql-san.yaml` file.

### Populate the MySQL database with data

Now to confirm that the database is able to read and write to the persistent storage you need
to put some data in the database. Do that by first logging into the MySQL instance.
It will prompt for a password. In the yaml file used to create the database, you'll see
that we set that to `Netapp1!`
```bash
kubectl exec -it $(kubectl get pod -l "app=mysql-fsx-san" --namespace=default -o jsonpath='{.items[0].metadata.name}') -- mysql -u root -p
```
NOTE: If you are using the NFS storage, be sure to use mysal-fsx-nas instead of mysql-fsx-san in the command above.

After you have logged in, here is a session showing an example of creating a database, then creating a table, then inserting
some values into the table:
```bash
mysql> create database fsxdatabase; 
Query OK, 1 row affected (0.01 sec)

mysql> use fsxdatabase;
Database changed 
mysql> create table fsx (filesystem varchar(20), capacity varchar(20), region varchar(20));
Query OK, 0 rows affected (0.04 sec)

mysql> insert into fsx (`filesystem`, `capacity`, `region`) values ('netapp01','1024GB', 'us-east-1'),('netapp02', 
'10240GB', 'us-east-2'),('eks001', '2048GB', 'us-west-1'),('eks002', '1024GB', 'us-west-2'),('netapp03', '1024GB', 'us-east-1'),('netapp04', '1024GB', 'us-west-1'); 
Query OK, 6 rows affected (0.03 sec) 
Records: 6  Duplicates: 0  Warnings: 0
```

And, to confirm everything is there, here is an SQL statement to retrieve the data:
```bash
mysql> select * from fsx;
+------------+----------+-----------+
| filesystem | capacity | region    |
+------------+----------+-----------+
| netapp01   | 1024GB   | us-east-1 |
| netapp02   | 10240GB  | us-east-2 |
| eks001     | 2048GB   | us-west-1 |
| eks002     | 1024GB   | us-west-2 |
| netapp03   | 1024GB   | us-east-1 |
| netapp04   | 1024GB   | us-west-1 |
+------------+----------+-----------+
6 rows in set (0.00 sec)
```

## Create a snapshot of the MySQL data
Of course one of the benefits of FSxN is the ability to take space efficient snapshots of the volumes.
These snapshots take almost no addiaional space on the backend storage and pose no performance impact.
So, let's create one for the SQL volume. The first step is to VolumeSnapshotClass by executing:
```bash
kubectl create -f manifests/volume-snapshot-class.yaml 
```
The output should look like:
```bash
volumesnapshotclass.snapshot.storage.k8s.io/fsx-snapclass created
```
Next, create a snapshot of the data by executing:
```bash
kubectl create -f manifests/volume-snapshot-san.yaml
```
The output should look like:
```bash
volumesnapshot.snapshot.storage.k8s.io/mysql-volume-san-snap-01 created
```
To confirm that the snapshot was created, execute:
```bash
kubectl get volumesnapshot
```
The output should look like:
```bash
NAME                       READYTOUSE   SOURCEPVC          SOURCESNAPSHOTCONTENT   RESTORESIZE   SNAPSHOTCLASS   SNAPSHOTCONTENT                                    CREATIONTIME   AGE
mysql-volume-san-snap-01   true         mysql-volume-san                           50Gi          fsx-snapclass   snapcontent-b3491f26-47e3-484c-aae0-69d45087d6c7   4s             5s
```

## Clone the MySQL data to a new storage persisent volume
Now that you have a snapshot of the data, you can create a read/write version of it, that
can be used as a new storage volume. This step creates a new FlexClone volume in FSx for ONTAP.
As mentioned above, on initial creation, a FlexClone takes almost no space; only a pointer
table gets created to the shared data blocks of the volume it is being cloned from.

The first step is to create a PersistentVolume from the snapshot by executing:
```bash
kubectl create -f manifests/pvc-from-san-snapshot.yaml
```
## Create a new MySQL database using the cloned storage
Now that you have a new storage volume, you can create a new MySQL database that uses it by executing:
```bash
kubectl create -f manifests/mysql-san-clone.yaml
```
To check that it is up run:
```bash
kubectl get pods
```
The output should look similar to this:
```bash
NAME                                  READY   STATUS    RESTARTS       AGE
csi-snapshotter-0                     3/3     Running   0              22h
mysql-fsx-san-695b497757-8n6bb        1/1     Running   0              21h
mysql-fsx-san-clone-d66d9d4bf-2r9fw   1/1     Running   0              14s
```
## To confirm that the new database is up and running, log into it and check the data
```bash
kubectl exec -it $(kubectl get pod -l "app=mysql-fsx-san-clone" --namespace=default -o jsonpath='{.items[0].metadata.name}') -- mysql -u root -p
```
After you have logged in, check that the same data is in the new database:
```bash
mysql> use fsxdatabase;
mysql> select * from fsx;
+------------+----------+-----------+
| filesystem | capacity | region    |
+------------+----------+-----------+
| netapp01   | 1024GB   | us-east-1 |
| netapp02   | 10240GB  | us-east-2 |
| eks001     | 2048GB   | us-west-1 |
| eks002     | 1024GB   | us-west-2 |
| netapp03   | 1024GB   | us-east-1 |
| netapp04   | 1024GB   | us-west-1 |
+------------+----------+-----------+
6 rows in set (0.00 sec)
```

## Final steps

At this point you don't need the jump server created to configure the EKS environment for
the FSxN File System, so feel free to `terminate` it (i.e. destroy it).

Other than that, you are welcome to deploy other applications that need persistent storage.

## Author Information

This repository is maintained by the contributors listed on [GitHub](https://github.com/NetApp/FSx-ONTAP-samples-scripts/graphs/contributors).

## License

Licensed under the Apache License, Version 2.0 (the "License").

You may obtain a copy of the License at [apache.org/licenses/LICENSE-2.0](http://www.apache.org/licenses/LICENSE-2.0).

Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an _"AS IS"_ basis, without WARRANTIES or conditions of any kind, either express or implied.

See the License for the specific language governing permissions and limitations under the License.

© 2024 NetApp, Inc. All Rights Reserved.
