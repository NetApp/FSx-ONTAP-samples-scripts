
# Multi log solution using FSxN and Trident on EKS

A multi log solution using NetApp FSxN and Trident for collecting non-stdout logs from applications.




## The problem
* Lets say you have your default application stream but you also want to maintain an access log and an audit log, each log has its own foramt, its own wirte frequesncy and even different permissions.  
* There is a need to save each type in a different file but the same goal of collecting these logs and pushing them to log aggreagtion engines/storage.
* The chalange is that these file are located on the disposible Pod storage and cannot be accessed or streamed same as std out/std error logs.
* A more advance but still common scenario is when a container has more than one log stream / file.




## Collecting logs using FSxN Trident persistent storage

With FSxN and Trident, you can create a shared namespace persistent storage platform and collect non-stdout logs into one location (ElasticSearch, Loki, S3, etc..), overcoming the common obstacles faced when implementing multilog solutions.





### Solution Architecture Example
## Getting Started

The following sections provide quickstart instructions for multiple logs shippers. All of these assume that you have cloned this repository locally and are using a CLI thats current directory is the root of the code repository.

### Prerequisites

* `Helm` - for reources installation.
* `Kubectl` – for interacting with the EKS cluster.
* NetApp FSxN running on the same EKS vpc.
* TCP NFS ports should be open between the EKS nodes and the FSxN: 
    `111`,
    `2049`,
    `635`,
    `4045`,
    `4046`,
    `4049` - [Check NetAppKB instructions](https://kb.netapp.com/onprem/ontap/da/NAS/Which_Network_File_System_NFS_TCP_and_NFS_UDP_ports_are_used_on_the_storage_system)
* Kubernetes Snapshot Custom Resources (CRD) and Snapshot Controller installed on EKS cluster:
  Learn more about the snapshot requirements for your cluster in the ["How to Deploy Volume Snapshots”](https://kubernetes.io/blog/2020/12/10/kubernetes-1.20-volume-snapshot-moves-to-ga/#how-to-deploy-volume-snapshots) Kuberbetes blog.
* NetApp Trident operator CSI should be installed on EKS. [Check Trident installation guide using Helm](https://docs.netapp.com/us-en/trident/trident-get-started/kubernetes-deploy-helm.html#deploy-the-trident-operator-and-install-astra-trident-using-helm).

### Installation

* Configure Trident CSI backend to connect to the FSxN file system. Create the backend configuration for the trident driver. Create secret on trident namespace and fill the FSxN password:
```kubectl create secret generic fsx-secret --from-literal=username=fsxadmin --from-literal=password=<your FSxN password> -n trident --create-namespace```
* Install trident-resources helm chart from this GitHub repository.
  The custom Helm chart includes:
   - `backend-tbc-ontap-nas.yaml` - backend configuration for using NFS on EKS
   - `backend-fsx-ontap-san.yaml` - backend configuration for using ISCSI on EKS (Optional)
   - `storageclass-fsx-nfs.yaml` - Kubernetes storage class for using NFS 
   - `storageclass-fsx-san.yaml` - Kubernetes storage class for using ISCSI (Optional) 
   - `primary-pvc-fsx.yaml` - primary PVC that will be shared cross-namespaces. NOTE: The PVC will be created in the log-collector namespace, so if it does not exist, it should be created before. [Check Trident TridentVolumeReference](https://docs.netapp.com/us-en/trident/trident-use/volume-share.html).

The following variables should be filled on the Values.yaml or run the following by using `--set` Helm command.

* `namespace` - namespace of the Trident operator
* `fsx.managment_lif` - FSxN ip address
* `fsx.svm_name` - FSxN SVM name
* `configuration.storageclass_nas` - NAS storage class name
* `configuration.storageclass_san` - SAN (ISCSI) storage class name

Then use helm to deploy the package:
```helm install trident-resources ./trident-resources -n trident```

Verify that FSxN has been successfully connected to the backend:
```kubectl get TridentBackendConfig -n trident```

### Implementing a sample application for collecting logs

Here is an example of an application that mounts Trident PVC at /log and uses it for cross-namespace PVC.

##### **shared-pvc.yaml**:
```
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  annotations:
      trident.netapp.io/shareFromPVC: vector/shared-pv
  name: rpc-app-pvc
  namespace: rpc
spec:
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 100Gi
  storageClassName: trident-csi
```
 * `trident.netapp.io/shareFromPVC:` The primary PersistentVolumeClaim you have created previously.
* `storage` - volume size

##### **volume-reference-fsx.yaml**:
```
apiVersion: trident.netapp.io/v1
kind: TridentVolumeReference
metadata:
  name: rpc-app-pvc
  namespace: rpc
spec:
  pvcName: shared-pv
  pvcNamespace: vector
```
##### **eks-sample-linux-deployment.yaml**:
```
      volumes:
        - name: task-pv-storage
          persistentVolumeClaim:
            claimName: rpc-app-pvc
```
```
        env:
          - name: POD_NAME
            valueFrom:
              fieldRef:
                apiVersion: v1
                fieldPath: metadata.name
          - name: NODE_NAME
            valueFrom:
              fieldRef:
                apiVersion: v1
                fieldPath: spec.nodeName
```
```
        volumeMounts:
          - mountPath: "/log"
            subPathExpr: $(NODE_NAME)/$(POD_NAME)
            name: task-pv-storage
```
* Mount FSxN Trident volume to the sample application
* Adding `POD_NAME`, `NODE_NAME` as environment variables for using `Kubernetes subPathExpr`. In this example, a Pod uses subPathExpr to create a directory `/<current-running-node-name>/<pod-name>` within the mountPath volume `/log`. The mountPath volume takes the Pod name and the Node name from the downwardAPI. The mount directory `/log/<node>/<pod>` is mounted at `/log` in the container and the container writes logs directly to `/log/<node>/<pod>` path. See [Kubernetes subPathExpr example](https://kubernetes.io/docs/concepts/storage/volumes/).

Installing an example application by helm:

```helm upgrade --install example-app ./examples/example-app -n rpc --create-namespace```

When the application is deployed, you should be able to see the PVC as a mount at /log.

### Collecting application logs with a logs collector

Implementing an open-source log collectors to collect logs from the PVC and stream them to ElasticSearch, Loki, S3, etc.

#### **vector.dev** 
A lightweight, ultra-fast tool for building observability pipelines. Check [vector.dev documentation](https://vector.dev/)

Install Vector.dev agent as DeamonSet from [Helm chart](https://vector.dev/docs/setup/installation/package-managers/helm/) and configure :
1. Clone vector GitHub repository:
``` 
git clone https://github.com/vectordotdev/helm-charts.git

```

2. Adding override values:
**vector-override-values.yaml**:
```
role: "Agent"
existingConfigMaps: 
  - "vector-logs-cm"
dataDir: "/vector-data-dir"

extraVolumeMounts:
- name: shared-logs
  mountPath: /logs
  readOnly: false
  subPathExpr: $(VECTOR_SELF_NODE_NAME)

service:
  ports: 
    - 9090
``` 
* `role: "Agent"` - Deploy vector as DeamonSet.
* `existingConfigMaps` - Adding cutom ConfigMap
* `extraVolumeMounts` - Mount primary PVC as `/logs/<currnet-node>`, a DeamonSet can only see pods logs on the same host.


3. Adding `/examples/logs-collectors/vector/vector-logs-cm.yaml` into Vector stack:

###### **vector-logs-cm.yaml**:
```
apiVersion: v1
kind: ConfigMap
metadata:
  name: vector-logs-cm
  namespace: vector

data:
  stdout.toml: |
    data_dir = "/vector-data-dir" 
    api.enabled = true            
    api.address = "0.0.0.0:8686"       
    
    [sources.access_logs]
      type = "file"
      ignore_older_secs = 600
      include = [ "/logs/*/*.log" ]
      read_from = "beginning"   

    #Send structured data to console                                                                                                                                                                                                                                               
    [sinks.sink_console]                                                                                                                                                                                                                                                       
      type = "console"                                                                                                                                                                                                                                                         
      inputs = ["access_logs"]                                                                                                                                                                                                                                                
      target = "stdout"                                                                                                                                                                                                                                                        
      encoding.codec = "text" 
```

In the example above, collecting logs from [source file](https://vector.dev/docs/reference/configuration/sources/file/) as /logs mount and stream it into the console.
[See more vector Sink configuration](https://vector.dev/docs/reference/configuration/sinks/)

4. Install Vector using override values:
```
helm install vector ./ \
  --namespace vector \
  --create-namespace \
  -f agent-override-values.yaml
```

#### **Filebeat** 
Lightweight shipper for logs. Check [Filebeat documentation](https://github.com/elastic/helm-charts/tree/main/filebeat)

Install Filebeat as DeamonSet from Helm chart and configure:
1. Clone Filebeat GitHub repository:
```
git clone https://github.com/elastic/helm-charts.git
cd filebeat
```
2. Adding override values:
**filebeat-overide-values.yaml**:
```
daemonset:
  enabled: true
  extraVolumeMounts:
    - name: shared-logs
      mountPath: /logs
      readOnly: false
      subPathExpr: $(NODE_NAME)

  extraVolumes:
    - name: shared-logs
      persistentVolumeClaim:
        claimName: shared-pv
```
3. Adding `/examples/logs-collectors/filebeat/filebeat-logs-config.yaml` into Filebeat stack:
**filebeat-logs-config.yaml**:
```
apiVersion: v1
kind: ConfigMap
metadata:
  name: logs-config
  labels:
    app: '{{ template "filebeat.fullname" . }}-logs-config'
    chart: "{{ .Chart.Name }}-{{ .Chart.Version }}"
    heritage: {{ .Release.Service | quote }}
    release: {{ .Release.Name | quote }}
data:
  filebeat.yml: |
    filebeat.inputs:
      - type: log
        paths:
          - /logs/*/*.log
    output.console:
      pretty: true
```
In the example above, collecting logs from [input Log](https://www.elastic.co/guide/en/beats/filebeat/current/filebeat-input-log.html) as `/logs` mount and stream it into the console.
[See more filebeat output configuration](https://www.elastic.co/guide/en/beats/filebeat/current/configuring-output.html)

4. Adding config map reference to Filebeat DeamonSet:
**deamonset.yaml:**
```
    - name: filebeat-config
    configMap:
        defaultMode: 0600
        name: logs-config
```

5. Install Filebeat using override values:
```
helm install filebeat ./
  --namespace vector \
  --create-namespace \
  -f filebeat-overide-values.yaml
```

#### **Fluent-bit** 
Fluent Bit is an open-source telemetry agent specifically designed to efficiently handle the challenges of collecting and processing telemetry data across a wide range of environments. [Check Fluent-bit documentation](https://docs.fluentbit.io/manual/)

Install fluent-operator from [Helm chart](https://github.com/fluent/helm-charts/tree/main/charts/fluent-operator) and configure:

1. Adding `/examples/logs-collectors/fluent-bit/fluentbit-override-values.yaml` override values:
**fluentbit-override-values.yaml:**
```
fluentbit:
  enable: true
  input:
    tail:
      enable: true
      path: "/logs/*/*.log"
  output:
      stdout: 
        enable: true
      
  additionalVolumes: 
    - name: shared-logs
      persistentVolumeClaim:
        claimName: shared-pv
  # Pod volumes to mount into the container's filesystem.
  additionalVolumesMounts: 
    - name: shared-logs
      mountPath: /logs
      readOnly: false
      subPathExpr: $(NODE_NAME)
```
2. Install fluent-operator using override values:
```
helm upgrade --install fluent-operator --create-namespace -n vector charts/fluent-operator/ -f /examples/logs-collectors/fluent-bit/fluentbit-override-values.yaml
```
## Running Tests

To run tests, connect to the sample application and create a log file under /log:

```bash
  kubectl exec -it --namespace rpc eks-sample-linux-deployment-858b788c8-57gsz /bin/bash
  # Run this inside the container:
  echo "this is my first log" >> /log/access.log
```
You should see the log on vector stdout log:
```
2024-01-21T11:45:31.903153Z  INFO source{component_kind="source" component_id=access_logs component_type=file}:file_server: vector::internal_events::file::source: Found new file to watch. file=/logs/eks-sample-linux-deployment-858b788c8-57gsz/access.log
this is my first log
```

You should see the log on filebeat stdout log:
```
"log": {
    "offset": 0,
    "file": {
    "path": "/logs/eks-sample-linux-deployment-858b788c8-57gsz/access.log"
    }
},
"message": "this is my first log",
"input": {
    "type": "log"
}
```
You should see the log on fluent-bit stdout log:
```
kube.logs.eks-sample-linux-deployment-858b788c8-mrl6l.access.log: [[1705914980.701605366, {}], {"log"=>"this is my first log"}]
```
## Author Information

This repository is maintained by the contributors listed on [GitHub](https://github.com/NetApp/FSx-ONTAP-samples-scripts/graphs/contributors).

## License

Licensed under the Apache License, Version 2.0 (the "License").

You may obtain a copy of the License at [apache.org/licenses/LICENSE-2.0](http://www.apache.org/licenses/LICENSE-2.0).

Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an _"AS IS"_ basis, without WARRANTIES or conditions of any kind, either express or implied.

See the License for the specific language governing permissions and limitations under the License.

© 2024 NetApp, Inc. All Rights Reserved.