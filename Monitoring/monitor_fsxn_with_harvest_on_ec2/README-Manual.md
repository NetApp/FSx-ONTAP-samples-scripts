# Deploy NetApp Harvest on EC2

Harvest installation for monitoring Amazon FSxN using Prometheus and Grafana stack, integrating AWS Secret Manager for FSxN credentials.

## Introduction

### What to Expect

Harvest installation will result in the following:
* Install NetApp Harvest with the latest version on your EC2 instance.
* Collecting metrics about your FSxNs and adding existing Grafana dashboards for better visualization.

### Prerequisites
* A FSx for ONTAP file system running in the same VPC as the EC2 instance.
* If not running an AWS based Linux, ensure that the `aws` command has been installed and configured.

## Installation Steps

### 1. Create AWS Secret Manager with Username and Password for each FSxN
Since this solution uses an AWS Secrets Manager secret to authenticate with the FSx for ONTAP file system
you will need to create a secret for each FSxN you want to monitor. You can use the following command to create a secret:

```sh
aws secretsmanager create-secret --name <YOUR-SECRET-NAME> --secret-string '{"username":"fsxadmin","password":"<YOUR-PASSWORD>"}'
```

### 2. Create Instance Profile with Permission to AWS Secret Manager and CloudWatch metrics

#### 2.1. Create Policy

Edit the harvest-policy.json file found in this repo with the ARN of the AWS Secret Manager secrets created above.
If you only have one FSxN and therefore only one secret, remove the comma after the one secret ARN (i.e. the last
entry should not have a comma after it).

```
{
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret",
        "secretsmanager:ListSecrets"
      ],
      "Resource": [
        "<your_secret_1_arn>",
        "<your_secret_2_arn>"
      ]
    },
    {
      "Effect": "Allow",
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
        "storagegateway:ListTagsForResource",
        "iam:ListAccountAliases"
      ],
      "Resource": [
        "*"
      ]
    }
  ],
  "Version": "2012-10-17"
}
```

Run the following command to create the policy and obtain the policy ARN:
```sh
POLICY_ARN=$(aws iam create-policy --policy-name harvest-policy --policy-document file://harvest-policy.json --query Policy.Arn --output text)
```

#### 2.2. Create Instance Profile Role

Run the following commands to create the instance profile role and attach the policy to it:
```sh
aws iam create-role --role-name HarvestRole --assume-role-policy-document file://trust-policy.json
aws iam attach-role-policy --role-name HarvestRole --policy-arn $POLICY_ARN
aws iam create-instance-profile --instance-profile-name HarvestProfile
aws iam add-role-to-instance-profile --instance-profile-name HarvestProfile --role-name HarvestRole
```

Note that the `trust-policy.json` file can be found in this repo.

### 3. Create EC2 Instance

We recommend using a `t2.xlarge` or larger instance type with at least 20GB disk.

Once you have created your ec2 instance, you can use the following command to attach the instance profile:

```sh
aws ec2 associate-iam-instance-profile --instance-id <INSTANCE-ID> --iam-instance-profile Arn=<Instance-Profile-ARN>,Name=HarvestProfile
```
You should get the instance profile ARN from step 2.2 above.

If your exiting ec2 instance already had an instance profile, then simply add the policy create in step 2.2 above to its instance profile role.

### 4. Install Docker and Docker Compose

To install Docker use the following commands if you are running an Red Hat based Linux:
```sh
sudo yum install docker
sudo systemctl start docker
sudo systemctl enable docker
```
If you aren't running a Red Hat based Linux, you can follow the instructions [here](https://docs.docker.com/engine/install/).

Install Docker Compose:
```text
LATEST_COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | jq -r '.tag_name')
ARCH=$(uname -m)
if [ -z "$ARCH"  -o -z "$LATEST_COMPOSE_VERSION" ]; then
  echo "Error: Unable to determine latest version or architecture."
else
  sudo curl -s -L "https://github.com/docker/compose/releases/download/$LATEST_COMPOSE_VERSION/docker-compose-linux-$ARCH" -o /usr/local/bin/docker-compose
  sudo chmod +x /usr/local/bin/docker-compose
  # Create a symlink in /usr/bin for more accessibility.
  [ ! -L /usr/bin/docker-compose ] && sudo ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose
fi
```

To confirm that docker has been installed correctly, run the following command:

```sh
sudo docker run hello-world
```

You should get output similar to the following:
```
Hello from Docker!
This message shows that your installation appears to be working correctly.

To generate this message, Docker took the following steps:
 1. The Docker client contacted the Docker daemon.
 2. The Docker daemon pulled the "hello-world" image from the Docker Hub.
    (amd64)
 3. The Docker daemon created a new container from that image which runs the
    executable that produces the output you are currently reading.
 4. The Docker daemon streamed that output to the Docker client, which sent it
    to your terminal.

To try something more ambitious, you can run an Ubuntu container with:
 $ docker run -it ubuntu bash

Share images, automate workflows, and more with a free Docker ID:
 https://hub.docker.com/

For more examples and ideas, visit:
 https://docs.docker.com/get-started/
```

### 5. Install Harvest on EC2

Preform the following steps to install Harvest on your EC2 instance:

#### 5.1. Generate Harvest Configuration File

Modify the `harvest.yml` found in this repo with your clusters details. You should just have to change the `<FSxN_ip_X>` with the IP addresses of your FSxNs.
Add as many pollers as you need to monitor all your FSxNs. There should be an AWS Secrets Manager secret for each FSxN.

Note in the example below, it has places for two FSxN. If you only have one, remove the "fsx02" section.

```yaml
Exporters:
    prometheus1:
        exporter: Prometheus
        port_range: 12990-14000
        add_meta_tags: false
Defaults:
    use_insecure_tls: true
Pollers:
    fsx01:
        datacenter: fsx
        addr: <FSxN_ip_1>
        collectors:
            - Rest
            - RestPerf
            - Ems
        exporters:
            - prometheus1
        credentials_script:
          path: /opt/fetch-credentails
          schedule: 3h
          timeout: 10s
    fsx02:
        datacenter: fsx
        addr: <FSxN_ip_2>
        collectors:
            - Rest
            - RestPerf
            - Ems
        exporters:
            - prometheus1
        credentials_script:
          path: /opt/fetch-credentails
          schedule: 3h
          timeout: 10s
```

#### 5.2. Generate a Docker Compose from Harvest Configuration

Run the following command to generate a Docker Compose file from the Harvest configuration:

```sh
docker run --rm \
  --env UID=$(id -u) --env GID=$(id -g) \
  --entrypoint "bin/harvest" \
  --volume "$(pwd):/opt/temp" \
  --volume "$(pwd)/harvest.yml:/opt/harvest/harvest.yml" \
  ghcr.io/netapp/harvest \
  generate docker full \
  --output harvest-compose.yml
```

:warning: Ignore the command that it outputs that it says will start the cluster.

#### 5.3. Replace Harvest images in the harvest-compose.yml:

Replace the Harvest image with one that supports using AWS Secret Manager for FSxN credentials:

```yaml
sed -i 's|ghcr.io/netapp/harvest:latest|ghcr.io/tlvdevops/harvest-fsx:latest|g' harvest-compose.yml
```

#### 5.4. Add AWS Secret Manager Names to Docker Compose Environment Variables

Edit the `harvest-compose.yml` file by adding the "environment" section for each FSxN with the two variables: `SECRET_NAME` and `AWS_REGION`.
These environment variables are required for the credentials script.

For example:
```yaml
services:
  fsx01:
    image: ghcr.io/tlvdevops/harvest-fsx:latest
    container_name: poller-fsx01
    restart: unless-stopped
    ports:
      - "12990:12990"
    command: '--poller fsx01 --promPort 12990 --config /opt/harvest.yml'
    volumes:
      - ./cert:/opt/harvest/cert
      - ./harvest.yml:/opt/harvest.yml
      - ./conf:/opt/harvest/conf
    environment:
      - SECRET_NAME=<your_secret_name>
      - AWS_REGION=<region_where_secret_resides>
    networks:
      - backend
```
#### 5.5. Download FSxN dashboards and import into Grafana container:
The following commands will download the FSxN designed dashboards from this repo and replace the default Grafana dashboards with them:
```yaml
wget https://raw.githubusercontent.com/NetApp/FSx-ONTAP-samples-scripts/main/Monitoring/monitor_fsxn_with_harvest_on_ec2/fsx_dashboards.zip
unzip fsx_dashboards.zip
rm -rf grafana/dashboards
mv dashboards grafana/dashboards
```

#### 5.6. Configure Prometheus to use yet-another-exporter (yace) to gather AWS FSxN metrics
AWS has useful metrics regarding the FSxN file system that ONTAP doesn't provide. Therefore, it is recommended to install
an exporter that will expose these metrics. The following steps show how to install a recommended exporter.

##### 5.6.1 Create the yace configuration file.
Edit the `yace-config.yaml` file found in this repo and replace `<aws_region>`, in both places, with the region where your FSxN resides:
```yaml
apiVersion: v1alpha1
sts-region: <aws_region>
discovery:
  jobs:
    - type: AWS/FSx
      regions: [<aws_region>]
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
        - name: CPUUtilization
          statistics: [Average]
```

##### 5.6.2 Add Yet-Another-Exporter to harvest-compose.yaml

Copy the following to the end of the `harvest-compose.yml` file:
```yaml
  yace:
    image: quay.io/prometheuscommunity/yet-another-cloudwatch-exporter:latest
    container_name: yace
    restart: always
    expose:
      - 8080
    volumes:
      - ./yace-config.yaml:/tmp/config.yml
      - $HOME/.aws:/exporter/.aws:ro
    command:
      - -listen-address=:8080
      - -config.file=/tmp/config.yml
    networks:
      - backend
```

##### 5.6.3. Add Yet-Another-Exporter target to prometheus.yml:
```yaml
sudo sed -i -e "\$a\- job_name: 'yace'" -e "\$a\  static_configs:" -e "\$a\    - targets: ['yace:8080']" container/prometheus/prometheus.yml
```

##### 6. Bring Everything Up

```sh
sudo docker-compose -f prom-stack.yml -f harvest-compose.yml up -d --remove-orphans
```

After bringing up the prom-stack.yml compose file, you can access Grafana at 
http://IP_OF_GRAFANA:3000.

You will be prompted to create a new password the first time you log in. Grafana's default credentials are:
```
username: admin
password: admin
```

## Adding additional FSx for ONTAP file systems.
If you need to add additional FSxN file systems to monitor after the initial installation,
you can do so by following the steps mentioned at the bottom of the [CloudFormation deployment](README.md) version of this read me file.

---

## Author Information

This repository is maintained by the contributors listed on [GitHub](https://github.com/NetApp/FSx-ONTAP-utils/graphs/contributors).

## License

Licensed under the Apache License, Version 2.0 (the "License").

You may obtain a copy of the License at [apache.org/licenses/LICENSE-2.0](http://www.apache.org/licenses/LICENSE-2.0).

Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an _"AS IS"_ basis, without WARRANTIES or conditions of any kind, either express or implied.

See the License for the specific language governing permissions and limitations under the License.

© 2025 NetApp, Inc. All Rights Reserved.
