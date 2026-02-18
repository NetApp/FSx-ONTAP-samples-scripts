#!/bin/python
#
################################################################################
# This Python program creates a clone of a volume in a FSx for ONTAP file
# system. It does this by creating a CloudFormation stack that uses the 
# NetApp CloudFormation extensions to create the clone.
################################################################################

import boto3
import json
import time
import getopt
import sys
import random

################################################################################
# This function just displays the usage information.
################################################################################
def usage():
    print("Usage: createClone.py -r region -l <linkArn> -s <secretArn> -k <secretKey> -f <fsxId> -n <svmName> -p <parentVolumeName> -c <cloneVolumeName> -t <template>")

################################################################################
# This is the main part of the script.
################################################################################
cloudFormationTemplate = """
Description: "Create a clone of a volume."

Parameters:
  FileSystemId:
    Description: "The File System ID."
    Type: String

  SecretArn:
    Description: "The Secret ARN."
    Type: String

  SecretKey:
    Description: "The key to use within the AWS secret."
    Default: "password"
    Type: String

  LinkArn:
    Description: "The ARN to the Lambda link function."
    Type: String

  SvmName:
    Description: "The name of the SVM that hold the parent volume."
    Type: String

  CloneVolumeName:
    Description: "The desired name for the cloned volume."
    Type: String

  ParentVolumeName:
    Description: "The name of the parent volume."
    Type: String

  IsCloned:
    Description: "Set to false, during an update, to split the clone from its parent."
    Type: String
    Default: "true"

Resources:
  CloneVolume:
    Type: "NetApp::FSxN::Volume"

    Properties:
      FsxAdminPasswordSource:
        Secret:
          SecretArn: !Ref SecretArn
          SecretKey: !Ref SecretKey
      FileSystemId: !Ref FileSystemId
      LinkArn: !Ref LinkArn
      SVM:
        Name: !Ref SvmName
      Name: !Ref CloneVolumeName

      Clone:
        ParentSVM:
          Name: !Ref SvmName
        ParentVolume:
          Name: !Ref ParentVolumeName
        IsCloned: !Ref IsCloned
"""
#
# Set the default values for the parameters.
linkArn=""
secretArn=""
secretKey=""
fsxId=""
svmName=""
parentVolumeName=""
cloneVolumeName=""
region=""
#
# Get the command line arguments.
argumentList = sys.argv[1:]
options = "hl:s:k:f:n:p:c:t:r:"
longOptions = ["help", "linkArn=", "scretArn=", "secretKey=", "fsxId=", "parentVolumeName=", "cloneVolumeName=", "svm=", "region="]
try:
    arguments, values = getopt.getopt(argumentList, options, longOptions)

    for currentArgument, currentValue in arguments:
        if currentArgument in ("-h", "--help"):
            usage()
            sys.exit(0)
        elif currentArgument in ("-l", "--linkArn"):
            linkArn = currentValue
        elif currentArgument in ("-s", "--secretArn"):
            secretArn = currentValue
        elif currentArgument in ("-k", "--secretKey"):
            secretKey = currentValue
        elif currentArgument in ("-f", "--fsxId"):
            fsxId = currentValue
        elif currentArgument in ("-n", "--svm"):
            svmName = currentValue
        elif currentArgument in ("-p", "--parentVolumeName"):
            parentVolumeName = currentValue
        elif currentArgument in ("-c", "--cloneVolumeName"):
            cloneVolumeName = currentValue
        elif currentArgument in ("-r", "--region"):
            region = currentValue

except getopt.error as err:
    print(str(err))
    usage()
    sys.exit(2)
#
# Check that all the required parameters are present.
if secretArn == "" or secretKey == "" or linkArn == "" or fsxId == "" or svmName == "" or parentVolumeName == "" or cloneVolumeName == "":
    print("Missing required parameters.")
    usage()
    sys.exit(1)
#
# Create the CloudFormation client.
cfClient = boto3.client("cloudformation", region_name=region)
#
# Add a random number to the stack name to make it unique.
stackName = "CreateClone-" + str(random.randint(1000, 9999))
#
# Create the stack.
response = cfClient.create_stack(StackName=stackName, TemplateBody=cloudFormationTemplate,
    Parameters=[
        {
            "ParameterKey": "FileSystemId",
            "ParameterValue": fsxId
        },
        {
            "ParameterKey": "SecretArn",
            "ParameterValue": secretArn
        },
        {
            "ParameterKey": "SecretKey",
            "ParameterValue": secretKey
        },
        {
            "ParameterKey": "LinkArn",
            "ParameterValue": linkArn
        },
        {
            "ParameterKey": "SvmName",
            "ParameterValue": svmName 
        },
        {
            "ParameterKey": "ParentVolumeName",
            "ParameterValue": parentVolumeName
        },
        {
            "ParameterKey": "CloneVolumeName",
            "ParameterValue": cloneVolumeName
        }
    ]
)
#
# Wait for the stack to complete.
while True: 
    response = cfClient.describe_stacks(StackName=stackName)
    if response["Stacks"][0]["StackStatus"] != "CREATE_IN_PROGRESS":
        break
    time.sleep(3)

if response["Stacks"][0]["StackStatus"] != "CREATE_COMPLETE":
    print("Failed to create clone.")
    sys.exit(1)
else:
    print("Clone created successfully.")
    sys.exit(0)
