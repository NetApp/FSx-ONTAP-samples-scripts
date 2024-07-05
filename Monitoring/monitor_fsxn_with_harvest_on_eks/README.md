# Deploy NetApp Harvest on EKS 

Harvest helm chart for monitoring Amazon FSxN on existing monitoring stack.

## Introduction

### What to expect

Harvest Helm chart installation will result the following:
* Install NetApp Harvest with latest version on your EKS
* Collecting metrics about your FSxN and adding existing Grafana dashboards for better visualization.

### Prerequisites
* `Helm` - for resources installation.
* NetApp FSxN running on the same EKS VPC.
* Existing `Prometheus` running on your EKS cluster.
* Existing `Grafana` running on your EKS cluster.

### Deployment
### User Input

|Parameter|Description| 
|:---|:---| 
|fsx.managment_lif|FSx for NetApp ONTAP filesystem management IP.|
|fsx.password|fsxadmin user password.|
|prometheus|Existing Prometheus name for discovering.|

### Installation
Install Harvest helm chart from this GitHub repository. The custom Helm chart includes:
* `deployment.yaml` - Harvest deployment using Harvest latest version image.
* `harvest-config.yaml` - Harvest backend configuration.
* `service-monitor.yaml` - Prometheus ServiceMonitor for collecting Harvest metrics.

```bash
helm upgrade --install harvest -f values.yaml ./ --namespace=harvest --create-namespace --set fsx.managment_lif=<managment_lif> --set fsx.password=<password> --set prometheus=<prometheus>
```
The `--namespace harvest` and `--create-namespace` flags instruct helm to create the harvest namespace (if needed), and deploy the Harvest on it.
The --set `fsx.managment_lif=<managment_lif>` and --set `fsx.password=<password>` flags instruct Harvest to use your FSxN credentials for collecting metrics.
The --set `prometheus=<prometheus>` will use for Prometheus ServiceMonitor.

Once the deployment is complete, Harvest should be listed as a target on Prometheus.
    
### Adding Grafana dashboards and visualize your FSxN metrics on Grafana
Import existing dashboards into your Grafana:
* [How to import Grafana dashboards.](https://grafana.com/docs/grafana/latest/dashboards/build-dashboards/import-dashboards/)
* [Supported Harvest Dashboards.](https://netapp.github.io/harvest/24.05/prepare-fsx-clusters/#supported-harvest-dashboards/)
* Example dashboards for Grafana are located in the dashboards folder.
### Notes
1. Currently, Harvest only supports one FSxN per deployment. If you have more than one FSxN, you should create a separate deployment for each.
2. The fsxadmin user password exists in the Harvest config map due to Harvest limitation (i.e. it can't be configured to use an AWS secret).
3. The FSxN fsxadmin user does not have full permission to collect all metrics. So, some traditional ONTAP dashboards may not fully populate.

### Screenshots

![Screenshots 1](./images/image1.png)

![Screenshots 2](./images/image2.png)
