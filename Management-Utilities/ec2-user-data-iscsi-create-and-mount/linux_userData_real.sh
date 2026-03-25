#!/bin/bash
#
# Since if aws is installed it goes into /usr/local/bin.
PATH=${PATH}:/usr/local/bin

LOG_FILE=/var/log/iscsi-install.log
TIMEOUT=5
#
# Get the O/S Linux distribution.
. /etc/os-release
case "$ID" in
  amzn|centos|rhel)
    OS_TYPE=rhel;;
  ubuntu|debian)
    OS_TYPE=debian;;
  *)
    echo "Unknown OS type: '$ID'." >> $LOG_FILE
    exit 1;;
esac

getSecretValue() {
  secret_arn=$1
  SECRET_VALUE="$(aws secretsmanager get-secret-value \
    --secret-id "$secret_arn" \
    --query 'SecretString' \
    --output text)"

  if [ $? -ne 0 ]; then
    echo "Failed to retrieve the secret from '$secret_arn', Aborting."
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
LambdaErrorFile="/tmp/lambda_error.log"
LambdaResponseFile="/tmp/lambda_response.json"
invokeLambda() {
  aws lambda invoke \
    --function-name "arn:aws:lambda:${AWS_REGION}:718273455463:function:reporting-monitoring-dashboard-usage" \
    --payload "$LAMBDA_PAYLOAD" \
    --cli-binary-format raw-in-base64-out \
    $LambdaResponseFile 2>$LambdaErrorFile
}
requiredCmds="curl unzip jq bc xxd"
if [ "$OS_TYPE" == "rhel" ]; then
  yum update -y
  checkCommand "yum update"
  for cmd in $requiredCmds; do
    if ! command -v $cmd &> /dev/null; then
      logMessage "Installing $cmd"
      if [ "$cmd" == "jq" ]; then
        # For RHEL/CentOS, install jq from EPEL repository
        yum install -y epel-release
        checkCommand "Install epel-release for jq"
      fi
      yum install -y $cmd
      checkCommand "Install $cmd"
      addUndoCommand "yum remove -y $cmd"
    fi
  done

  if [ "$ID" != "amzn" ]; then
    curl -s https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip -o awscliv2.zip
    unzip -q awscliv2.zip
    ./aws/install
    rm -rf aws awscliv2.zip
  fi
elif [ "$OS_TYPE" == "debian" ]; then
  apt-get update > /dev/null  2>&1
  for cmd in $requiredCmds; do
    if ! command -v $cmd &> /dev/null; then
      logMessage "Installing $cmd"
      apt-get install -y $cmd
      checkCommand "Install $cmd"
      addUndoCommand "apt-get remove -y $cmd"
    fi
  done
  curl -s https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip -o awscliv2.zip
  unzip -q awscliv2.zip
  ./aws/install
  rm -rf aws awscliv2.zip
fi

LUN_SIZE=$(bc -l <<< "0.90*$VOLUME_SIZE" )
LUN_NAME=${VOLUME_NAME}_$(($RANDOM%(900)+100))

echo "# Uninstall file" > uninstall.sh
chmod u+x uninstall.sh

logMessage "Get secret data"
getSecretValue "${SECRET_ARN}"
FSXN_PASSWORD="${SECRET_VALUE}"
logMessage "Secret data retrieved successfully"
commandDescription="Install linux iSCSI packages"
logMessage "${commandDescription}"
if [ "$OS_TYPE" == "rhel" ]; then
  yum install -y device-mapper-multipath iscsi-initiator-utils
  checkCommand "${commandDescription}"
  addUndoCommand "yum remove -y device-mapper-multipath iscsi-initiator-utils"
elif [ "$OS_TYPE" == "debian" ]; then
  apt-get update > /dev/null 2>&1
  apt-get install -y multipath-tools open-iscsi
  checkCommand "${commandDescription}"
  addUndoCommand "apt-get remove -y multipath-tools open-iscsi"
fi
commandDescription="Set multisession timeout from 120s to 5s"
logMessage "${commandDescription}"
sed -i 's/node.session.timeo.replacement_timeout = .*/node.session.timeo.replacement_timeout = 5/' /etc/iscsi/iscsid.conf
grep "node.session.timeo.replacement_timeout = 5" /etc/iscsi/iscsid.conf
checkCommand "${commandDescription}"
addUndoCommand "sed -i 's/node.session.timeo.replacement_timeout = .*/node.session.timeo.replacement_timeout = 120/' /etc/iscsi/iscsid.conf"
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
    exit 1
fi
commandDescription="Set multipath config for automatic failover"
logMessage "${commandDescription}"
if [ $OS_TYPE == "rhel" ]; then
    mpathconf --enable --with_multipathd y
    checkCommand "${commandDescription}"
    addUndoCommand "mpathconf --disable"
elif [ $OS_TYPE == "debian" ]; then
    systemctl enable multipathd
    systemctl start multipathd
    checkCommand "${commandDescription}"
    isServiceRunning=$(systemctl is-active --quiet multipathd && echo "1" || echo "0")
    if [ "$isServiceRunning" -eq 1 ]; then
        logMessage "multipathd service is running"
        addUndoCommand "systemctl --now disable multipathd"
    else
        logMessage "multipathd service is not running, aborting"
        ./uninstall.sh
        exit 1
   fi
fi

. /etc/iscsi/initiatorname.iscsi
logMessage "InitiatorName is: ${InitiatorName}"

logMessage "Testing connection to ONTAP."
versionResponse=$(curl -sm $TIMEOUT -X GET -u "$ONTAP_USER":"$FSXN_PASSWORD" -k "https://$FSXN_ADMIN_IP/api/cluster?fields=version" | jq -r .version)
if [ "$versionResponse" == "null" ]; then
    logMessage "Connection to ONTAP failed, aborting."
    ./uninstall.sh
    exit 1
fi

groupName=$(hostname)
iGroupResult=$(curl -sm $TIMEOUT -X GET -u "$ONTAP_USER":"$FSXN_PASSWORD" -k "https://$FSXN_ADMIN_IP/api/protocols/san/igroups?svm.name=$SVM_NAME&name=$groupName&initiators.name=$InitiatorName&protocol=iscsi&os_type=linux")
initiatorExists=$(echo "${iGroupResult}" | jq '.num_records')
if [ "$initiatorExists" -eq 0 ]; then
    logMessage "Initiator ${InitiatorName} with group ${groupName} does not exist, creating it."
    logMessage "Create initiator group for vserver: ${SVM_NAME} group: ${groupName} initiator: ${InitiatorName}"
    createGroupResult=$(curl -sm $TIMEOUT -X POST -u "$ONTAP_USER":"$FSXN_PASSWORD" -H "Content-Type: application/json" -k "https://$FSXN_ADMIN_IP/api/protocols/san/igroups" -d '{
      "protocol": "iscsi",
      "initiators": [
        {
          "name": "'$InitiatorName'"
        }
      ],
      "os_type": "linux",
      "name": "'$groupName'",
      "svm": {
        "name": "'$SVM_NAME'"
      }
    }')
    iGroupResult=$(curl -sm $TIMEOUT -X GET -u "$ONTAP_USER":"$FSXN_PASSWORD" -k "https://$FSXN_ADMIN_IP/api/protocols/san/igroups?svm.name=$SVM_NAME&name=$groupName&initiators.name=$InitiatorName&protocol=iscsi&os_type=linux")
    iGroupUuid=$(echo ${iGroupResult} | jq -r '.records[] | select(.name == "'$groupName'" ) | .uuid')

    if [ -n "$iGroupUuid" ]; then
        logMessage "Initiator group ${groupName} was created successfully with UUID: ${iGroupUuid}"
    else
        logMessage "Initiator group ${groupName} was not created, aborting"
        ./uninstall.sh
        exit 1
    fi

    addUndoCommand "curl -sm $TIMEOUT -X DELETE -u \"$ONTAP_USER\":\"$FSXN_PASSWORD\" -k \"https://$FSXN_ADMIN_IP/api/protocols/san/igroups/$iGroupUuid\""
else
    logMessage "Initiator ${InitiatorName} with group ${groupName} already exists, skipping creation."
fi
#
# Get the EC2 instanace ID.
TOKEN=$(curl -sX PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
instance_id=$(curl -sH "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id)
if [ -z "$instance_id" ]; then
  instance_id="unknown"
fi

logMessage "Create volume: ${SVM_NAME} vol: ${VOLUME_NAME} size: ${VOLUME_SIZE}g"
createVolumeResult=$(curl -sm $TIMEOUT -X POST -u "$ONTAP_USER":"$FSXN_PASSWORD" -k "https://$FSXN_ADMIN_IP/api/storage/volumes" -d '{
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
jobStatus=$(curl -sX GET -u "$ONTAP_USER":"$FSXN_PASSWORD" -k "https://$FSXN_ADMIN_IP/api/cluster/jobs/$jobId")
jobState=$(echo "$jobStatus" | jq -r '.state')
if [ "$jobState" != "success" ]; then
    logMessage "Volume creation job did not complete successfully, aborting"
    jobError=$(echo "$jobStatus" | jq -r '.error')
    logMessage "Error details: $jobError"
    ./uninstall.sh
    exit 1
fi

volumeResult=$(curl -sm $TIMEOUT -X GET -u "$ONTAP_USER":"$FSXN_PASSWORD" -k "https://$FSXN_ADMIN_IP/api/storage/volumes?name=${VOLUME_NAME}&svm.name=${SVM_NAME}")
volumeUUid=$(echo "${volumeResult}" | jq -r '.records[] | select(.name == "'$VOLUME_NAME'" ) | .uuid')
if [ -n "$volumeUUid" ]; then
    logMessage "Volume ${VOLUME_NAME} was created successfully with UUID: ${volumeUUid}"
else
    logMessage "Volume ${VOLUME_NAME} was not created, aborting"
    ./uninstall.sh
    exit 1
fi
addUndoCommand "curl -sm $TIMEOUT -X DELETE -u \"$ONTAP_USER\":\"$FSXN_PASSWORD\" -k \"https://$FSXN_ADMIN_IP/api/storage/volumes/${volumeUUid}\""

logMessage "Create iscsi lun: ${SVM_NAME} vol: ${VOLUME_NAME} lun: ${LUN_NAME} size: ${LUN_SIZE}g (90% of volume)"
createLunResult=$(curl -sm $TIMEOUT -X POST -u "$ONTAP_USER":"$FSXN_PASSWORD" -k "https://$FSXN_ADMIN_IP/api/storage/luns" -d '{
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
lunResult=$(curl -sX GET -u "$ONTAP_USER":"$FSXN_PASSWORD" -k "https://$FSXN_ADMIN_IP/api/storage/luns?fields=uuid&name=/vol/${VOLUME_NAME}/$LUN_NAME")

lunUuid=$(echo "${lunResult}" | jq -r '.records[] | select(.name == "'/vol/${VOLUME_NAME}/$LUN_NAME'" ) | .uuid')
if [ -n "$lunUuid" ]; then
    logMessage "LUN ${LUN_NAME} was created successfully with UUID: ${lunUuid}"
else
    logMessage "LUN ${LUN_NAME} was not created, aborting"
    ./uninstall.sh
    exit 1
fi

addUndoCommand "curl -sm $TIMEOUT -X DELETE -u \"$ONTAP_USER\":\"$FSXN_PASSWORD\" -k \"https://$FSXN_ADMIN_IP/api/storage/luns/${lunUuid}\""

logMessage "Create a mapping from the LUN you created to the igroup you created"

lunMapResult=$(curl -sm $TIMEOUT -X POST -u "$ONTAP_USER":"$FSXN_PASSWORD" -k "https://$FSXN_ADMIN_IP/api/protocols/san/lun-maps" -d '{
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

getLunMap=$(curl -sm $TIMEOUT -X GET -u "$ONTAP_USER":"$FSXN_PASSWORD" -k "https://$FSXN_ADMIN_IP/api/protocols/san/lun-maps?lun.name=/vol/${VOLUME_NAME}/${LUN_NAME}&igroup.name=${groupName}&svm.name=${SVM_NAME}")
lunGroupCreated=$(echo "${getLunMap}" | jq -r '.num_records')
if [ "$lunGroupCreated" -eq 0 ]; then
    logMessage "LUN mapping was not created, aborting"
    ./uninstall.sh
    exit 1
else
    logMessage "LUN mapping was created successfully"
fi

addUndoCommand "curl -sm $TIMEOUT -X DELETE -u \"$ONTAP_USER\":\"$FSXN_PASSWORD\" -k \"https://$FSXN_ADMIN_IP/api/protocols/san/lun-maps?lun.name=/vol/${VOLUME_NAME}/${LUN_NAME}&igroup.name=${groupName}&svm.name=${SVM_NAME}\""
#
# Serial hex needed for readable block device name
getLunSerialNumberResult=$(curl -sm $TIMEOUT -X GET -u "$ONTAP_USER":"$FSXN_PASSWORD" -k "https://$FSXN_ADMIN_IP/api/storage/luns?fields=serial_number")
serialNumber=$(echo "${getLunSerialNumberResult}" | jq -r '.records[] | select(.name == "'/vol/$VOLUME_NAME/$LUN_NAME'" ) | .serial_number')
serialHex=$(echo -n "${serialNumber}" | xxd -p)
if [ -z "$serialHex" ]; then
    logMessage "Serial number for the LUN is not available, aborting"
    ./uninstall.sh
    exit 1
fi

logMessage "Get the iscsi interface addresses for the svm ${SVM_NAME}"
getInterfacesResult=$(curl -sm $TIMEOUT -X GET -u "$ONTAP_USER":"$FSXN_PASSWORD" -k "https://$FSXN_ADMIN_IP/api/network/ip/interfaces?svm.name=$SVM_NAME&fields=ip")
iscsi1IP=$(echo "$getInterfacesResult" | jq -r '.records[] | select(.name == "iscsi_1") | .ip.address')
iscsi2IP=$(echo "$getInterfacesResult" | jq -r '.records[] | select(.name == "iscsi_2") | .ip.address')

if [ -n "$iscsi1IP" ] && [ -n "$iscsi2IP" ]; then
    iscsi1IP=$(echo ${iscsi1IP%/*})
    iscsi2IP=$(echo ${iscsi2IP%/*})
    logMessage "iscsi interface addresses for the svm ${SVM_NAME} are: ${iscsi1IP} and ${iscsi2IP}"
else
    logMessage "iscsi interface addresses for the svm ${SVM_NAME} are not available, aborting"
    ./uninstall.sh
    exit 1
fi

logMessage "Discover the target iSCSI nodes, iscsi IP: ${iscsi1IP}"
iscsiadm --mode discovery --op update --type sendtargets --portal $iscsi1IP
checkCommand "${commandDescription}"
addUndoCommand "iscsiadm --mode discovery --op delete --type sendtargets --portal ${iscsi1IP}"
addUndoCommand "iscsiadm --mode discovery --op delete --type sendtargets --portal ${iscsi2IP}"

logMessage "Getting target initiator"
targetInitiator=$(iscsiadm --mode discovery --op update --type sendtargets --portal $iscsi1IP | awk '{print $2}' | head -n 1)
logMessage "Target initiator is: ${targetInitiator}"

iscsiadm --mode node -T $targetInitiator --op update -n node.session.nr_sessions -v 8

logMessage "Log into target initiator: ${targetInitiator}"
iscsiadm --mode node -T $targetInitiator --login
addUndoCommand "iscsiadm --mode node -T $targetInitiator --logout"
#
# Add the following section to the /etc/multipath.conf file:
# defaults {
#   user_friendly_names yes
#   find_multipaths yes
# }
# multipaths {
#    multipath {
#        wwid 3600a0980${serialHex}
#        alias ${VOLUME_NAME}
#    }
# }
logMessage "Update /etc/multipath.conf file, Assign name to block device."

SERIAL_HEX=$serialHex
ALIAS=$VOLUME_NAME
CONF=/etc/multipath.conf

if egrep -q "alias\t*${ALIAS}$" $CONF; then
  echo "Error, there is already an alias in the multipath.conf file for the volume '$ALIAS'. Aborting."
  ./uninstall.sh
  exit 1
fi
cp $CONF ${CONF}_backup
chmod o+rw $CONF

if grep -q 'defaults' $CONF; then
    if grep -q 'user_friendly_names' $CONF; then
      sed -i '/user_friendly_names/s/user_friendly_names.*/user_friendly_names yes/' $CONF
    else
      sed -i '/defaults/a\\tuser_friendly_names yes' $CONF
    fi
    if grep -q 'find_multipaths' $CONF; then
      sed -i '/find_multipaths/s/find_multipaths.*/find_multipaths yes/' $CONF
    else
      sed -i '/defaults/a\\tfind_multipaths yes' $CONF
    fi
else
    printf "\ndefaults {\n\tuser_friendly_names yes\n\tfind_multipaths yes\n}\n" >> $CONF
fi

if egrep -q '^multipaths {' $CONF; then
    sed -i '/^multipaths {/a\\tmultipath {\n\t\twwid 3600a0980'"${SERIAL_HEX}"'\n\t\talias '"${ALIAS}"'\n\t}\n' $CONF
else
    printf "multipaths {\n\tmultipath {\n\t\twwid 3600a0980$SERIAL_HEX\n\t\talias $ALIAS\n\t}\n}\n" >> $CONF
fi

logMessage "Updated /etc/multipath.conf file content: $(cat $CONF)"

commandDescription="Restart multipathd for /etc/multipathd.conf changes"
logMessage "${commandDescription}"
systemctl restart multipathd.service
checkCommand "${commandDescription}"
addUndoCommand "systemctl restart multipathd.service"
addUndoCommand "cp /etc/multipath.conf_backup /etc/multipath.conf"

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

directory_path=mnt
mount_point=$VOLUME_NAME

commandDescription="Create mount point /${directory_path}/${mount_point}"
logMessage "${commandDescription}"
mkdir /$directory_path/$mount_point
checkCommand "${commandDescription}"
addUndoCommand "rm -rf /$directory_path/$mount_point"

commandDescription="Create file system for /dev/mapper/${ALIAS}"
logMessage "${commandDescription}"
mkfs.ext4 /dev/mapper/$ALIAS
checkCommand "${commandDescription}"

commandDescription="Mount the file system"
logMessage "${commandDescription}"
mount -t ext4 /dev/mapper/$ALIAS /$directory_path/$mount_point
checkCommand "${commandDescription}"
addUndoCommand "umount /$directory_path/$mount_point"

commandDescription="Verify read/write access"
logMessage "${commandDescription}"
echo "test mount iscsci" > /$directory_path/$mount_point/testIscsi.txt
cat /$directory_path/$mount_point/testIscsi.txt
checkCommand "${commandDescription}"
rm /$directory_path/$mount_point/testIscsi.txt

logMessage "FSXn iSCSI volume mount successful."

commandDescription="Add mount to /etc/fstab"
logMessage "${commandDescription}"
echo "/dev/mapper/$ALIAS /$directory_path/$mount_point ext4 defaults,_netdev 0 0" >> /etc/fstab
checkCommand "${commandDescription}"
addUndoCommand "sed -i '$d' /etc/fstab"

logMessage "Report usage"
logMessage "Attempting Lambda invoke"
LAMBDA_PAYLOAD='{"ResourceProperties":{"Source":"Deploy_EC2_Wizard","Region":"'$AWS_REGION'"},"RequestType":"CLI"}'

invokeLambda
if [ $? -ne 0 ] && grep -q "initializing" $LambdaErrorFile 2>/dev/null; then
    logMessage "Lambda initializing, retrying in 10s..."
    sleep 10
    invokeLambda
fi

if [ $? -eq 0 ]; then
    logMessage "Usage reporting completed successfully"
else
    logMessage "Usage reporting failed"
fi

logMessage "Script completed successfully."

rm -f uninstall.sh
