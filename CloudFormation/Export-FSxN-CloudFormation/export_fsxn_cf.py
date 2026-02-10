#!/bin/python3
#
# This script takes an FSx for ONTAP file system ID as input and generates
# a CloudFormation template for the file system, its volumes, and its
# storage virtual machines. The output is printed to the console in JSON format.
################################################################################

import json
import boto3
import sys
import optparse
#
# Get the file system ID from the command line
parser = optparse.OptionParser()
parser.add_option('-f', dest='filesystemId', help='The ID of the FSx for ONTAP file system to generate the CloudFormation template for.')
parser.add_option('-n', dest='nameAppend', help='A string to append to the names of the resources in the CloudFormation template to make them unique. This is optional.')
opts, args = parser.parse_args()

if opts.filesystemId is None:
    print("Error: --filesystem-id is required", file=sys.stderr)
    sys.exit(1)
filesystemId = opts.filesystemId
nameAppend = opts.nameAppend if opts.nameAppend is not None else ""
#
# Create boto3 client for fsx and ec2.
fsxClient = boto3.client('fsx')
ec2Client = boto3.client('ec2')
#
# Get the file system details
response = fsxClient.describe_file_systems(FileSystemIds=[filesystemId])
if response.get('FileSystems') is None or len(response['FileSystems']) == 0:
    print(f"No file system found with ID {filesystemId}", file=sys.stderr)
    sys.exit(1)
#
# Build the CloudFormation template for the file system
cfTemplate = {
    "Description": f"FSx File System template for {filesystemId}.",
    "Resources": {}
}
cfTemplate['Parameters'] = {
    "fsxadminPassword": {
        "Type": "String",
        "Description": "The AWS Secrets Manager secret that has the password for the fsxadmin user. It should have a key named 'password' that contains the password."
    }
}
fileSystem = response['FileSystems'][0]
fsCfTemplate = {}
fsCfTemplate['Type'] = 'AWS::FSx::FileSystem'
fsCfTemplate['Properties'] = {}
for prop in ['NetworkType', 'FileSystemType', 'KmsKeyId', 'StorageCapacity', 'SubnetIds', 'StorageType', 'Tags']:
    if prop in fileSystem:
        fsCfTemplate['Properties'][prop] = fileSystem[prop]
#
# Get the security groups from the ENIs.
fsCfTemplate['Properties']['SecurityGroupIds'] = []
securityGroups = {} # Use a dictionary to store the security groups to avoid duplicates.
response = ec2Client.describe_network_interfaces(NetworkInterfaceIds=fileSystem['NetworkInterfaceIds'])
for eni in response['NetworkInterfaces']:
    for group in response['NetworkInterfaces'][0]['Groups']:
        securityGroups[group['GroupId']] = 1
for group in securityGroups.keys():
    fsCfTemplate['Properties']['SecurityGroupIds'].append(group)
#
# Copy the ONTAP configuration.
fsCfTemplate['Properties']['OntapConfiguration'] = {"FsxAdminPassword": {"Fn::Sub": "{{resolve:secretsmanager:${fsxadminPassword}:SecretString:password}}"}}
for prop in ['AutomaticBackupRetentionDays', 'DailyAutomaticBackupStartTime', 'DeploymentType',
                 'EndpointIpAddressRange', 'EndpointIpv6AddressRange', 'PreferredSubnetId', 'RouteTableIds', 
                 'WeeklyMaintenanceStartTime', 'HAPairs', 'ThroughputCapacityPerHAPair']:
    if prop in fileSystem['OntapConfiguration']:
        fsCfTemplate['Properties']['OntapConfiguration'][prop] = fileSystem['OntapConfiguration'][prop]
if fileSystem['OntapConfiguration']['DiskIopsConfiguration']['Mode'] == 'AUTOMATIC':
    fsCfTemplate['Properties']['OntapConfiguration']['DiskIopsConfiguration'] = {'Mode': 'AUTOMATIC'}
else:
    fsCfTemplate['Properties']['OntapConfiguration']['DiskIopsConfiguration'] = fileSystem['DiskIopsConfiguration']
#
# If using the default endpoint IP address range, remove it from the
# CloudFormation template since AWS will automatically use a new default
# address range if the 'EndpointIpAddressRange' is not specified.
if 'EndpointIpAddressRange' in fsCfTemplate['Properties']['OntapConfiguration']:
    if fsCfTemplate['Properties']['OntapConfiguration']['EndpointIpAddressRange'].startswith("198.18"):
        del fsCfTemplate['Properties']['OntapConfiguration']['EndpointIpAddressRange']
    else:
        cfTemplate['Parameters']['endpointIpAddressRange'] = {
             "Type": "String",
             "Description": "The IP address range to use for the file system's endpoints.",
             "Default": fsCfTemplate['Properties']['OntapConfiguration']['EndpointIpAddressRange']
             }
        fsCfTemplate['Properties']['OntapConfiguration']['EndpointIpAddressRange'] = {"Ref": "endpointIpAddressRange"}

cfTemplate['Resources'].update({filesystemId.replace("-", ""): fsCfTemplate})
#
# Get all the volumes for the file system. Getting the volumes before the SVMs
# since I need the list of volumes to get the security style of the root volume
# for each SVMs.
response = fsxClient.describe_volumes(Filters=[{'Name': 'file-system-id', 'Values': [filesystemId]}])
volumes = response['Volumes']
for volume in volumes:
    if volume['OntapConfiguration']['StorageVirtualMachineRoot']:
        continue
    volumeCfTemplate = {}
    volumeCfTemplate['Type'] = 'AWS::FSx::Volume'
    volumeCfTemplate['Properties'] = {}
    for property in ['Name', 'VolumeType', 'Tags']:
        if property in volume:
            volumeCfTemplate['Properties'][property] = volume[property]
    volumeCfTemplate['Properties']['Name'] = volumeCfTemplate['Properties']['Name'] + nameAppend

    volumeCfTemplate['Properties']['OntapConfiguration'] = {}
    for property in ['AggregateName', 'CopyTagsToBackups', 'OntapVolumeType', 'SecurityStyle', 'SizeInMegabytes',
                     'StorageEfficiencyEnabled', 'VolumeStyle', 'JunctionPath',
                     'SnapshotPolicy', 'TieringPolicy', 'SnaplockConfiguration']:
        if property in volume['OntapConfiguration']:
            volumeCfTemplate['Properties']['OntapConfiguration'][property] = volume['OntapConfiguration'][property]
    volumeCfTemplate['Properties']['OntapConfiguration']['StorageVirtualMachineId'] = {"Ref" : volume['OntapConfiguration']['StorageVirtualMachineId'].replace("-", "")}
    #
    # DP volumes can't have JunctionPath, StorageEfficiency, SnapshotPolicy or SecurityStyle properties
    if volume['OntapConfiguration']['OntapVolumeType'] == 'DP':
        for prop in ['JunctionPath', 'StorageEfficiencyEnabled', 'SnapshotPolicy', 'SecurityStyle']:
            if prop in volumeCfTemplate['Properties']['OntapConfiguration']:
                print(f"Warning: Volume {volume['Name']} is a DP volume and cannot have the {prop} property, removing it from the CloudFormation template.", file=sys.stderr)
                del volumeCfTemplate['Properties']['OntapConfiguration'][prop]
    else:
        if 'JunctionPath' not in volumeCfTemplate['Properties']['OntapConfiguration']:
            print(f"Warning: Volume {volume['Name']} does not have a junction path yet it is required for a Cloudformation template so setting it to /{volumeCfTemplate['Properties']['Name']}", file=sys.stderr)
            volumeCfTemplate['Properties']['OntapConfiguration']['JunctionPath'] = "/" + volumeCfTemplate['Properties']['Name']

    cfTemplate['Resources'].update({volume['VolumeId'].replace("-", ""): volumeCfTemplate})
#
# Get all the storage virtual machines for the file system.
response = fsxClient.describe_storage_virtual_machines(Filters=[{'Name': 'file-system-id', 'Values': [filesystemId]}])
for svm in response['StorageVirtualMachines']:
    svmCfTemplate = {}
    svmCfTemplate['Type'] = 'AWS::FSx::StorageVirtualMachine'
    svmCfTemplate['Properties'] = {"FileSystemId": {"Ref" : filesystemId.replace("-", "")}}
    for prop in ['ActiveDirectoryConfiguration', 'Name', 'RootVolumeSecurityStyle', 'Tags']:
        if prop in svm:
            svmCfTemplate['Properties'][prop] = svm[prop]
    svmCfTemplate['Properties']['Name'] = svmCfTemplate['Properties']['Name'] + nameAppend

    if 'ActiveDirectoryConfiguration' in svm:
        if len(svmCfTemplate['Properties']['ActiveDirectoryConfiguration']['NetBiosName']) > 10 and len(nameAppend) > 0:
            svmCfTemplate['Properties']['ActiveDirectoryConfiguration']['NetBiosName'] = svmCfTemplate['Properties']['ActiveDirectoryConfiguration']['NetBiosName'][:10] + nameAppend.upper()
        else:
            svmCfTemplate['Properties']['ActiveDirectoryConfiguration']['NetBiosName'] = svmCfTemplate['Properties']['ActiveDirectoryConfiguration']['NetBiosName'] + nameAppend.upper()
        svmCfTemplate['Properties']['ActiveDirectoryConfiguration']['NetBiosName'] = svmCfTemplate['Properties']['ActiveDirectoryConfiguration']['NetBiosName'][:15]
        if 'SelfManagedActiveDirectoryConfiguration' in svm['ActiveDirectoryConfiguration']:
            if 'OrganizationalUnitDistinguishedName' in svm['ActiveDirectoryConfiguration']['SelfManagedActiveDirectoryConfiguration']:
                #
                # Since CF can only handle organizational unit distinguish names that have a
                # parent of OU, we need to check if the parent of the organizational unit is
                # OU and if not, we need to remove the organizational unit distinguish name
                # from the CloudFormation template and print a warning message.
                dnParent=svm['ActiveDirectoryConfiguration']['SelfManagedActiveDirectoryConfiguration']['OrganizationalUnitDistinguishedName'].split(",")[0]
                dnParent = dnParent.split("=")[0]
                if dnParent != "OU":
                    #
                    # The default value from ONTAP is 'CN=Computers' which does not have a
                    # parent of OU, but CF requires that the parent is OU, therefore we will
                    # just ignore the organizational unit distinguish name.
                    if svm['ActiveDirectoryConfiguration']['SelfManagedActiveDirectoryConfiguration']['OrganizationalUnitDistinguishedName'] != "CN=Computers":
                        print(f'Warning: The organizational unit distinguish name for the SVM {svm["Name"]} is "{svm["ActiveDirectoryConfiguration"]["SelfManagedActiveDirectoryConfiguration"]["OrganizationalUnitDistinguishedName"]}" which does not have a parent of a OU and CloudFormation requires that, therefore the distinguished name is ignored. This will cause the SVM to be put into the "default" computer location', file=sys.stderr)
                    del svmCfTemplate['Properties']['ActiveDirectoryConfiguration']['SelfManagedActiveDirectoryConfiguration']['OrganizationalUnitDistinguishedName'] 

            secretParameterId = f'{svm["Name"].replace("-", "").replace("_", "")}AdminCredentials'
            cfTemplate['Parameters'][secretParameterId] = {
                "Type": "String",
                "Description": f"The AWS Secrets Manager secret that has the Active Directory credentials for the {svm['Name']} storage virtual machine. It should have two keys named 'username' and 'passowrd'."
            }
            svmCfTemplate['Properties']['ActiveDirectoryConfiguration']['SelfManagedActiveDirectoryConfiguration']['UserName'] = {"Fn::Sub": "{{resolve:secretsmanager:${" + secretParameterId + "}:SecretString:username}}"}
            svmCfTemplate['Properties']['ActiveDirectoryConfiguration']['SelfManagedActiveDirectoryConfiguration']['Password'] = {"Fn::Sub": "{{resolve:secretsmanager:${" + secretParameterId + "}:SecretString:password}}"}
    #
    # Get the security style for the SVM's root volume. Assume the root volume is <svm_name>_root
    for volume in volumes:
        if volume['OntapConfiguration']['StorageVirtualMachineId'] == svm['StorageVirtualMachineId'] and volume['OntapConfiguration']['StorageVirtualMachineRoot']:
            svmCfTemplate['Properties']['RootVolumeSecurityStyle'] = volume['OntapConfiguration']['SecurityStyle']
            break
    if svmCfTemplate['Properties'].get('RootVolumeSecurityStyle') is None:
        if 'ActiveDirectoryConfiguration' in svmCfTemplate['Properties']:
            svmCfTemplate['Properties']['RootVolumeSecurityStyle'] = 'NTFS'
        else:
            svmCfTemplate['Properties']['RootVolumeSecurityStyle'] = 'UNIX'
        print(f"Warning: Could not find root volume for SVM {svm['Name']}. Setting the security style to {svmCfTemplate['Properties']['RootVolumeSecurityStyle']}.", file=sys.stderr)
    cfTemplate['Resources'].update({svm['StorageVirtualMachineId'].replace("-", ""): svmCfTemplate})

cfTemplate['Outputs'] = {
    "FileSystemId": {
        "Description": "The ID of the FSx for ONTAP file system.",
        "Value": {"Ref": filesystemId.replace("-", "")}
    }
}
# Print the CloudFormation template in JSON format
print(json.dumps(cfTemplate, indent=4))
