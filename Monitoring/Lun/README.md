# LUN Monitoring

## Introduction

The solution provide the ability to export LUN metrics into CloudWatch. It export the Latency, Iops and Throughput metrics. The solution is per FileSystem
The solution is based on a CloudFormation template that need to be deployed per FileSystem. The template creates the following resourcess

1. Lambda - the unit that monitor the FileSystem and add the metrics.
2. Scheduler - AWS EventBridge scheduler that thrigger the Lambda every minute.
3. Dashboard - CloudWatch desbaord that show 10 widgets. 9 widgets per metric (Latency, Iops, Throughput - Read, Write and Total) and 1 widget that show top 5 luns with highest throuput.
4. Lambda Role - IAM role that allow the Lambda to run.
5. Scheduler Role - IAM role that allow the scheduler to tirgger the lambda.
6. SecretManager endpoint (optional) - as the Lambda run inside the vpc, by default it will not have outgoing connectivity , so it need to have VPC endpint to the SecretManager service. User can decide either to create it without the CloudFormation or via the CloudFormation.
7. CloudWatch endpoint (optional) - as the Lambda run inside the vpc, by default it will not have outgoing connectivity , so it need to have VPC endpint to the CloudWatch service. User can decide either to create it without the CloudFormation or via the CloudFormation.
8. SecretManager secret (optional) - in order to send to the FileSystem ONTAP REST APIs commands, the Lambda needs the ONTAP credentials. the Lambda is desgined to take the password from a secret. User can either provide existing ARN with a key name, or to mark that the CloudFormation template will generate a secret.

## Prerequisites

* You must have an AWS Account with necessary permissions to create and manage resources
## Usage

In order to use the solution, you will need to run the CloudFomration template in your AWS accout.
The CloudFormation parameters are:

1. FileSystemId (Mandatory) - the id of the FileSystem .
2. Subnet IDs - the Subnet ids that the lambda will run - the subnets need to have connectivity to the FileSystem.
3. Security Group IDs (Mandatory) - the SecurityGroup ids that the lambda will be associated when running - they need to provide connectivity to the FileSystem.
4. VPC ID (Mandatory) - the VPC that the Lambda will run.
5. Create Secret Manager Endpoint (Not mandatory) - flag if to create SecretManager VPC endpoint inside the VPC.
6. Create CloudWatch Endpoint (Not mandatory) - flag if to create CloudWatch VPC endpoint inside the VPC.
7. Create Secret for the password - flag if to create SecretManager secret. In case that it marked as true, the parameter FSX admin password is mandatory.
8. FSX admin password - the fsxadmin password. in case that the user decided to create Secretmanager secret this parameter is mandatory.
9. Secret Manager FSX admin password ARN - in case the user already created secret for the Lambda and didnt mark to create secret ARN , this parameter is mandatory.
10. Secret Manager FSX admin password key - the key of the fsxadmin secret password, if the user didnt mark to create secret ARN , this parameter is mandatory.

## Author Information

This repository is maintained by the contributors listed on [GitHub](https://github.com/NetApp/FSxN-Samples/graphs/contributors).

## License

Licensed under the Apache License, Version 2.0 (the "License").

You may obtain a copy of the License at [apache.org/licenses/LICENSE-2.0](http://www.apache.org/licenses/LICENSE-2.0).

Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" basis, without WARRANTIES or conditions of any kind, either express or implied.

See the License for the specific language governing permissions and limitations under the License.
