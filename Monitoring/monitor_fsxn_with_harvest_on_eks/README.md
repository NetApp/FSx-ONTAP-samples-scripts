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
second and third lines from the above command.

The above will create a 50Gib PVC for Prometheus to use. You can adjust the size as needed.

## Deploy Harvest on EKS

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
cd FSx-ONTAP-samples-scripts/Monitoring/monitoring_fsxn_with_harvest_on_eks
```
Next, run the following commands to install Harvest:
```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm upgrade --install harvest -f values.yaml ./ --namespace=harvest --create-namespace --set fsx.managment_lif=<managment_lif> \
    --set fsx.username=<user>  --set fsx.password=<password> --set prometheus=<prometheus>
```
Where:
* '--namespace=harvest' and '--create-namespace' flags instruct helm to create a namespace named 'harvest' (if needed), and deploy the Harvest on it.
* '<username>' is the username you want Harvest to use to authenticate with the FSxN file system. The default is 'fsxadmin'.
* '<password>' is the password you want Harvest to use to authenticate with the FSxN file system.
* '<managment_lif>' should be the IP address, or DNS hostname, of the FSx for ONTAP file system management endpoint. You can get this information from the AWS console.
* '<prometheus>' is the release name of the Prometheus instance you want to use to store the monitoring data. This should be the same as the Prometheus release name you used when you deployed Prometheus.

Once the deployment is complete, Harvest should be listed as a target on Prometheus.

After installation, if you install Grafana with the steps above, you can access it by running the following command:
```bash
kubectl port-forward svc/harvest-grafana 3000 -n harvest
```
Then open your browser and navigate to `http://localhost:3000` and login with the default username and password (admin/prom-operator).

To provide a more permanent access, you can create a load balancer service for Grafana. You can read more about how to do that
[here](https://aws.amazon.com/blogs/containers/exposing-kubernetes-applications-part-1-service-and-ingress-resources/).
    
### Adding Grafana dashboards and visualize your FSxN metrics on Grafana
Import existing dashboards into your Grafana:
* [How to import Grafana dashboards.](https://grafana.com/docs/grafana/latest/dashboards/build-dashboards/import-dashboards/)
* [Supported Harvest Dashboards.](https://netapp.github.io/harvest/24.05/prepare-fsx-clusters/#supported-harvest-dashboards/)
* Example dashboards for Grafana are located in the `dashboards` folder.
### Notes
1. Currently, Harvest only supports one FSxN per deployment. If you have more than one FSxN, you should create a separate deployment for each.
2. The fsxadmin user password exists in the Harvest config map due to Harvest limitation (i.e. it can't be configured to use an AWS secret).
3. The FSxN fsxadmin user does not have full permission to collect all metrics. Because of that some traditional ONTAP dashboards may not fully populate.

### Screenshots

![Screenshots 1](./images/image1.png)

![Screenshots 2](./images/image2.png)
