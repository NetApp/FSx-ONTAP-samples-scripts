# Deploy NetApp Harvest on EKS 

This subfolder contains a Helm chart to install [NetApp Harvest](https://github.com/NetApp/harvest/blob/main/README.md)
into an AWS EKS cluster to monitor multiple FSx for ONTAP file systems using the
Grafana + Prometheus stack. It uses the AWS Secrets Manager to obtain
credentials for the FSxN file systems so those credentials aren't insecurely stored.

## Introduction

### What to expect

Harvest Helm chart installation will result the following:
* Install NetApp Harvest with latest version on your EKS
* Each FSxN cluster will represent as Kubernetes pod on the cluster.
* Collecting metrics about your FSxNs and adding existing Grafana dashboards for better visualization.

### Prerequisites
* `Helm` - for resources installation.
* An FSx for ONTAP file system deployed in the same VPC as the EKS cluster.
* Existing `Secrets Manager`secret in the same region as the FSxN file system.
* Existing `Prometheus` running on your EKS cluster.
* Existing `Grafana` running on your EKS cluster.

**NOTE:** You can install both Prometheus and Grafana using this [Helm chart](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack).

### Deployment
### User Input

Parameter | Description | 
--- | --- | 
fsxs.clusters.name | FSxN cluster name | 
fsxs.clusters.managment_lif | FSxN for NetApp ONTAP filesystem management IP |
fsxs.clusters.secretName | AWS Secrets Manager for FSxN credentials |
fsxs.clusters.region | FSxN and AWS Secrets Manager region |
fsxs.clusters.promPort | Which port harvest will be created and exposed to Promethues |
promethues | Existing Promethues name for discovering |

### Integration with AWS Secrets Manager

The installation supports integration with AWS Secrets Manager. You can store your FSxN credentials by using existing or new AWS Secrets Manager. 
Harvest will invoke script specified in the credentials_script path section which already mapped to Harvest container.
Harvest uses ServiceAccount with permissions to fetch the secrets. 
Credentails script expect to fetch `USERNAME`, `PASSWORD` values from Secrets Manager.
ServiceAccount should be created during the installation with the sufficient permissions. 


### Monitoring multiples FSxN

The Helm chart supports monitoring multiple FSxNs.
You can add multiples FSxNs by configure it on `values.yaml`:
For example: 
```
fsxs:
  clusters:
    - name: fsx1
      managment_lif: <FSx1_Management_LIF>
      promPort: 12990
      secretName: <FSx1_secret_name>
      region: <FSx1_region>
    - name: fsx2
      managment_lif: <FSx2_Management_LIF>
      promPort: 12991
      secretName: <FSx2_secret_name>
      region: <FSx2_region>
```
**NOTE:** Each FSxN cluster should have unique port number for promPort.

### Installation
Install Harvest helm chart from this GitHub repository. The custom Helm chart includes:
* `deplyment.yaml` - Harvest deployment using Harvest latest version image
* `harvest-config.yaml` - Harvest backend configuration
* `harvest-cm.yaml` -  Environment variables configuration for credentails script.
* `service-monitor.yaml` - Promethues ServiceMonitor for collecting Harvest metrics.

1. **Create AWS Secrets Manager for FSxN credentials**
If you don't already have an AWS Secrets Manager secret for your FSxN credentials, you can create one using the AWS CLI.
```
aws secretsmanager create-secret \
  --region <REGION> \
  --name <SECRET_NAME> \
  --secret-string '{"USERNAME":"fsxadmin", "PASSWORD":"<YOUR_FSX_PASSWORD>"}'
```

2. **Create ServiceAccount with permissions to AWS Secrets Manager**

**Create Policy with permissions to AWS secretsmanager:**

The following IAM policy can be used to grant the all permissions required by Harvest to fetch the secrets:

```
{
    "Statement": [
        {
            "Action": [
                "secretsmanager:GetSecretValue",
                "secretsmanager:DescribeSecret",
                "secretsmanager:ListSecrets"
            ],
            "Effect": "Allow",
            "Resource": [
                "<your_secret_manager_arn_1>",
                "<your_secret_manager_arn_2>"
            ]
        }
    ],
    "Version": "2012-10-17"
}

```
You can use the following command to create the policy:

POLICY_ARN=$(aws iam create-policy --policy-name harvest_read_secrets --policy-document file://harvest-read-secrets-policy.json --query Policy.Arn --output text)

Note that this creates a variable named `POLICY_ARN` that you will use in the next step.    

**Create ServiceAccount**:

**note**: If you don't already have a namespace where you want to deploy Harvest, you can create one using the following command:
```
kubectl create ns <NAMESPACE>
```

To create the ServiceAccount, run the following command:
```
eksctl create iamserviceaccount --name harvest-sa --region=<REGION> --namespace <NAMESPACE> --role-name harvest-role --cluster <YOUR_CLUSTER_NAME> --attach-policy-arn "$POLICY_ARN" --approve
```

3. **Install Harvest helm chart**
```text
helm upgrade --install harvest  -f values.yaml ./ --namespace=<NAMESPACE> --set promethues=<your_promethues_release_name>
```

Once the deployment is complete, Harvest should be listed as a target on Prometheus.

### Import FSxN CloudWatch metrics into your monitoring stack using YACE
AWS provides FSx for ONTAP metrics which cannot be collected by Harvest. Therefore, we recommend to
use yet-another-exporter (by Prometheus community) for collecting metrics from CloudWatch. See [YACE](https://github.com/nerdswords/helm-charts) for more information.

#### Installation #### 
1. **Create ServiceAccount with permissions to AWS CloudWatch**
The following IAM policy can be used to grant the all permissions required by yet-another-exporter to fetch the CloudWatch metrics:

```
{
    "Version": "2012-10-17",
    "Statement": [
      {
        "Action": [
          "tag:GetResources",
          "cloudwatch:GetMetricData",
          "cloudwatch:GetMetricStatistics",
          "cloudwatch:ListMetrics",
          "apigateway:GET",
          "aps:ListWorkspaces",
          "autoscaling:DescribeAutoScalingGroups",
          "dms:DescribeReplicationInstances",
          "dms:DescribeReplicationTasks",
          "ec2:DescribeTransitGatewayAttachments",
          "ec2:DescribeSpotFleetRequests",
          "shield:ListProtections",
          "storagegateway:ListGateways",
          "storagegateway:ListTagsForResource"
        ],
        "Effect": "Allow",
        "Resource": "*"
      }
    ]
  }

```
Run the following command in order to create the policy:

POLICY_ARN=$(aws iam create-policy --policy-name yace-exporter-policy --policy-document file://yace-exporter-policy.json --query Policy.Arn --output text)

2. **Create ServiceAccount**:

**note**: namespace should be already exists\
if not exist use the following command: 
```
kubectl create ns <NAMESPACE>
```
```
eksctl create iamserviceaccount --name yace-exporter-sa --region=<REGION> --namespace <NAMESPACE> --role-name yace-cloudwatch-exporter-role --cluster <YOUR_CLUSTER_NAME> --attach-policy-arn "$POLICY_ARN" --approve
```

3. **Install yace-exporter helm chart**

```text
helm repo add nerdswords https://nerdswords.github.io/helm-charts
```

Change the prometheus release name for ServiceMonitor creation in the yace-override-values.yaml file:
```
serviceMonitor:
  enabled: true
  labels:
    release: <Prometheus_Name>
```

Also apply the region name to FSxN's region in yace-override-values.yaml:
```
  apiVersion: v1alpha1
  sts-region: <Region_Name>
  discovery:
    jobs:
    - type: AWS/FSx
      regions:
        - <Region_Name>
      period: 300
      length: 300
      metrics:
      - name: DiskReadOperations
        statistics: [Average]
      - name: DiskWriteOperations
        statistics: [Average]
      - name: DiskReadBytes
        statistics: [Average]
      - name: DiskWriteBytes
        statistics: [Average]
      - name: DiskIopsUtilization
        statistics: [Average]
      - name: NetworkThroughputUtilization
        statistics: [Average]
      - name: FileServerDiskThroughputUtilization
        statistics: [Average]
```

Run the following command to install the yace-exporter helm chart:
```text
helm install nerdswords/yet-another-cloudwatch-exporter -f yace-override-values.yaml
```

### Adding Grafana dashboards and visualize your FSxN metrics on Grafana
Import existing dashboards into your Grafana:
* [How to import Grafana dashboards](https://grafana.com/docs/grafana/latest/dashboards/build-dashboards/import-dashboards/)
* Example dashboards for Grafana are located in the dashboards folder
#### Note
 fsxadmin user does not have a full permission to collect all metrics by default.
