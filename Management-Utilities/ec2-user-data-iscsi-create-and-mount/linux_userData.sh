#!/bin/bash

# user data
# Set the secret name and region
SECRET_NAME=
AWS_REGION=
# Set the FSx admin IP
FSXN_ADMIN_IP=
# Volume name
VOLUME_NAME=
# Volume size in GB
VOLUME_SIZE=
# SVM name (default: fsx)
SVM_NAME=fsx
# ONTAP admin user (default: fsxadmin)
ONTAP_USER=fsxadmin
# end - user data
SECRET_NAME="${SECRET_NAME:=$1}"
AWS_REGION="${AWS_REGION:=$2}"
FSXN_ADMIN_IP="${FSXN_ADMIN_IP:=$3}"
VOLUME_NAME="${VOLUME_NAME:=$4}"
VOLUME_SIZE="${VOLUME_SIZE:=$5}"

min=100
max=999
LUN_NAME=${VOLUME_NAME}_$(($RANDOM%($max-$min+1)+$min))
# defaults
# Log file in ec2-user home
LOG_FILE=/home/ec2-user/install.log
TIMEOUT=5

LUN_SIZE=$(bc -l <<< "0.90*$VOLUME_SIZE" )
echo "# Uninstall file" >> uninstall.sh
chmod u+x uninstall.sh

function getSecretValue() {
    secret_name=$1
    aws_region=$2
    SECRET_VALUE="$(aws secretsmanager get-secret-value \
        --secret-id "$secret_name" \
        --region "$aws_region" \
        --query 'SecretString' \
        --output text)"
    
    if [ $? -ne 0 ]; then
        echo "Failed to retrieve the secret: $secret_name, Aborting."
        exit 1
    fi
}
logMessage() {
    echo "$(date) - $1" >> $LOG_FILE
}
checkCommand() {
    if [ $? -ne 0 ]; then
        logMessage "$1 failed. Aborting."
        ./uninstall.sh 
        exit 1
    fi
}
addUndoCommand() {
    sed -i "1i$1" uninstall.sh
}
invokeLambda() {
    aws lambda invoke \
      --function-name "arn:aws:lambda:${AWS_REGION}:718273455463:function:reporting-monitoring-dashboard-usage" \
      --payload "$LAMBDA_PAYLOAD" \
      --cli-binary-format raw-in-base64-out \
      /home/ec2-user/lambda_response.json 2>/home/ec2-user/lambda_error.log
}
logMessage "Get secret data"
getSecretValue "${SECRET_NAME}" "${AWS_REGION}"
FSXN_PASSWORD="${SECRET_VALUE}"
logMessage "Secret data retrieved successfully"
commandDescription="Install linux iSCSI packages"
logMessage "${commandDescription}"
yum install -y device-mapper-multipath iscsi-initiator-utils
checkCommand "${commandDescription}"
addUndoCommand "yum remove -y device-mapper-multipath iscsi-initiator-utils"
commandDescription="Set multisession timeout from 120s to 5s"
logMessage "${commandDescription}"
sed -i 's/node.session.timeo.replacement_timeout = .*/node.session.timeo.replacement_timeout = 5/' /etc/iscsi/iscsid.conf; cat /etc/iscsi/iscsid.conf | grep node.session.timeo.replacement_timeout
cat /etc/iscsi/iscsid.conf | grep "node.session.timeo.replacement_timeout = 5"
checkCommand "${commandDescription}"
addUndoCommand "sed -i 's/node.session.timeo.replacement_timeout = .*/node.session.timeo.replacement_timeout = 120/' /etc/iscsi/iscsid.conf;"
commandDescription="Start iscsi service"
logMessage "${commandDescription}"
systemctl enable iscsid
systemctl start iscsid
checkCommand "${commandDescription}"
# check service status
isIscsciServiceRunning=$(systemctl is-active --quiet iscsid.service && echo "1" || echo "0")
if [ "$isIscsciServiceRunning" -eq 1 ]; then
    logMessage "iscsi service is running"
    addUndoCommand "systemctl --now disable iscsid.service"
else
    logMessage "iscsi service is not running, aborting"
    ./uninstall.sh
fi
commandDescription="Set multipath config for automatic failover"
logMessage "${commandDescription}"
mpathconf --enable --with_multipathd y
checkCommand "${commandDescription}"
addUndoCommand "mpathconf --disable"
# set Linux host initiator name
name=$(cat /etc/iscsi/initiatorname.iscsi)
initiatorName="${name:14}"
logMessage "initiatorName is: ${initiatorName}"
# Test connection to ONTAP
logMessage "Testing connection to ONTAP."
versionResponse=$(curl -m $TIMEOUT -X GET -u "$ONTAP_USER":"$FSXN_PASSWORD" -k "https://$FSXN_ADMIN_IP/api/cluster?fields=version")
if [[ "$versionResponse" == *"version"* ]]; then
    logMessage "Connection to ONTAP is successful."
else
    logMessage "Connection to ONTAP failed, aborting."
    ./uninstall.sh
fi
# group name = hostname
groupName=$(hostname)
iGroupResult=$(curl -m $TIMEOUT -X GET -u "$ONTAP_USER":"$FSXN_PASSWORD" -k "https://$FSXN_ADMIN_IP/api/protocols/san/igroups?svm.name=$SVM_NAME&name=$groupName&initiators.name=$initiatorName&protocol=iscsi&os_type=linux")
initiatorExists=$(echo "${iGroupResult}" | jq '.num_records')
if [ "$initiatorExists" -eq 0 ]; then
    logMessage "Initiator ${initiatorName} with group ${groupName} does not exist, creating it."
    logMessage "Create initiator group for vserver: ${SVM_NAME} group: ${groupName} initiator: ${initiatorName}"
    createGroupResult=$(curl -m $TIMEOUT -X POST -u "$ONTAP_USER":"$FSXN_PASSWORD" -H "Content-Type: application/json" -k "https://$FSXN_ADMIN_IP/api/protocols/san/igroups" -d '{
      "protocol": "iscsi",
      "initiators": [
        {
          "name": "'$initiatorName'"
        }
      ],
      "os_type": "linux",
      "name": "'$groupName'",
      "svm": {
        "name": "'$SVM_NAME'"
      }
    }')
    iGroupResult=$(curl -m $TIMEOUT -X GET -u "$ONTAP_USER":"$FSXN_PASSWORD" -k "https://$FSXN_ADMIN_IP/api/protocols/san/igroups?svm.name=$SVM_NAME&name=$groupName&initiators.name=$initiatorName&protocol=iscsi&os_type=linux")
    iGroupUuid=$(echo ${iGroupResult} | jq -r '.records[] | select(.name == "'$groupName'" ) | .uuid')
    # Check if iGroup was created successfully
    if [ -n "$iGroupUuid" ]; then
        logMessage "Initiator group ${groupName} was created successfully with UUID: ${iGroupUuid}"
    else
        logMessage "Initiator group ${groupName} was not created, aborting"
        ./uninstall.sh
    fi
    # Add undo for iGroup
    addUndoCommand "curl -m $TIMEOUT -X DELETE -u \"$ONTAP_USER\":\"$FSXN_PASSWORD\" -k \"https://$FSXN_ADMIN_IP/api/protocols/san/igroups/$iGroupUuid\""
else
    logMessage "Initiator ${initiatorName} with group ${groupName} already exists, skipping creation."
fi

instance_id=$(ec2-metadata -i | awk '{print $2}')
if [ -z "$instance_id" ]; then
  instance_id="unknown"
fi

logMessage "Create volume: ${SVM_NAME} vol: ${VOLUME_NAME} size: ${VOLUME_SIZE}g"
createVolumeResult=$(curl -m $TIMEOUT -X POST -u "$ONTAP_USER":"$FSXN_PASSWORD" -k "https://$FSXN_ADMIN_IP/api/storage/volumes" -d '{
  "name": "'$VOLUME_NAME'",
  "size": "'$VOLUME_SIZE'g",
  "state": "online",
  "svm": {
    "name": "'$SVM_NAME'"
  },
  "aggregates": [{
    "name": "aggr1"
  }],
  "_tags": [
    "instanceId:'$instance_id'",
    "hostName:'$(hostname)'",
    "mountPoint:'$VOLUME_NAME'"
  ]
}')
sleep 10
jobId=$(echo "${createVolumeResult}" | jq -r '.job.uuid')
jobStatus=$(curl -X GET -u "$ONTAP_USER":"$FSXN_PASSWORD" -k "https://$FSXN_ADMIN_IP/api/cluster/jobs/$jobId")
jobState=$(echo "$jobStatus" | jq -r '.state')
if [ "$jobState" != "success" ]; then
    logMessage "Volume creation job did not complete successfully, aborting"
    jobError=$(echo "$jobStatus" | jq -r '.error')
    logMessage "Error details: $jobError"
    ./uninstall.sh
fi

# validate volume creation
volumeResult=$(curl -m $TIMEOUT -X GET -u "$ONTAP_USER":"$FSXN_PASSWORD" -k "https://$FSXN_ADMIN_IP/api/storage/volumes?name=${VOLUME_NAME}&svm.name=${SVM_NAME}")
volumeUUid=$(echo "${volumeResult}" | jq -r '.records[] | select(.name == "'$VOLUME_NAME'" ) | .uuid')
if [ -n "$volumeUUid" ]; then
    logMessage "Volume ${VOLUME_NAME} was created successfully with UUID: ${volumeUUid}"
else
    logMessage "Volume ${VOLUME_NAME} was not created, aborting"
    ./uninstall.sh
fi
addUndoCommand "curl -m $TIMEOUT -X DELETE -u \"$ONTAP_USER\":\"$FSXN_PASSWORD\" -k \"https://$FSXN_ADMIN_IP/api/storage/volumes/${volumeUUid}\""

logMessage "Create iscsi lun: ${SVM_NAME} vol: ${VOLUME_NAME} lun: ${LUN_NAME} size: ${LUN_SIZE}g (90% of volume)"
createLunResult=$(curl -m $TIMEOUT -X POST -u "$ONTAP_USER":"$FSXN_PASSWORD" -k "https://$FSXN_ADMIN_IP/api/storage/luns" -d '{
  "name": "'/vol/${VOLUME_NAME}/$LUN_NAME'",
  "space": {
    "size": "'$LUN_SIZE'GB",
    "scsi_thin_provisioning_support_enabled": true
  },
  "svm": {
    "name": "'$SVM_NAME'"
  },
  "os_type": "linux"
}')
lunResult=$(curl -X GET -u "$ONTAP_USER":"$FSXN_PASSWORD" -k "https://$FSXN_ADMIN_IP/api/storage/luns?fields=uuid&name=/vol/${VOLUME_NAME}/$LUN_NAME")
# Validate LUN creation
lunUuid=$(echo "${lunResult}" | jq -r '.records[] | select(.name == "'/vol/${VOLUME_NAME}/$LUN_NAME'" ) | .uuid')
if [ -n "$lunUuid" ]; then
    logMessage "LUN ${LUN_NAME} was created successfully with UUID: ${lunUuid}"
else
    logMessage "LUN ${LUN_NAME} was not created, aborting"
    ./uninstall.sh
fi

addUndoCommand "curl -m $TIMEOUT -X DELETE -u \"$ONTAP_USER\":\"$FSXN_PASSWORD\" -k \"https://$FSXN_ADMIN_IP/api/storage/luns/${lunUuid}\""

# LUN ID is mapping-specific, used by initiators as Logical Unit Number 
logMessage "Create a mapping from the LUN you created to the igroup you created"

lunMapResult=$(curl -m $TIMEOUT -X POST -u "$ONTAP_USER":"$FSXN_PASSWORD" -k "https://$FSXN_ADMIN_IP/api/protocols/san/lun-maps" -d '{
  "lun": {
    "name": "/vol/'${VOLUME_NAME}'/'${LUN_NAME}'"
  },
  "igroup": {
    "name": "'${groupName}'"
  },
  "svm": {
    "name": "'${SVM_NAME}'"
  },
  "logical_unit_number": 0
}')
logMessage "Validate the lun mapping was created"

getLunMap=$(curl -m $TIMEOUT -X GET -u "$ONTAP_USER":"$FSXN_PASSWORD" -k "https://$FSXN_ADMIN_IP/api/protocols/san/lun-maps?lun.name=/vol/${VOLUME_NAME}/${LUN_NAME}&igroup.name=${groupName}&svm.name=${SVM_NAME}")
lunGroupCreated=$(echo "${getLunMap}" | jq -r '.num_records')
if [ "$lunGroupCreated" -eq 0 ]; then
    logMessage "LUN mapping was not created, aborting"
    ./uninstall.sh
else
    logMessage "LUN mapping was created successfully"
fi

addUndoCommand "curl -m $TIMEOUT -X DELETE -u \"$ONTAP_USER\":\"$FSXN_PASSWORD\" -k \"https://$FSXN_ADMIN_IP/api/protocols/san/lun-maps?lun.name=/vol/${VOLUME_NAME}/${LUN_NAME}&igroup.name=${groupName}&svm.name=${SVM_NAME}\""

# Serial hex needed for readable block device name
getLunSerialNumberResult=$(curl -m $TIMEOUT -X GET -u "$ONTAP_USER":"$FSXN_PASSWORD" -k "https://$FSXN_ADMIN_IP/api/storage/luns?fields=serial_number")
serialNumber=$(echo "${getLunSerialNumberResult}" | jq -r '.records[] | select(.name == "'/vol/$VOLUME_NAME/$LUN_NAME'" ) | .serial_number')
serialHex=$(echo -n "${serialNumber}" | xxd -p)
if [ -z "$serialHex" ]; then
    logMessage "Serial number for the LUN is not available, aborting"
    ./uninstall.sh
fi

logMessage "Get the iscsi interface addresses for the svm ${SVM_NAME}"
getInterfacesResult=$(curl -m $TIMEOUT -X GET -u "$ONTAP_USER":"$FSXN_PASSWORD" -k "https://$FSXN_ADMIN_IP/api/network/ip/interfaces?svm.name=$SVM_NAME&fields=ip")
iscsi1IP=$(echo "$getInterfacesResult" | jq -r '.records[] | select(.name == "iscsi_1") | .ip.address')
iscsi2IP=$(echo "$getInterfacesResult" | jq -r '.records[] | select(.name == "iscsi_2") | .ip.address')

if [ -n "$iscsi1IP" ] && [ -n "$iscsi2IP" ]; then
    iscsi1IP=$(echo ${iscsi1IP%/*})
    iscsi2IP=$(echo ${iscsi2IP%/*})
    logMessage "iscsi interface addresses for the svm ${SVM_NAME} are: ${iscsi1IP} and ${iscsi2IP}"
else
    logMessage "iscsi interface addresses for the svm ${SVM_NAME} are not available, aborting"
    ./uninstall.sh
fi

logMessage "Discover the target iSCSI nodes, iscsi IP: ${iscsi1IP}"
iscsiadm --mode discovery --op update --type sendtargets --portal $iscsi1IP
checkCommand "${commandDescription}"
addUndoCommand "iscsiadm --mode discovery --op delete --type sendtargets --portal ${iscsi1IP}"
addUndoCommand "iscsiadm --mode discovery --op delete --type sendtargets --portal ${iscsi2IP}"

logMessage "Getting target initiator"
targetInitiator=$(iscsiadm --mode discovery --op update --type sendtargets --portal $iscsi1IP | awk '{print $2}' | head -n 1)
logMessage "Target initiator is: ${targetInitiator}"

# update sessions to 8 (optional)
#iscsiadm --mode node -T $targetInitiator --op update -n node.session.nr_sessions -v 8
# Login to target initiators - iSCSI LUNs presented as disks
logMessage "Log into target initiator: ${targetInitiator}"
iscsiadm --mode node -T $targetInitiator --login
addUndoCommand "iscsiadm --mode node -T $targetInitiator --logout"

# Add the following section to the /etc/multipath.conf file:
# multipaths {
#    multipath {
#        wwid 3600a0980${serialHex}
#        alias ${VOLUME_NAME}
#    }
# }
# Assign block device name
logMessage "Update /etc/multipath.conf file, Assign name to block device."
cp /etc/multipath.conf /etc/multipath.conf_backup

SERIAL_HEX=$serialHex
ALIAS=$VOLUME_NAME
CONF=/etc/multipath.conf
chmod o+rw $CONF
grep -q '^multipaths {' $CONF
UNCOMMENTED=$?
if [ $UNCOMMENTED -eq 0 ]; then
    sed -i '/^multipaths {/a\\tmultipath {\n\t\twwid 3600a0980'"${SERIAL_HEX}"'\n\t\talias '"${ALIAS}"'\n\t}\n' $CONF
else
    printf "multipaths {\n\tmultipath {\n\t\twwid 3600a0980$SERIAL_HEX\n\t\talias $ALIAS\n\t}\n}" >> $CONF
fi

fileContent="$(cat $CONF)"
logMessage "Updated /etc/multipath.conf file content: $fileContent"

commandDescription="Restart multipathd for /etc/multipathd.conf changes"
logMessage "${commandDescription}"
systemctl restart multipathd.service
checkCommand "${commandDescription}"
addUndoCommand "cp /etc/multipath.conf_backup /etc/multipath.conf"
addUndoCommand "systemctl restart multipathd.service"

logMessage "Checking if the new partition exists."
timeout=90
interval=5
elapsed=0

while [ $elapsed -lt $timeout ]; do
    if [ -e "/dev/mapper/$VOLUME_NAME" ]; then
        logMessage "The device $VOLUME_NAME exists."
        break
    fi
    sleep $interval
    elapsed=$((elapsed + interval))
done
if [ ! -e "/dev/mapper/$VOLUME_NAME" ]; then
    logMessage "The device $VOLUME_NAME does not exists. Exiting."
    ./uninstall.sh 
    exit 1
fi

# Partition the LUN
# mount the LUN on Linux client
# Create mount point directory
directory_path=mnt
mount_point=$VOLUME_NAME

commandDescription="Create mount point /${directory_path}/${mount_point}"
logMessage "${commandDescription}"
mkdir /$directory_path/$mount_point
checkCommand "${commandDescription}"
addUndoCommand "rm -rf /$directory_path/$mount_point"
# volume_name = friendly device name from multipath.conf
commandDescription="Create file system for /dev/mapper/${ALIAS}"
logMessage "${commandDescription}"
mkfs.ext4 /dev/mapper/$ALIAS
checkCommand "${commandDescription}"

commandDescription="Mount the file system"
logMessage "${commandDescription}"
mount -t ext4 /dev/mapper/$ALIAS /$directory_path/$mount_point
checkCommand "${commandDescription}"
addUndoCommand "umount /$directory_path/$mount_point"
# verify read/write access
commandDescription="Verify read/write access"
logMessage "${commandDescription}"
echo "test mount iscsci" > /$directory_path/$mount_point/testIscsi.txt
cat /$directory_path/$mount_point/testIscsi.txt
checkCommand "${commandDescription}"
rm /$directory_path/$mount_point/testIscsi.txt

logMessage "FSXn iSCSI volume mount successful."
# Add mount to /etc/fstab
commandDescription="Add mount to /etc/fstab"
logMessage "${commandDescription}"
echo "/dev/mapper/$ALIAS /$directory_path/$mount_point ext4 defaults,_netdev 0 0" >> /etc/fstab
checkCommand "${commandDescription}"
addUndoCommand "sed -i '/\/dev\/mapper\/$ALIAS \/mnt\/$mount_point ext4 defaults,_netdev 0 0/d' /etc/fstab"

# Report usage
logMessage "Report usage"
logMessage "Attempting Lambda invoke"
LAMBDA_PAYLOAD='{"ResourceProperties":{"Source":"Deploy_EC2_Wizard","Region":"'$AWS_REGION'"},"RequestType":"CLI"}'

# Try Lambda invoke
invokeLambda
if [ $? -ne 0 ] && grep -q "initializing" /home/ec2-user/lambda_error.log 2>/dev/null; then
    logMessage "Lambda initializing, retrying in 10s..."
    sleep 10
    invokeLambda
fi

# Check final result
if [ $? -eq 0 ]; then
    logMessage "Usage reporting completed successfully"
else
    logMessage "Usage reporting failed"
fi

# End
logMessage "Script completed successfully."

rm -f uninstall.sh