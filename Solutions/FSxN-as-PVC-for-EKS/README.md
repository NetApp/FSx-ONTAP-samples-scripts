# FSx for NetApp ONTAP as persistent storage

## Introduction

In this project you'll find the instructions and code necessary to deploy an AWS EKS
cluster and an Amazon FSx for NetApp ONTAP File System (FSxN) to provide the persistent storage
for it. It will leverage NetApp's Astra Trident to provide the interface between EKS to FSxN.

## Prerequisites

A Linux based EC2 instance with the following installed:
- Hashicorp Terraform
- AWS CLI authenticated with an account that has privileges necessary to:
	- Deploy an EKS cluster
	- Deplay an FSx for Netapp ONTAP File System
	- Create security groups
	- Create a VPC and subnets
	- Create a NAT Gateway
	- Create an EC2 instance

## Installation Overview
The overall process is as follows:
- Ensure the prerequisites have been installed and configured.
- Clone this repo from GitHub
- Make any desired changes to the variables.tf file.
- Run 'terraform init' to initialize the terraform environment.
- Run 'terraform apply -auto-approve' to:
  - Create a new VPC with public and priviate subnets
  - Deploy a FSx for NetApp ONTAP File System
  - Deploy a EKS cluster
  - Deploy an EC2 Linux based instance
- SSH to the Linux based instance to complete the setup
  - Install the FSx for NetApp ONTAP Trident CSI driver
  - Configure the Trident CSI driver
  - Create a Kubernetes storage class
- Deploy an sample application to test the storage with

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
- fsx_throughput_capacity - The throughput capacity of the FSx for NetApp ONTAP File System.
Read the "description" of the variable to see valid values.
- fsx_storage_capacity - The storage capacity of the FSx for NetApp ONTAP File System.
Read the "description" of the variable to see the valid range.
- key_pair_name - The name of the key pair to use to access the jump server.
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

eks-cluster-name = "fsx-eks-tA4dcLJc"
eks-jump-server = "Instance ID: i-0a685d8d694846119, Public IP: 54.200.56.39"
fsx-management-ip = "FSX_MANAGEMENT_IP=198.19.255.98"
fsx-password = "FSX_PASSWORD=x8Dukl5!"
fsx-svm-name = "FSX_SVM_NAME=ekssvm"
region = "us-west-2"
zz_update_kubeconfig_command = "aws eks update-kubeconfig --name fsx-eks-tA4dcLJc --region us-west-2"
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
referened in the variables.tf file.
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
to your EKS configuration, and associate it with Cluster Admin policy to be able to view and
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
aws eks associate-access-policy --cluster-name <EKS_CLUSTER_NAME>  --principal-arn <USER_ARN> --policy-arn arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy --access-scope type=cluster
```
Like above, replace <EKS_CLUSTER_NAME> with the name of your EKS cluster. And replace <USER_ARN> with
IAM ARN obtained from the command above. Leave the rest of the arguments as is.

### Configure kubectl to use the EKS cluster
You'll notice from the output of the `terraform apply` command a "zz_update_kubeconfig_command"
variable. The output of that variable shows the command to run to configure kubectl to use
the EKS cluster.
Here's an example:
```bash
aws eks update-kubeconfig --name EKS_CLUSTER_NAME --region us-west-2
```
Run the following command to confirm you can communicate with the EKS cluster:
```bash
kubectl get nodes
```
You should get output similar to this:
```bash
NAME                                           STATUS   ROLES    AGE   VERSION
ip-192-168-1-100.us-west-2.compute.internal     Ready    <none>   2m    v1.21.2-eks-55c2c7
ip-192-168-1-101.us-west-2.compute.internal     Ready    <none>   2m    v1.21.2-eks-55c2c7
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
to see what the latest version is: [Releases Netapp/trident](https://github.com/NetApp/trident/releases/). The latest version will always be at the top of
that page. The below example is downloading the latest version as of May 16th, 2024.
```bash
wget https://github.com/NetApp/trident/releases/download/v24.02.0/trident-installer-24.02.0.tar.gz
tar -xf trident-installer-24.02.0.tar.gz
helm install trident -n trident --create-namespace  trident-installer/helm/trident-operator-*.tgz
```

### Confirm Trident is up and running
Confirm that the Trident operator is up and running by runing this command:
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

### Configure the Trident CSI backend to FSx for NetApp ONTAP
For the example use case outlined below we are going to set up an iSCSI LUN for an MySQL
database. Because of that, we are going to set the storage driver name
in the Trident backend configuration to `ontap-san`. You can read more about
the different driver types in the
[Astra Trident documentation](https://docs.netapp.com/us-en/trident/trident-use/trident-fsx.html#drivers).

In the command below you're going to need the FSX Management IP, the FSX password, and
the name of the SVM that was created. You can obtain all that information from the output
from the `terraform apply` command. If you have lost that output, you can always log back
into the server where you ran `terraform apply` and simply run it again. It should
state that there aren't any changes to be made and show the output again.

Note that a copy of the this repo has been put into the
ubuntu home directory for you. Don't be confused with this copy and the one you used to create the
environment earlier. This copy will not have the terraform state information, nor your changes
to the variables.tf file.

Execute the following commands to configure Trident to use the `ontap-san` driver.
```bash
cd ~/FSx-ONTAP-samples-scripts/Solutions/FSxN-as-PVC-for-EKS
mkdir temp
FSX_MANAGEMENT_IP=<IP_ADDRESS> FSX_PASSWORD=<FSX_PASSWORD> FSX_SVM_NAME=<SVM_NAME> envsubst < manifests/backend-tbc-ontap-san.tmpl > temp/backend-tbc-ontap-san.yaml
kubectl create -n trident -f temp/backend-tbc-ontap-san.yaml
```
Of course replace <IP_ADDRESS> with the FSxN Management IP address, replace <FSX_PASSWORD>
with the password of the FSxN File System, and replace <SVM_NAME> with the name of the
SVM that was created.

Feel free to look at the `temp/backend-tbc-ontap-san.yaml` file that was used to
configure the Trident backend.

To confirm that the backend has been appropriatedly configured, run this command:
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
kubectl create -f manifests/storageclass-fsxn-block.yaml
```
To confirm it worked execute this command:
```bash
kubectl get storageclass
```
The output should be similar to this:
```bash
NAME              PROVISIONER             RECLAIMPOLICY   VOLUMEBINDINGMODE      ALLOWVOLUMEEXPANSION   AGE
fsx-basic-block   csi.trident.netapp.io   Delete          Immediate              true                   20h
gp2 (default)     kubernetes.io/aws-ebs   Delete          WaitForFirstConsumer   false                  44h
```
Feel free to look at the `manifests/storageclass-fsxn-block.yaml` file to see
how the storage class was configured.

## Create a stateful application
Now that you have setup Kubernetes to use Trident to interface with FSxN for presistent
storage, you are ready to create an application that will use it. In the example below,
we are setting up a MySQL database that will use a iSCSI LUN configured on the FSxN file system.

### Create a Persistent Volume Claim
The first step is to create an iSCSI LUN for the database by executing:

```bash
kubectl create -f manifests/pvc-fsxn-block.yaml
```
To check that it worked, execute:
```bash
kubectl get pvc
```
The output should look similar to this:
```bash
NAME           STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS      VOLUMEATTRIBUTESCLASS   AGE
mysql-volume   Bound    pvc-f1e94884-fb3b-4cb0-b58b-50fa2b8cbb77   50Gi       RWO            fsx-basic-block   <unset>                 20h
```

### Deploy an MySQL database using the storage created above
Now you can deply a MySQL database by executing:
```bash
kubectl create -f manifests/mysql.yaml
```
To check that it is up run:
```bash
kubectl get pods
```
The output should look similar to this:
```bash
NAME                         READY   STATUS    RESTARTS   AGE
csi-snapshotter-0            3/3     Running   0          22h
mysql-fsx-695b497757-pvn7q   1/1     Running   0          20h
```
To see how the MySQL was configured, check out the `manifests/mysql.yaml` file.

### Populate the MySQL database with data

Now to confirm that the database is able to read and write to the presistent storage you need
to put some data in the database. Do that by first logging into the MySQL instance.
It will prompt for a password. In the yaml file used to create the database, you'll see
that we set that to `Netapp1!`
```bash
kubectl exec -it $(kubectl get pod -l "app=mysql-fsx" --namespace=default -o jsonpath='{.items[0].metadata.name}') -- mysql -u root -p
```
Onced logged in, here are some SQL statements used to create a database, create a table, then insert
some values:
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
## Final steps

At this point you don't need to jump server created to configure the EKS environment for
the FSxN File System, so feel free to `terminate` it (i.e. destory it).

Other than that, you are welcome to deploy other applications that need persistent storage.

## Author Information

This repository is maintained by the contributors listed on [GitHub](https://github.com/NetApp/FSx-ONTAP-samples-scripts/graphs/contributors).

## License

Licensed under the Apache License, Version 2.0 (the "License").

You may obtain a copy of the License at [apache.org/licenses/LICENSE-2.0](http://www.apache.org/licenses/LICENSE-2.0).

Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an _"AS IS"_ basis, without WARRANTIES or conditions of any kind, either express or implied.

See the License for the specific language governing permissions and limitations under the License.

© 2024 NetApp, Inc. All Rights Reserved.