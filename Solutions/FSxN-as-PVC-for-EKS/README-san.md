### Configure the Trident CSI backend to use FSx for NetApp ONTAP
For the example below we are going to set up an iSCSI LUN for a MySQL
database. To help facilitate that, we are going to set up Astra Trident as a backend provider.
Since we are going to be creating an iSCSI LUN, we are going to use its `ontap-san` driver.
Astra Trident has several different drivers to choose from. You can read more about the
drivers it supports in the
[Astra Trident documentation.](https://docs.netapp.com/us-en/trident/trident-use/trident-fsx.html#fsx-for-ontap-driver-details)

In the commands below you're going to need the FSxN ID, the FSX SVM name, and the
secret ARN. All of that information can be obtained from the output
from the `terraform apply` command. If you have lost that output, you can always log back
into the server where you ran `terraform apply` and simply run it again. It should
state that there aren't any changes to be made and simply show the output again.

Note that a copy of this repo has been put into ubuntu's home directory on the
jump server for you. Don't be confused with this copy of the repo and the one you
used to create the environment with earlier. This copy will not have the terraform
state information, nor your changes to the variables.tf file, but it does have
other files you'll need to complete the setup.

After making the following substitutions in the commands below:
- \<fsx-id> with the FSxN ID.
- \<fsx-svm-name> with the name of the SVM that was created.
- \<secret-arn> with the ARN of the AWS SecretsManager secret that holds the FSxN password.

Run them to configure Trident to use the FSxN file system that was
created earlier using the `terraform --apply` command:
```
cd ~/FSx-ONTAP-samples-scripts/Solutions/FSxN-as-PVC-for-EKS
mkdir temp
export FSX_ID=<fsx-id>
export FSX_SVM_NAME=<fsx-svm-name>
export SECRET_ARN=<secret-arn>
envsubst < manifests/backend-tbc-ontap-san.tmpl > temp/backend-tbc-ontap-san.yaml
kubectl create -n trident -f temp/backend-tbc-ontap-san.yaml
```

To get more information regarding how the backed was configured, look at the
`temp/backend-tbc-ontap-san.yaml` file.

To confirm that the backend has been appropriately configured, run this command:
```bash
kubectl get tridentbackendconfig -n trident
```
The output should look similar to this:
```bash
NAME                    BACKEND NAME            BACKEND UUID                           PHASE   STATUS
backend-fsx-ontap-san   backend-fsx-ontap-san   7a551921-997c-4c37-a1d1-f2f4c87fa629   Bound   Success
```
If the status is `Failed`, then you can add the "--output=json" flag to the `kubectl get tridentbackendconfig`
command to get more information as to why it failed. Specifically, look at the "message" field in the output.
The following command will get just the status messages:
```bash
kubectl get tridentbackendconfig -n trident --output=json | jq '.items[] | .status.message'
```
Once you have resolved any issues, you can remove the failed backend by running:

**ONLY RUN THIS COMMAND IF THE STATUS IS FAILED**
```bash
kubectl delete -n trident -f temp/backend-tbc-ontap-san.yaml
```
Then, you can re-run the `kubectl create -n trident -f temp/backend-tbc-ontap-san.yaml` command.
If the issues was with one of the variables that was substituted in, then you will need to
rerun the `envsubst` command to create a new `temp/backend-tbc-ontap-san.yaml` file
before running the `kubectl create -n trident -f temp/backend-tbc-ontap-san.yaml` command.

### Create a Kubernetes storage class
The next step is to create a Kubernetes storage class by executing:
```bash
kubectl create -f manifests/storageclass-fsxn-san.yaml
```
To confirm it worked run this command:
```bash
kubectl get storageclass
```
The output should be similar to this:
```bash
NAME              PROVISIONER             RECLAIMPOLICY   VOLUMEBINDINGMODE      ALLOWVOLUMEEXPANSION   AGE
fsx-basic-san     csi.trident.netapp.io   Delete          Immediate              true                   20h
gp2 (default)     kubernetes.io/aws-ebs   Delete          WaitForFirstConsumer   false                  44h
```
To see more details on how the storage class was defined, look at the `manifests/storageclass-fsxn-san.yaml`
file.

## Create a stateful application
Now that you have set up Kubernetes to use Trident to interface with FSxN for persistent
storage, you are ready to create an application that will use it. In the example below,
we are setting up a MySQL database that will use an iSCSI LUN provisioned on the FSxN file system.

### Create a Persistent Volume Claim
The first step is to create an iSCSI LUN for the database by running:

```bash
kubectl create -f manifests/pvc-fsxn-san.yaml
```
To check that it worked, run:
```bash
kubectl get pvc
```
The output should look similar to this:
```bash
NAME               STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS    VOLUMEATTRIBUTESCLASS   AGE
mysql-volume-san   Bound    pvc-1aae479e-4b27-4310-8bb2-71255134edf0   50Gi       RWO            fsx-basic-san   <unset>                 114m
```

If you want to see what was created on the FSxN file system, you can log into it and take a look.
You will want to login as the 'fsxadmin' user, using the password stored in the AWS SecretsManager secret.
You can find the IP address of the FSxN file system in the output from the `terraform apply` command, or
from the AWS console. Here is an example of logging in and listing all the LUNs and volumes on the system:
```bash
ubuntu@ip-10-0-4-125:~/FSx-ONTAP-samples-scripts/Solutions/FSxN-as-PVC-for-EKS$ ssh -l fsxadmin 198.19.255.174
(fsxadmin@198.19.255.174) Password:

Last login time: 6/21/2024 15:30:27
FsxId0887a493c777c5122::> lun show
Vserver   Path                            State   Mapped   Type        Size
--------- ------------------------------- ------- -------- -------- --------
ekssvm    /vol/trident_pvc_1aae479e_4b27_4310_8bb2_71255134edf0/lun0
                                          online  mapped   linux        50GB

FsxId0887a493c777c5122::> volume show
Vserver   Volume       Aggregate    State      Type       Size  Available Used%
--------- ------------ ------------ ---------- ---- ---------- ---------- -----
ekssvm    ekssvm_root  aggr1        online     RW          1GB    972.4MB    0%
ekssvm    trident_pvc_1aae479e_4b27_4310_8bb2_71255134edf0
                       aggr1        online     RW         55GB    54.90GB    0%
2 entries were displayed.
```

### Deploy a MySQL database using the storage created above
Now you can deploy a MySQL database by running:
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
mysql-fsx-san-79cdb57b58-m2lgr   1/1     Running   0          31s
```
Note that it might take a minute or two for the pod to get to the Running status.

To see how the MySQL was configured, check out the `manifests/mysql-san.yaml` file.

### Populate the MySQL database with data

Now to confirm that the database can read and write to the persistent storage you need
to put some data in the database. Do that by first logging into the MySQL instance using the
command below. It will prompt for a password. In the yaml file used to create the database,
you'll see that we set that to `Netapp1!`
```bash
kubectl exec -it $(kubectl get pod -l "app=mysql-fsx-san" --namespace=default -o jsonpath='{.items[0].metadata.name}') -- mysql -u root -p
```

After you have logged in, here is a session showing an example of creating a database, then creating a table, then inserting
some values into the table:
```
mysql> create database fsxdatabase; 
Query OK, 1 row affected (0.01 sec)

mysql> use fsxdatabase;
Database changed 

mysql> create table fsx (filesystem varchar(20), capacity varchar(20), region varchar(20));
Query OK, 0 rows affected (0.04 sec)

mysql> insert into fsx (`filesystem`, `capacity`, `region`) values ('netapp01','1024GB', 'us-east-1'),
('netapp02', '10240GB', 'us-east-2'),('eks001', '2048GB', 'us-west-1'),('eks002', '1024GB', 'us-west-2'),
('netapp03', '1024GB', 'us-east-1'),('netapp04', '1024GB', 'us-west-1'); 
Query OK, 6 rows affected (0.03 sec) 
Records: 6  Duplicates: 0  Warnings: 0
```

And, to confirm everything is there, here is an SQL statement to retrieve the data:
```
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

mysql> quit
Bye
```

## Create a snapshot of the MySQL data
Of course, one of the benefits of FSxN is the ability to take space efficient snapshots of the volumes.
These snapshots take almost no additional space on the backend storage and pose no performance impact.

### Install the Kubernetes Snapshot CRDs and Snapshot Controller:
The first step is to install the Snapshot CRDs and the Snapshot Controller.
To do that by running these commands:
```bash
git clone https://github.com/kubernetes-csi/external-snapshotter 
cd external-snapshotter/ 
kubectl kustomize client/config/crd | kubectl create -f - 
kubectl -n kube-system kustomize deploy/kubernetes/snapshot-controller | kubectl create -f - 
kubectl kustomize deploy/kubernetes/csi-snapshotter | kubectl create -f - 
cd ..
```
### Create a snapshot class based on the CRD instsalled
Create a snapshot class by executing:
```bash
kubectl create -f manifests/volume-snapshot-class.yaml 
```
The output should look like:
```bash
volumesnapshotclass.snapshot.storage.k8s.io/fsx-snapclass created
```
Note that this storage class works for both LUNs and NFS volumes, so there aren't different versions
of this file based on the storage type you are testing with.

### Create a snapshot of the MySQL data
Now you can create a snapshot by running:
```bash
kubectl create -f manifests/volume-snapshot-san.yaml
```
The output should look like:
```bash
volumesnapshot.snapshot.storage.k8s.io/mysql-volume-san-snap-01 created
```
To confirm that the snapshot was created, run:
```bash
kubectl get volumesnapshot
```
The output should look like:
```bash
NAME                       READYTOUSE   SOURCEPVC          SOURCESNAPSHOTCONTENT   RESTORESIZE   SNAPSHOTCLASS   SNAPSHOTCONTENT                                    CREATIONTIME   AGE
mysql-volume-san-snap-01   true         mysql-volume-san                           50Gi          fsx-snapclass   snapcontent-bdce9310-9698-4b37-9f9b-d1d802e44f17   2m18s          2m18s
```

You can log onto the FSxN file system to see that the snapshot was created there:
```bash
FsxId0887a493c777c5122::> snapshot show -volume trident_pvc_*
                                                                 ---Blocks---
Vserver  Volume   Snapshot                                  Size Total% Used%
-------- -------- ------------------------------------- -------- ------ -----
ekssvm   trident_pvc_1aae479e_4b27_4310_8bb2_71255134edf0
                  snapshot-bdce9310-9698-4b37-9f9b-d1d802e44f17
                                                           140KB     0%    0%
```
## Clone the MySQL data to a new storage persistent volume
Now that you have a snapshot of the data, you can use it to create a read/write version
of it. This can be used as a new storage volume for another mysql database. This operation
creates a new FlexClone volume in FSx for ONTAP.  Note that initially a FlexClone volume
take up almost no additional space; only a pointer table is created to point to the
shared data blocks of the volume it is being cloned from.

The first step is to create a Persistent Volume Claim from the snapshot by executing:
```bash
kubectl create -f manifests/pvc-from-san-snapshot.yaml
```
To check that it worked, run:
```bash
kubectl get pvc
```
The output should look similar to this:
```bash
$ kubectl get pvc
NAME                     STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS    VOLUMEATTRIBUTESCLASS   AGE
mysql-volume-san         Bound    pvc-1aae479e-4b27-4310-8bb2-71255134edf0   50Gi       RWO            fsx-basic-san   <unset>                 125m
mysql-volume-san-clone   Bound    pvc-ceb1b2c2-de35-4011-8d6e-682b6844bf02   50Gi       RWO            fsx-basic-san   <unset>                 2m22s
```

To check it on the FSxN side, you can run:
```bash
FsxId0887a493c777c5122::> volume clone show
                      Parent  Parent        Parent
Vserver FlexClone     Vserver Volume        Snapshot             State     Type
------- ------------- ------- ------------- -------------------- --------- ----
ekssvm  trident_pvc_ceb1b2c2_de35_4011_8d6e_682b6844bf02
                      ekssvm  trident_pvc_1aae479e_4b27_4310_8bb2_71255134edf0
                                            snapshot-bdce9310-9698-4b37-9f9b-d1d802e44f17
                                                                 online    RW
```
### Create a new MySQL database using the cloned volume
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
### To confirm that the new database is up and running, log into it and check the data
```bash
kubectl exec -it $(kubectl get pod -l "app=mysql-fsx-san-clone" --namespace=default -o jsonpath='{.items[0].metadata.name}') -- mysql -u root -p
```
After you have logged in, check that the same data is in the new database:
```
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
