#!/bin/python3
#
################################################################################
# This script is used to create a report of all the FSx for ONTAP file systems
# in the AWS account. It will list all the file systems, SVMs, and volumes
# along with their usage information.
#
# By default it will generate an HTML report of all the FSx for ONTAP file
# systems witin the default aws region. However, it can be configured to report
# on all the FSx for ONTAP file systems in all of the AWS regions, or a specific
# set of regions. It can generate either an HTML or text based report.
#
# The following environment variables are used to configure the script:
#   ALL_REGIONS: If set to 'true', the script will report on all the FSxN in
#               all regions.
#   REGIONS: A comma-separated list of regions report on.
#   REPORT_TYPE: If set to 'text', the script will generate a text report. If
#               set to anything else, it will generate an HTML report.
#   TO_ADDRESS: The email address to send the report to. If not set, the report
#              will be output to the console.
#   FROM_ADDRESS: The email address to send the report from. If not set, the
#                report will be output to the console.
################################################################################

import boto3
from botocore.config import Config
import json
from datetime import datetime, timedelta
import argparse
import os

################################################################################
# This function is used to get the value of a tag by its key. It returns 'N/A'
# if the tag is not found.
################################################################################
def getTag(key, tags):
    for tag in tags:
        if tag['Key'] == key:
            return tag['Value']
    return 'N/A'

################################################################################
# This function is used to obtain all the information about the FSx for ONTAP
# including its configuration and usage information.
################################################################################
def getFSxNInfo(region):
    global fsxns, svms, volumes, volumeUsageInfo, fsxnUsageInfo

    fsxns = []
    svms = []
    volumes = []
    #
    # Initialize the FSx client
    fsxClient = boto3.client('fsx', region_name=region)
    cwClient = boto3.client('cloudwatch', region_name=region)
    #
    # Retrieve all FSx for ONTAP file systems
    fsxnData = fsxClient.describe_file_systems()
    for fsxn in fsxnData['FileSystems']:
        if fsxn['FileSystemType'] == 'ONTAP':
            fsxns.append(fsxn)
    next = fsxnData.get('NextToken')
    while next:
        fsxnData = fsxClient.describe_file_systems(NextToken=next)
        for fsxn in fsxnData['FileSystems']:
            if fsxn['FileSystemType'] == 'ONTAP':
                fsxns.append(fsxn)
        next = fsxnData.get('NextToken')
    #
    # Retrieve all the FSxN usage information
    fsxnUsageInfo = {}
    metrics = []
    count = 0
    for fsxn in fsxns:
        fsxnId = fsxn['FileSystemId']
        count += 1
        metrics.append({
                    "Id": f"{fsxnId.replace('fs-', 'm_')}",
                    "MetricStat": {
                        "Metric": {
                            "Namespace": "AWS/FSx",
                            "MetricName": "StorageUsed",
                            "Dimensions": [
                            {
                                "Name": "FileSystemId",
                                "Value": fsxnId
                            },
                            {
                                "Name": "StorageTier",
                                "Value": "SSD"
                            },
                            {
                                "Name": "DataType",
                                "Value": "All"
                            }]
                        },
                        "Period": 300,
                        "Stat": "Average"
                    },
                    "ReturnData": True
                 })
        if count > 100:
            response = cwClient.get_metric_data(MetricDataQueries=metrics,
                StartTime=datetime.now() - timedelta(minutes=10),
                EndTime=datetime.now())
            for metric in response['MetricDataResults']:
                fsxnId = metric['Id'].replace('m_', 'fs-')
                fsxnUsageInfo[fsxnId] = {
                        'UsedCapacity': metric['Values'][0] if len(metric['Values']) > 0 else 'N/A',
                        'StorageCapacity': fsxn['StorageCapacity']}
            count = 0
            metrics = []

    if count > 0:
        response = cwClient.get_metric_data(MetricDataQueries=metrics,
            StartTime=datetime.now() - timedelta(minutes=10),
            EndTime=datetime.now())
        for metric in response['MetricDataResults']:
            fsxnId = metric['Id'].replace('m_', 'fs-')
            fsxnUsageInfo[fsxnId] = {
                    'UsedCapacity': metric['Values'][0] if len(metric['Values']) > 0 else 'N/A',
                    'StorageCapacity': fsxn['StorageCapacity']}
    #
    # Retrieve all the SVMs
    svmsData = fsxClient.describe_storage_virtual_machines()
    for svm in svmsData['StorageVirtualMachines']:
        svms.append(svm)
    next = svmsData.get('NextToken')
    while next:
        svmsData = fsxClient.describe_storage_virtual_machines(NextToken=next)
        for svm in svmsData['StorageVirtualMachines']:
            svms.append(svm)
        next = svmsData.get('NextToken')
    #
    # Retrieve all the FSx for ONTAP volumes
    volumesData = fsxClient.describe_volumes()
    for volume in volumesData['Volumes']:
        if volume.get('OntapConfiguration') is not None:
            volumes.append(volume)
    next = volumesData.get('NextToken')
    while next:
        volumesData = fsxClient.describe_volumes(NextToken=next)
        for volume in volumesData['Volumes']:
            if volume.get('OntapConfiguration') is not None:
                volumes.append(volume)
        next = volumesData.get('NextToken')
    #
    # Sort the volumes by name.
    volumes.sort(key=lambda k: k["Name"].lower())
    #
    # Retrieve the volume usage metrics.
    volumeUsageInfo = {}
    metrics = []
    count=0
    for volume in volumes:
        volId = volume['VolumeId']
        fsxnId = volume['FileSystemId']
        count+=1
        for metric in ['StorageCapacity', 'FilesUsed', 'FilesCapacity']:
            metrics.append({
                    "Id": f"{volId.replace('fsvol-', 'm_')}_{metric}",
                    "MetricStat": {
                        "Metric": {
                            "Namespace": "AWS/FSx",
                            "MetricName": metric,
                            "Dimensions": [
                            {
                                "Name": "FileSystemId",
                                "Value": fsxnId
                            },
                            {
                                "Name": "VolumeId",
                                "Value": volId
                            }]
                        },
                        "Period": 300,
                        "Stat": "Average"
                    },
                    "ReturnData": True
                 })
        for dataType in ['User', 'Other', 'Snapshot']:
            metrics.append({
                    "Id": f"{volId.replace('fsvol-', 'm_')}_StorageUsed_{dataType}",
                    "MetricStat": {
                        "Metric": {
                            "Namespace": "AWS/FSx",
                            "MetricName": "StorageUsed",
                            "Dimensions": [
                            {
                                "Name": "FileSystemId",
                                "Value": fsxnId
                            },
                            {
                                "Name": "VolumeId",
                                "Value": volId
                            },
                            {
                                "Name": "StorageTier",
                                "Value": "All"
                            },
                            {
                                "Name": "DataType",
                                "Value": dataType
                            }]
                        },
                        "Period": 300,
                        "Stat": "Average"
                    },
                    "ReturnData": True
                })

        if count > 70:
            response = cwClient.get_metric_data(MetricDataQueries=metrics,
                StartTime=datetime.now() - timedelta(minutes=10),
                EndTime=datetime.now())
            for metric in response['MetricDataResults']:
                volumeUsageInfo[metric['Id']] = metric
            count=0
            metrics = []

    if count > 0:
        response = cwClient.get_metric_data(MetricDataQueries=metrics,
            StartTime=datetime.now() - timedelta(minutes=10),
            EndTime=datetime.now())
        for metric in response['MetricDataResults']:
            volumeUsageInfo[metric['Id']] = metric
################################################################################
# This function is used to generate a html version of the report.
################################################################################
def generateHTMLReport(region):
    global fsxns, svms, volumes, volumeUsageInfo, fsxnUsageInfo

    if len(fsxns) == 0:
        return ""

    htmlBody = '<table style="border-collapse: collapse;">\n'
    tableCellStyle = "border: 1px solid black; padding-top: 2px; padding-bottom: 2px; padding-left: 5px; padding-right: 5px"
    
    for fsxn in fsxns:
        fsxnId = fsxn['FileSystemId']
        name = getTag('Name', fsxn.get('Tags', []))
        ontapConfig = fsxn['OntapConfiguration']
        if fsxnUsageInfo[fsxnId]['UsedCapacity'] != 'N/A' :
            fileSystemUsedCapacity = int(fsxnUsageInfo[fsxnId]['UsedCapacity']/1024/1024/1024)
            percentUsed = f"{((fileSystemUsedCapacity / fsxn['StorageCapacity']) * 100):.2f}%"
            fileSystemUsedCapacity = f"{fileSystemUsedCapacity}GB"
        else:
            fileSystemUsedCapacity = 'N/A'
            percentUsed = 'N/A'
        htmlBody += f'<tr><td colspan=11 style="{tableCellStyle}"><b>ID:</b> {fsxnId}<br>\n'
        htmlBody += f"<b>Name:</b> {name}<br>\n"
        htmlBody += f"<b>Region:</b> {region}<br>\n"
        htmlBody += f"<b>Availability:</b> {ontapConfig['DeploymentType']}<br>\n"
        htmlBody += f"<b>Provised Performance Tier Storage:</b> {fsxn['StorageCapacity']}GB<br>\n"
        htmlBody += f"<b>Used Performance Tier Storage:</b> {fileSystemUsedCapacity}<br>\n"
        htmlBody += f"<b>Percent Used Performance Tier:</b> {percentUsed}<br>\n"
        htmlBody += "</td></tr>\n"
        htmlBody += f'<tr><td colspan=11 style="{tableCellStyle}"><b>Volumes:</b></td></tr>\n'
        htmlBody += f'<tr><th style="{tableCellStyle}">Name</th><th style="{tableCellStyle}">SVM</th><th style="{tableCellStyle}">ID</th>\n'
        htmlBody += f'<th style="{tableCellStyle}">Tiering Policy</th><th style="{tableCellStyle}">Type</th><th style="{tableCellStyle}">Volume Style</th>\n'
        htmlBody += f'<th style="{tableCellStyle}">Security Type</th><th style="{tableCellStyle}">Storage Capacity(MB)</th><th style="{tableCellStyle}">Storage Utilization</th>\n'
        htmlBody += f'<th style="{tableCellStyle}">Files Capacity</th><th style="{tableCellStyle}">Files Utilization</th></tr>\n'
        for volume in volumes:
            if volume['FileSystemId'] == fsxnId:
                volId = volume['VolumeId']
                ontapConfig = volume['OntapConfiguration']
                volumeCapacity = volumeUsageInfo[volId.replace("fsvol-", 'm_') + '_StorageCapacity']['Values'][0] if len(volumeUsageInfo[volId.replace("fsvol-", 'm_') + '_StorageCapacity']['Values']) > 0 else 0
                volumeUsed = volumeUsageInfo[volId.replace("fsvol-", "m_") + '_StorageUsed_User']['Values'][0] if len(volumeUsageInfo[volId.replace("fsvol-", "m_") + '_StorageUsed_User']['Values']) > 0 else 0
                volumeUsed += volumeUsageInfo[volId.replace("fsvol-", "m_") + '_StorageUsed_Other']['Values'][0] if len(volumeUsageInfo[volId.replace("fsvol-", "m_") + '_StorageUsed_Other']['Values']) > 0 else 0
                volumeUsed += volumeUsageInfo[volId.replace("fsvol-", "m_") + '_StorageUsed_Snapshot']['Values'][0] if len(volumeUsageInfo[volId.replace("fsvol-", "m_") + '_StorageUsed_Snapshot']['Values']) > 0 else 0
                volumePercentUsed = f"{((volumeUsed / volumeCapacity) * 100):.2f}%" if volumeCapacity > 0 else 'N/A'
                volumeFilesUsed = volumeUsageInfo[volId.replace("fsvol-", "m_") +  '_FilesUsed']['Values'][0] if len(volumeUsageInfo[volId.replace("fsvol-", "m_") +  '_FilesUsed']['Values']) > 0 else 0
                volumeFilesCapacity = volumeUsageInfo[volId.replace("fsvol-", "m_") +  '_FilesCapacity']['Values'][0] if len(volumeUsageInfo[volId.replace("fsvol-", "m_") +  '_FilesCapacity']['Values']) > 0 else 0
                volumeFilesPercentUsed = f"{((volumeFilesUsed / volumeFilesCapacity) * 100):.2f}%" if volumeFilesCapacity > 0 else 'N/A'
                securityStyle = ontapConfig.get('SecurityStyle', 'N/A')
                htmlBody += f'<tr><td align="right" style="{tableCellStyle}">{volume["Name"]}</td><td align="right" style="{tableCellStyle}">{ontapConfig["StorageVirtualMachineId"]}</td>\n'
                htmlBody += f'<td align="right" style="{tableCellStyle}">{volume["VolumeId"]}</td><td align="right" style="{tableCellStyle}">{ontapConfig["TieringPolicy"]["Name"]}</td>\n'
                htmlBody += f'<td align="right" style="{tableCellStyle}">{ontapConfig["OntapVolumeType"]}</td>\n'
                htmlBody += f'<td align="right" style="{tableCellStyle}">{ontapConfig["VolumeStyle"]}</td><td align="right" style="{tableCellStyle}">{securityStyle}</td>\n'
                htmlBody += f'<td align="right" style="{tableCellStyle}">{int(volumeCapacity/1024/1024)}</td><td align="right" style="{tableCellStyle}">{volumePercentUsed}</td>\n'
                htmlBody += f'<td align="right" style="{tableCellStyle}">{int(volumeFilesCapacity)}</td><td align="right" style="{tableCellStyle}">{volumeFilesPercentUsed}</td></tr>\n'
        htmlBody += '<tr><td style="{tableCellStyle}"> </td></tr>\n'
    htmlBody += "</table>\n"
    htmlBody += "<br><br>\n"

    return htmlBody

################################################################################
# This function is used to generate a text version of the report.
################################################################################
def generateTextReport(region):
    global fsxns, svms, volumes, volumeUsageInfo, fsxnUsageInfo
    #
    # Generate the report.
    textReport = f"File Systems in {region}:\n"
    for fsxn in fsxns:
        indent = ' ' * 4
        fsxnId = fsxn['FileSystemId']
        textReport += f"{indent}File System ID: {fsxnId}\n"
        name = getTag('Name', fsxn.get('Tags', []))
        textReport += f"{indent}Name: {name}\n{indent}Status: {fsxn['Lifecycle']}\n{indent}VPC: {fsxn['VpcId']}\n{indent}Subnet(s): "
        for subnet in fsxn['SubnetIds']:
            textReport += f"{subnet} "
        ontapConfig = fsxn['OntapConfiguration']
        textReport += f"\n{indent}Deployment Type: {ontapConfig['DeploymentType']}\n{indent}Number of HA pairs: {ontapConfig['HAPairs']}\n"
        textReport += f"{indent}Management IP: {ontapConfig['Endpoints']['Management']['IpAddresses'][0]}\n"
        textReport += f"{indent}Throughput Capacity: {ontapConfig['ThroughputCapacity']}\n{indent}IOPS Capacity: {ontapConfig['DiskIopsConfiguration']['Iops']}\n"
        backupConfig = fsxn.get('AutomaticBackupRetentionDays', 'N/A')
        textReport += f"{indent}Backup Configuration: {backupConfig}\n{indent}Maintenance Schedule: {ontapConfig['WeeklyMaintenanceStartTime']}\n"
        textReport += f"{indent}Provisioned Capacity: {fsxn['StorageCapacity']}GB\n"
        if fsxnUsageInfo[fsxnId]['UsedCapacity'] != 'N/A' :
            fileSystemUsedCapacity = int(fsxnUsageInfo[fsxnId]['UsedCapacity']/1024/1024/1024)
            percentUsed = f"{((fileSystemUsedCapacity / fsxn['StorageCapacity']) * 100):.2f}%"
            fileSystemUsedCapacity = f"{fileSystemUsedCapacity}GB"
        else:
            fileSystemUsedCapacity = 'N/A'
            percentUsed = 'N/A'
        textReport += f"{indent}Used Capacity: {fileSystemUsedCapacity}\n"
        textReport += f"{indent}Percent Capacity Used: {percentUsed}%\n"

        textReport += f"{indent}Storage Virtual Machines:\n"
        for svm in svms:
            indent=' ' * 8
            if svm['FileSystemId'] != fsxn['FileSystemId']:
                continue

            svmId = svm['StorageVirtualMachineId']
            textReport += f"{indent}ID: {svmId}\n{indent}Name: {svm['Name']}\n{indent}Status: {svm['Lifecycle']}\n"
            textReport += f"{indent}Data/Management IP: {svm['Endpoints']['Management']['IpAddresses'][0]}\n{indent}iSCSI IP: {svm['Endpoints']['Iscsi']['IpAddresses'][0]}\n"
            textReport += f"{indent}Volumes:\n"
            for volume in volumes:
                indent = ' ' * 12
                if volume['OntapConfiguration']['StorageVirtualMachineId'] != svmId:
                    continue
                volId = volume['VolumeId']
                ontapConfig = volume['OntapConfiguration']
                securityStyle = ontapConfig.get('SecurityStyle', 'N/A')
                textReport += f"{indent}ID: {volume['VolumeId']}\n{indent}Name: {volume['Name']}\n{indent}Status: {volume['Lifecycle']}\n"
                textReport += f"{indent}Security Style: {securityStyle}\n{indent}Tiering Policy: {ontapConfig['TieringPolicy']['Name']}\n"
                textReport += f"{indent}Replication Type: {ontapConfig['OntapVolumeType']}\n{indent}Snapshot Policy: {ontapConfig['SnapshotPolicy']}\n{indent}Type: {ontapConfig['VolumeStyle']}\n"
                volumeCapacity = volumeUsageInfo[volId.replace("fsvol-", 'm_') + '_StorageCapacity']['Values'][0] if len(volumeUsageInfo[volId.replace("fsvol-", 'm_') + '_StorageCapacity']['Values']) > 0 else 0
                volumeUsed = volumeUsageInfo[volId.replace("fsvol-", "m_") + '_StorageUsed_User']['Values'][0] if len(volumeUsageInfo[volId.replace("fsvol-", "m_") + '_StorageUsed_User']['Values']) > 0 else 0
                volumeUsed += volumeUsageInfo[volId.replace("fsvol-", "m_") + '_StorageUsed_Other']['Values'][0] if len(volumeUsageInfo[volId.replace("fsvol-", "m_") + '_StorageUsed_Other']['Values']) > 0 else 0
                volumeUsed += volumeUsageInfo[volId.replace("fsvol-", "m_") + '_StorageUsed_Snapshot']['Values'][0] if len(volumeUsageInfo[volId.replace("fsvol-", "m_") + '_StorageUsed_Snapshot']['Values']) > 0 else 0
                volumePercentUsed = f"{((volumeUsed / volumeCapacity) * 100):.2f}%" if volumeCapacity > 0 else 'N/A'
                volumeFilesUsed = volumeUsageInfo[volId.replace("fsvol-", "m_") +  '_FilesUsed']['Values'][0] if len(volumeUsageInfo[volId.replace("fsvol-", "m_") +  '_FilesUsed']['Values']) > 0 else 0
                volumeFilesCapacity = volumeUsageInfo[volId.replace("fsvol-", "m_") +  '_FilesCapacity']['Values'][0] if len(volumeUsageInfo[volId.replace("fsvol-", "m_") +  '_FilesCapacity']['Values']) > 0 else 0
                volumeFilesPercentUsed = f"{((volumeFilesUsed / volumeFilesCapacity) * 100):.2f}%" if volumeFilesCapacity > 0 else 'N/A'
                textReport += f"{indent}Capacity: {int(volumeCapacity/1024/1024)}M\n{indent}Used Capacity: {int(volumeUsed/1024/1024)}M\n{indent}Percent Capacity Used: {volumePercentUsed}\n"
                textReport += f"{indent}Files Capacity: {int(volumeFilesCapacity)}\n{indent}Files Used: {int(volumeFilesUsed)}\n{indent}Percent Files Used: {volumeFilesPercentUsed}\n"
                textReport += "\n"
            textReport += "\n"
        textReport += "\n"

    return textReport

################################################################################
# This function is used to email the report.
################################################################################
def emailReport(report, fromAddress, toAddress):

    sesClient = boto3.client('ses')
    response = sesClient.send_email(
                    Destination={
                        'ToAddresses': [
                            toAddress
                        ]
                    },
                    Message= {
                        'Body': {
                            'Html': {
                                'Data': report,
                            }
                        },
                        'Subject': {
                            'Charset': 'UTF-8',
                            'Data': "FSxN Report",
                        }
                    },
                    Source=fromAddress
                )

################################################################################
# This function is used to get the configuration from the environment variables.
################################################################################
def getConfig():
    global config
    #
    config = {
        "AWS_REGION": None,
        "ALL_REGIONS": None,
        "REGIONS": None,
        "REPORT_TYPE": None,
        "TO_ADDRESS": None,
        "TEXT_REPORT": None,
        "FROM_ADDRESS": None
    }
    #
    # Get the paramaters from the environment.
    for var in config:
        config[var] = os.environ.get(var)
        #
        # Since CloudFormation set all environment variables to empty strings
        # set them back to none if they are empty.
        if config[var] == '':
            config[var] = None
    #
    # Convert string values to boolean where necessary.
    if config['ALL_REGIONS'] != None:
        if config['ALL_REGIONS'].lower() == 'true':
            config['ALL_REGIONS'] = True
        else:
            config['ALL_REGIONS'] = False
    #
    # To be backwards compatible, if the TEXT_REPORT variable is set, then
    # set REPORT_TYPE appropriately.
    if config['TEXT_REPORT'] != None and config['REPORT_TYPE'] is None:
        if config['TEXT_REPORT'].lower() == 'true':
            config['REPORT_TYPE'] = "text"
        else:
            config['REPORT_TYPE'] = "html"

################################################################################
################################################################################
def lambda_handler(event, context):
    global config, boto3Config
    #
    # Configure boto3 to use the more advanced "adaptive" retry method.
    boto3Config = Config(
        retries = {
            'max_attempts': 5,
            'mode': 'adaptive'
        }
    )

    getConfig()
    regions = []

    if calledAsLambda:
        if config['TO_ADDRESS'] is None or config['FROM_ADDRESS'] is None:
            raise Exception("Both 'toAddress' and 'fromAddress' environment variables must be set for email reporting.")

    if config['REGIONS'] is not None:
        regions = config['REGIONS'].split(',')
        i=0
        while i < len(regions):
            regions[i] = regions[i].strip()
            i += 1
    elif config['ALL_REGIONS']:
        ec2Client = boto3.client('ec2', config=boto3Config)
        ec2Regions = ec2Client.describe_regions()['Regions']
        for region in ec2Regions:
            regions += [region['RegionName']]
    else:
        if config['AWS_REGION'] is not None:
            regions = [config['AWS_REGION']]
        else:
            regions = [boto3.Session().region_name]

    fsxRegions = boto3.Session().get_available_regions('fsx')
    report = ""
    #
    # For an HTML report, just want the HTML start and end data once for all the regions.
    if config['REPORT_TYPE'] != "text":
        currentReport = "<!DOCTYPE html>\n<html>\n"
        currentReport += "<head>\n<title>FSxN Report</title>\n"
        currentReport += "</head>\n<body>\n"

    for region in regions:
        if region in fsxRegions:
            #
            # Get all the FSxN information.
            getFSxNInfo(region)
            #
            # Generate the report.
            if config['REPORT_TYPE'] == 'text':
                currentReport = generateTextReport(region)
            else:  # Default to an HTML report.
                currentReport += generateHTMLReport(region)

            if len(currentReport) > maxEmailSize:
                raise Exception(f"Report for region {region} exceeds maximum email size of {maxEmailSize} characters.")

            if len(report) + len(currentReport) > maxEmailSize:
                emailReport(report, fromAddress, toAddress)
                report = currentReport
                currentReport = ""
            else:
                report += currentReport
                currentReport = ""

    if config['REPORT_TYPE'] != 'text':
        report += "</body></html>\n"
    #
    # Email the report.
    if config['TO_ADDRESS'] is None or config['FROM_ADDRESS'] is None:
        print(report)
    else:
        emailReport(report, config['FROM_ADDRESS'], config['TO_ADDRESS'])

################################################################################
################################################################################
#
# If this script is not running as a Lambda function, then call the lambda_handler function.
calledAsLambda = True
maxEmailSize = (1024*1024*5) # The SES version 1 is 5MB. SES version 2 is 10MB.
if os.environ.get('AWS_LAMBDA_FUNCTION_NAME') == None:
    calledAsLambda = False
    lambda_handler(None, None)
