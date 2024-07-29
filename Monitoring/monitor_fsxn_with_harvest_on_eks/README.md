# Deploy NetApp Harvest on EKS 

Harvest helm chart for monitoring Amazon FSx for ONTAP with Harvest, Grafana and Prometheus on EKS.

## Introduction
This sample shows how to deploy NetApp Harvest on EKS to monitor an Amazon FSx for NetApp ONTAP file system.
Harvest is a data collector that collects metrics from a NetApp ONTAP storage system and provides a REST API
for accessing the collected data. Harvest can be used to monitor the performance of your FSx for ONTAP
file system and visualize the metrics on Grafana. You can read more about Harvest [here](https://netapp.github.io/harvest/).

## What to expect

Harvest Helm chart installation will result the following:
* Install NetApp Harvest with latest version on your EKS
* Collecting metrics about your FSx for ONTAP.
* Add Grafana dashboards for better visualization.

## Prerequisites
* `helm` - for resources installation.
* A NetApp FSx for ONTAP accessible from the same VPC as you EKS cluster.
* If you want Prometheus to have persistent storage, you will need a storage class defined. I would recommend 
using NetApp's Astra Trident to offer up some storage from your FSx for ONTAP file system. You can install Trident from
the AWS Marketplace into your EKS cluster. If you need help creating a storage class using Trident, please refer to the
[Trident documentation](https://docs.netapp.com/us-en/trident/).

## Deployment of Prometheus and Grafana
If you don't have Prometheus and Grafana running in your EKS cluster, you can deploy both of them
using the following commands:
```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack --namespace prometheus --create-namespace \
  --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.storageClassName=<FSX-BASIC-NAS>, \
  --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage=50Gi
```
Where:
* \<FSX-BASIC-NAS\> is the storage class you want to use.  If you don't care about persistent storage, you can omit the
last two lines from the above command.

The above will create a 50Gib PVC for Prometheus to use. You can adjust the size as needed.

A successful installation should look like this:
```bash
$ helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack --namespace prometheus --create-namespace \
  --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.storageClassName=fsx-basic-nas, \
  --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage=50Gi
NAME: kube-prometheus-stack
LAST DEPLOYED: Fri Jul 26 22:57:04 2024
NAMESPACE: prometheus
STATUS: deployed
REVISION: 1
NOTES:
kube-prometheus-stack has been installed. Check its status by running:
  kubectl --namespace prometheus get pods -l "release=kube-prometheus-stack"

Visit https://github.com/prometheus-operator/kube-prometheus for instructions on how to create & configure Alertmanager and Prometheus instances using the Operator.
```

To check the status, you can run the following command:
```bash
kubectl get pods -n prometheus
```
It should look something like this:
```bash
$ kubectl get pods -n prometheus
NAME                                                        READY   STATUS    RESTARTS   AGE
alertmanager-kube-prometheus-stack-alertmanager-0           2/2     Running   0          51s
kube-prometheus-stack-grafana-86844f6b47-njw6n              3/3     Running   0          56s
kube-prometheus-stack-kube-state-metrics-7c8d64d446-rj4tv   1/1     Running   0          56s
kube-prometheus-stack-operator-85b765d6bc-ll5q2             1/1     Running   0          56s
kube-prometheus-stack-prometheus-node-exporter-7rtbp        1/1     Running   0          56s
kube-prometheus-stack-prometheus-node-exporter-ffckd        1/1     Running   0          56s
prometheus-kube-prometheus-stack-prometheus-0               2/2     Running   0          50s
```

## Deploy Harvest on EKS
Now that you have Prometheus and Grafana running, you are ready to deploy Harvest to monitor your FSx for ONTAP file system.

### Input Parameters

|Parameter|Description| 
|:---|:---| 
|fsx.managment\_lif|The FSx for NetApp ONTAP file system management IP.|
|fsx.username|The username that Harvest will use to authenticate to the FSx for ONTAP file system with. It will default to 'fsxadmin'. Note that since Harvest does not support using AWS secrets it is recommended that you use an account that has been assigned the fsxadmin-readonly role.|
|fsx.password|The password that Harvest will use to authenticate with the FSx for ONTAP file system. |
|prometheus|Is the release name of the Prometheus instance you want to use to store the monitoring data.|

### Installation
To install Harvest helm chart from the Prometheus Community GitHub repository you will first need to copy the
contents that are part of this repository to your local system. It will probably be easier to just clone the
entire repo by running the follow command as opposed to copying the files individually:
```bash
git clone https://github.com/NetApp/FSx-ONTAP-samples-scripts.git
```
Then navigate to this sample's directory:
```
cd FSx-ONTAP-samples-scripts/Monitoring/monitor_fsxn_with_harvest_on_eks/HelmChart
```
Ran the command below after making the following substitutions:
* \<usernname> - The username you want Harvest to use to authenticate with the FSxN file system. The default is 'fsxadmin'.
* \<password> - The password you want Harvest to use to authenticate with the FSxN file system.
* \<managment\_lif> - The IP address, or DNS hostname, of the FSx for ONTAP file system management endpoint. You can get this information from the AWS console.
* \<prometheus> - The release name of the Prometheus instance you want to use to store the monitoring data. If you used the command above to install Prometheus, this will be 'kube-prometheus-stack'.

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm upgrade --install harvest -f values.yaml ./ --namespace=harvest --create-namespace --set fsx.managment_lif=<managment_lif> \
    --set fsx.username=<username>  --set fsx.password=<password> --set prometheus=<prometheus>
```

:bulb: **Tip:** Put the above commands in your favorite text editor and make the substitutions there. Then copy and paste the commands into the terminal.

A successful installation should look like this:
```bash
$ helm upgrade --install harvest -f values.yaml ./ --namespace=harvest --create-namespace --set fsx.managment_lif=198.19.255.245 --set fsx.username=fsxadmin  --set fsx.password=redacted --set prometheus=kube-prometheus-stack
Release "harvest" does not exist. Installing it now.
NAME: harvest
LAST DEPLOYED: Mon Jul 29 22:49:57 2024
NAMESPACE: harvest
STATUS: deployed
REVISION: 1
TEST SUITE: None
```

Once the deployment is complete, Harvest should be listed as a target on Prometheus.

After installation, if you installed Grafana with the steps above, you can access it by running the following command:
```bash
kubectl port-forward -n prometheus $(kubectl -n prometheus get pods | grep kube-prometheus-stack-grafana | awk '{print $1}') 3000 &
```
Then open your browser and navigate to `http://localhost:3000` and login with the default username and password (admin/prom-operator).

If you 'ssh'ed into the server where you ran the above command, you'll need to forward port 3000 to that server. You can do that by running the following command from your local machine:
```bash
ssh -L 3000:localhost:3000 -N -f <server>
```
Where `<server>` is the server you are connecting to.

Notes:
* The -L option specifies the port forwarding. The first number is the port on the local machine. The second part is the hostname to setup the port forwarding on, where `localhost` means the local system. The third part is the port of the remote server.
* The -N option tells ssh not to execute a remote command.
* The -f option tells ssh to go into the background just before command execution.
* This works from a Linux or Mac system. If you are using Windows, you will need to have WSL installed and run the command from there.
* If you also have to provide an -i option to provide authenticat, as well as an -l option to specify a specific user, you'll also need to provide those options as well.

To provide a more permanent access, you can create a load balancer service for Grafana. You can read more about how to do that
[here](https://aws.amazon.com/blogs/containers/exposing-kubernetes-applications-part-1-service-and-ingress-resources/).
    
### Adding Grafana dashboards and visualize your FSxN metrics on Grafana
There are a few sample dashboards in the `dashboards` folder that you can import into Grafana to visualize the metrics that Harvest is collecting.
* [How to import Grafana dashboards.](https://grafana.com/docs/grafana/latest/dashboards/build-dashboards/import-dashboards/)
* [Supported Harvest Dashboards.](https://netapp.github.io/harvest/24.05/prepare-fsx-clusters/#supported-harvest-dashboards/)
### Notes
1. When importing the dashboard, be sure to select the Prometheus data source that you are using to store the metrics.
2. The FSxN fsxadmin user does not have full permission to collect all metrics. Because of that some traditional ONTAP dashboards may not fully populate.
3. Currently, Harvest only supports one FSxN per deployment. If you have more than one FSxN, you should create a separate deployment for each.
4. The fsxadmin user password exists in the Harvest config map due to Harvest limitation (i.e. it can't be configured to use an AWS secret).

### Screenshots
Here are some screenshots of the Grafana dashboards that are included in the `dashboards` folder.
![Screenshots 1](./images/image1.png)

![Screenshots 2](./images/image2.png)
