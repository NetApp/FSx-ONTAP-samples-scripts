# Deploy NetApp Harvest on EC2

Harvest installation for monitoring Amazon FSxN using Promethues and Grafana stack, integrating AWS Secret Manager for FSxN credentials.

## Introduction

### What to Expect

Harvest installation will result in the following:
* Install NetApp Harvest with the latest version on your EC2 instance.
* Collecting metrics about your FSxNs and adding existing Grafana dashboards for better visualization.

### Prerequisites
* A FSx for ONTAP running in the same VPC.
* If not running an AWS based Linux, ensure that the `aws` command has been instealled and configured.

## Installation Steps

### 1. Create AWS Secret Manager with Username and Password for each FSxN

```sh
aws secretsmanager create-secret --name <YOUR-SECRET-NAME> --secret-string '{"username":"fsxadmin","password":"<YOUR-PASSWORD>"}'
```

### 2. Create Instance Profile with Permission to AWS Secret Manager and cloudwatch metrics

#### 2.1. Create Policy with Permissions to AWS Secret Manager

Edit the harvest-policy.json file found in this repo with the ARN of the AWS Secret Manager secret created above.

```sh
POLICY_ARN=$(aws iam create-policy --policy-name harvest-policy --policy-document file://harvest-policy.json --query Policy.Arn --output text)
```

#### 2.2. Create Instance Profile Role

```sh
aws iam create-role --role-name HarvestRole --assume-role-policy-document file://trust-policy.json
aws iam attach-role-policy --role-name HarvestRole --policy-arn $POLICY_ARN
aws iam create-instance-profile --instance-profile-name HarvestProfile
aws iam add-role-to-instance-profile --instance-profile-name HarvestProfile --role-name HarvestRole
```

Note that the `trust-policy.json` file can be found in this repo.

### 3. Create EC2 Instance

We recommend using a `t2.xlarge` instance type with 20GB disk and attaching the instance profile.

If you already have an ec2 instance, you can use the following command to attach the instance profile:

```sh
aws ec2 associate-iam-instance-profile --instance-id <INSTANCE-ID> --iam-instance-profile Arn=<Instance-Profile-ARN>,Name=HarvestProfile
```
You should get the instance profile ARN from step 2.2 above.

If your exiting ec2 instance already had an instance profile, then simply add the policy create in step 2.2 above.

### 4. Install Docker and Docker Compose

Use the following commands if you are running an Red Hat based Linux:
```sh
sudo yum install docker
sudo curl -L https://download.docker.com/linux/centos/7/x86_64/stable/Packages/docker-compose-plugin-2.6.0-3.el7.x86_64.rpm -o ./compose-plugin.rpm
sudo yum install ./compose-plugin.rpm -y
sudo systemctl start docker
```
If you aren't running a Red Hat based Linux, you can follow the instructions [here](https://docs.docker.com/engine/install/).

To confirm that docker has been installed correctly, run the following command:

```sh
sudo docker run hello-world
```

You should get output similar to the following:
```
Unable to find image 'hello-world:latest' locally
latest: Pulling from library/hello-world
e6590344b1a5: Pull complete
Digest: sha256:bfbb0cc14f13f9ed1ae86abc2b9f11181dc50d779807ed3a3c5e55a6936dbdd5
Status: Downloaded newer image for hello-world:latest

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

To install Harvest on your EC2 instance following the following steps:

#### 5.1. Generate Harvest Configuration File

Create `harvest.yml` file with your cluster details, below is an example with annotated comments. Modify as needed for your scenario:

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

:warning:**NOTE** Ignore the command that it outputs used to start Harvest.

#### 5.3. Replace Harvest images in the harvest-compose.yml:

Replace the Harvest image that supports using AWS Secret Manager for FSxN credentials:

```yaml
sed -i 's|ghcr.io/netapp/harvest:latest|ghcr.io/tlvdevops/harvest-fsx:latest|g' harvest-compose.yml
```

#### 5.4. Add AWS Secret Manager Names to Docker Compose Environment Variables

`SECRET_NAME` and `AWS_REGION` are required for the credentials script.

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
wget https://raw.githubusercontent.com/NetApp/FSx-ONTAP-samples-scripts/main/Monitoring/monitor_fsxn_with_grafana/fsx_dashboards.zip
unzip fsx_dashboards.zip
rm -rf grafana/dashboards
mv dashboards grafana/dashboards
```

#### 5.6. Configure Prometheus to use yet-another-exporter (yace) to gather AWS FSxN metrics
AWS has useful metrics regarding the FSxN file system that ONTAP doesn't provide. Therefore, it is recommended to install
an exporter that will expose these metrics. The following steps show how to install a recommended exporter.

##### 5.6.1 Create the yace configuration file.
Use the text in the box below to create the configuration file named `yace-config.yaml`. Replace `<your_region>`, in both places, with the region where your FSxN resides:

```yaml
apiVersion: v1alpha1
sts-region: <your_region>
discovery:
  jobs:
    - type: AWS/FSx
      regions: [<your_region>]
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
sudo sed -i -e "\$a\- job_name: 'yace'" -e '$a\  static_configs:' -e "\$a\    - targets: ['yace:8080']" container/prometheus/prometheus.yml
```

##### 6. Bring Everything Up

```sh
sudo docker compose -f prom-stack.yml -f harvest-compose.yml up -d --remove-orphans
```

After bringing up the prom-stack.yml compose file, you can access Grafana at 
http://IP_OF_GRAFANA:3000.

You will be prompted to create a new password the first time you log in. Grafana's default credentials are:
```
username: admin
password: admin
```
