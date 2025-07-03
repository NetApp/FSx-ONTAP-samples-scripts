#!/bin/bash

# user data
# Set the secret name and region
SECRET_NAME=[Secret name has it been saved in AWS secret manager]
AWS_REGION=[AWS region]

FSXN_PASSWORD=[Fsx admin password, e.g. fsxadmin123]
FSXN_ADMIN_IP=[Fsx admin ip, e.g. 172.25.45.32]
# Volume name
VOLUME_NAME=[Fsx volume name, e.g. iscsiVol]
# Volume size in GB
VOLUME_SIZE=[volume size in GB, e.g 100g]
# Default value is fsx, but you can change it to any other value according to yours FSx for ONTAP SVM name
SVM_NAME=fsx
# end - user data


min=100
max=999
LUN_NAME=${VOLUME_NAME}_$(($RANDOM%($max-$min+1)+$min))

# defaults
ONTAP_USER=fsxadmin
LOG_FILE=/home/ec2-user/install.log

VOL_SIZE=$(echo $VOLUME_SIZE | sed 's/.$//')
LUN_SIZE=$(bc -l <<< "0.85*$VOL_SIZE" )

echo "# Uninstall file" >> uninstall.sh
sudo chmod u+x uninstall.sh

function getSecretValue() {
    secret_name=$1
    aws_region=$2
    SECRET_VALUE=$(aws secretsmanager get-secret-value \
        --secret-id "$secret_name" \
        --region "$aws_region" \
        --query 'SecretString' \
        --output text)
    
    if [ $? -ne 0 ]; then
        echo "Failed to retrieve the secret: $secret_name, Aborting."
        exit 1
    fi
}

function fsxnSshCommand(){
    command = $1
    sshpass -p $FSXN_PASSWORD ssh -o StrictHostKeyChecking=no fsxadmin@$FSXN_ADMIN_IP $command
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

logMessage "Get secret data"
getSecretValue "${SECRET_NAME}" "${AWS_REGION}"
FSXN_PASSWORD=$SECRET_VALUE
logMessage "Secret data retrieved successfully"

commandDescription="Install linux iSCSI packages"
logMessage "${commandDescription}"
sudo yum install -y device-mapper-multipath iscsi-initiator-utils
checkCommand "${commandDescription}"
addUndoCommand "sudo yum remove -y device-mapper-multipath iscsi-initiator-utils"

commandDescription="Set multisession replacment time from default 120 sec to 5 sec"
logMessage "${commandDescription}"
sudo sed -i 's/node.session.timeo.replacement_timeout = .*/node.session.timeo.replacement_timeout = 5/' /etc/iscsi/iscsid.conf; sudo cat /etc/iscsi/iscsid.conf | grep node.session.timeo.replacement_timeout
checkCommand "${commandDescription}"
addUndoCommand "sudo sed -i 's/node.session.timeo.replacement_timeout = .*/node.session.timeo.replacement_timeout = 120/' /etc/iscsi/iscsid.conf; sudo cat /etc/iscsi/iscsid.conf | grep node.session.timeo.replacement_timeout"

commandDescription="Start iscsi service"
logMessage "${commandDescription}"
sudo service iscsid start
checkCommand "${commandDescription}"

# check if the service is running
isIscsciServiceRunning=$(sudo service iscsid status | grep "Active: active (running)" | wc -l)
if [ "$isIscsciServiceRunning" -eq 1 ]; then
    logMessage "iscsi service is running"
    addUndoCommand "sudo service iscsid stop"
else
    logMessage "iscsi service is not running, aborting"
    # now we have to rollback and exit
    ./uninstall.sh
fi

commandDescription="Set multipath configuration which allow automatic failover between yours file servers"
logMessage "${commandDescription}"
sudo mpathconf --enable --with_multipathd y
checkCommand "${commandDescription}"
addUndoCommand "sudo mpathconf --disable"

# set the initiator name of your Linux host
name=$(sudo cat /etc/iscsi/initiatorname.iscsi)
initiatorName="${name:14}"
logMessage "initiatorName is: ${initiatorName}"

# Configure iSCSI on the FSx for ONTAP file system
commandDescription="Install sshpass which will allow to connect FSXn using SSH"
logMessage "${commandDescription}"
sudo yum install -y sshpass
checkCommand "${commandDescription}"
addUndoCommand "sudo yum remove -y sshpass"

# Test connection to ONTAP
commandDescription="Testing connection to ONTAP."
logMessage "${commandDescription}"
sshpass -p $FSXN_PASSWORD ssh -o StrictHostKeyChecking=no $ONTAP_USER@$FSXN_ADMIN_IP "version"
checkCommand "${commandDescription}"

# group name should be the hostname of the linux host
groupName=$(hostname)

commandDescription="Create initiator group for vserver: ${SVM_NAME} group name: ${groupName} and intiator name: ${initiatorName}"

lunGroupresult=${sshpass -p $FSXN_PASSWORD ssh -o StrictHostKeyChecking=no $ONTAP_USER@$FSXN_ADMIN_IP "lun igroup show -vserver $SVM_NAME -igroup $groupName -initiator $initiatorName -protocol iscsi -ostype linux"}
if [[ "$lunGroupresult" == *"There are no entries matching your query."* ]]; then
    logMessage "Initiator ${initiatorName} with group ${groupName} does not exist, creating it."
    logMessage "${commandDescription}"
    sshpass -p $FSXN_PASSWORD ssh -o StrictHostKeyChecking=no $ONTAP_USER@$FSXN_ADMIN_IP "lun igroup create -vserver $SVM_NAME -igroup $groupName -initiator $initiatorName -protocol iscsi -ostype linux"
    checkCommand "${commandDescription}"
    addUndoCommand "sshpass -p ${FSXN_PASSWORD} ssh -o StrictHostKeyChecking=no ${ONTAP_USER}@${FSXN_ADMIN_IP} lun igroup delete -vserver ${SVM_NAME} -igroup ${groupName} -force"
else
    logMessage "Initiator ${initiatorName} with group ${groupName} already exists, skipping creation."
fi

# confirm that igroup was created
isInitiatorGroupCreadted=$(sshpass -p $FSXN_PASSWORD ssh -o StrictHostKeyChecking=no $ONTAP_USER@$FSXN_ADMIN_IP "lun igroup show -igroup $groupName -protocol iscsi" | grep $groupName | wc -l)
if [ "$isInitiatorGroupCreadted" -eq 1 ]; then
    logMessage "Initiator group ${groupName} was created"
else
    logMessage "Initiator group ${groupName} was not created, aborting"
    # now we have to rollback and exit
    ./uninstall.sh
fi

commandDescription="Create volume for vserver: ${SVM_NAME} volume name: ${VOLUME_NAME} and size: ${VOLUME_SIZE}"
logMessage "${commandDescription}"
sshpass -p $FSXN_PASSWORD ssh -o StrictHostKeyChecking=no $ONTAP_USER@$FSXN_ADMIN_IP "volume create -vserver $SVM_NAME -volume $VOLUME_NAME -aggregate aggr1 -size $VOLUME_SIZE -state online"
checkCommand "${commandDescription}"
addUndoCommand "sshpass -p ${FSXN_PASSWORD} ssh -o StrictHostKeyChecking=no ${ONTAP_USER}@${FSXN_ADMIN_IP} volume delete -vserver ${SVM_NAME} -volume ${VOLUME_NAME} -force"

commandDescription="Create iscsi lun for vserver: ${SVM_NAME} volume name: ${VOLUME_NAME} and lun name: ${LUN_NAME} and size: ${LUN_SIZE}g"
logMessage "${commandDescription}"
sshpass -p $FSXN_PASSWORD ssh -o StrictHostKeyChecking=no $ONTAP_USER@$FSXN_ADMIN_IP "lun create -vserver $SVM_NAME -path /vol/$VOLUME_NAME/$LUN_NAME -size "${LUN_SIZE}g" -ostype linux -space-allocation enabled"
checkCommand "${commandDescription}"
addUndoCommand "sshpass -p ${FSXN_PASSWORD} ssh -o StrictHostKeyChecking=no ${ONTAP_USER}@${FSXN_ADMIN_IP} lun delete -vserver ${SVM_NAME} -path /vol/${VOLUME_NAME}/${LUN_NAME} -force"

# Create a mapping from the LUN you created to the igroup you created
# The LUN ID integer is specific to the mapping, not to the LUN itself. 
# This is used by the initiators in the igroup as the Logical Unit Number use this value for the initiator when accessing the storage. 
commandDescription="Create a mapping from the LUN you created to the igroup you created"
logMessage "${commandDescription}"
lun_id=0
sshpass -p $FSXN_PASSWORD ssh -o StrictHostKeyChecking=no $ONTAP_USER@$FSXN_ADMIN_IP "lun mapping create -vserver $SVM_NAME -path /vol/$VOLUME_NAME/$LUN_NAME -igroup $groupName -lun-id 0"
checkCommand "${commandDescription}"

commandDescription="Validate the lun mapping was created"
logMessage "${commandDescription}"
serialHex=$(sshpass -p $FSXN_PASSWORD ssh -o StrictHostKeyChecking=no $ONTAP_USER@$FSXN_ADMIN_IP "lun show -path /vol/$VOLUME_NAME/$LUN_NAME -fields state,mapped,serial-hex" | grep $SVM_NAME | awk '{print $3}')
if [ -n "$serialHex" ]; then
    logMessage "Lun mapping was created"
else
    logMessage "Lun mapping was not created, aborting"
    addUndoCommand "sshpass -p ${FSXN_PASSWORD} ssh -o StrictHostKeyChecking=no ${ONTAP_USER}@${FSXN_ADMIN_IP} lun mapping delete -vserver ${SVM_NAME} -path /vol/${VOLUME_NAME}/${LUN_NAME} -igroup ${groupName}"    
fi

# The serail hex in needed for creating readable name for the block device.
commandDescription="Get the iscsi interface addresses for the svm ${SVM_NAME}"
logMessage "${commandDescription}"
iscsi1IP=$(sshpass -p $FSXN_PASSWORD ssh -o StrictHostKeyChecking=no $ONTAP_USER@$FSXN_ADMIN_IP "network interface show -vserver $SVM_NAME"  | grep -e iscsi_1 | awk '{print $3}')
iscsi2IP=$(sshpass -p $FSXN_PASSWORD ssh -o StrictHostKeyChecking=no $ONTAP_USER@$FSXN_ADMIN_IP "network interface show -vserver $SVM_NAME"  | grep -e iscsi_2 | awk '{print $3}')

if [ -n "$i$iscsi1IP" ] && [ -n "$iscsi2IP" ]; then
    iscsi1IP=$(echo ${iscsi1IP%/*})
    iscsi2IP=$(echo ${iscsi2IP%/*})
    logMessage "iscsi interface addresses for the svm ${SVM_NAME} are: ${iscsi1IP} and ${iscsi2IP}"
else
    logMessage "iscsi interface addresses for the svm ${SVM_NAME} are not available, aborting"
    # now we have to rollback and exit
    ./uninstall.sh
fi

commandDescription="Discover the target iSCSI nodes, iscsi IP: ${iscsi1IP}"
logMessage "${commandDescription}"
sudo iscsiadm --mode discovery --op update --type sendtargets --portal $iscsi1IP
checkCommand "${commandDescription}"
addUndoCommand "sudo iscsiadm --mode discovery --op delete --type sendtargets --portal $iscsi1IP"
addUndoCommand "sudo iscsiadm --mode discovery --op delete --type sendtargets --portal $iscsi2IP"

logMessage "Getting target initiator"
targetInitiator=$(sudo iscsiadm --mode discovery --op update --type sendtargets --portal $iscsi1IP | awk '{print $2}' | head -n 1)
logMessage "Target initiator is: ${targetInitiator}"

# update the number of sessions to 8 (optional step)
#sudo iscsiadm --mode node -T $targetInitiator --op update -n node.session.nr_sessions -v 8

# Log into the target initiators. Your iSCSI LUNs are presented as available disks
logMessage "Log into target initiator: ${targetInitiator}"
sudo iscsiadm --mode node -T $targetInitiator --login
addUndoCommand "sudo iscsiadm --mode node -T $targetInitiator --logout"

# verify that dm-multipath has identified and merged the iSCSI sessions
sudo multipath -ll 
device_name=fsxontap

# Add the following section to the /etc/multipath.conf file:
# multipaths {
#    multipath {
#        wwid 3600a0980${serialHex}
#        alias ${device_name}
#    }
# }
# Assign name to block device, this should be function that will get serial hex and device name
commandDescription="Update /etc/multipath.conf file, Assign name to block device."
logMessage "${commandDescription}"
sudo cp /etc/multipath.conf /etc/multipath.conf_backup

SERIAL_HEX=$serialHex
#ALIAS=$device_name
ALIAS=$VOLUME_NAME
CONF=/etc/multipath.conf
sudo chmod o+rw $CONF
sudo grep -q '^multipaths {' $CONF
UNCOMMENTED=$?
if [ $UNCOMMENTED -eq 0 ]; then
    sudo sed -i '/^multipaths {/a\\tmultipath {\n\t\twwid 3600a0980'"${SERIAL_HEX}"'\n\t\talias '"${ALIAS}"'\n\t}\n' $CONF
else
    sudo printf "multipaths {\n\tmultipath {\n\t\twwid 3600a0980$SERIAL_HEX\n\t\talias $ALIAS\n\t}\n}" >> $CONF
fi

fileContent=$(cat $CONF)
logMessage "Updated /etc/multipath.conf file content: $fileContent"

commandDescription="Restart the multipathd service for the changes at: /etc/multipathd.conf will take effect."
logMessage "${commandDescription}"
sudo systemctl restart multipathd.service
checkCommand "${commandDescription}"
addUndoCommand "sudo cp /etc/multipath.conf_backup /etc/multipath.conf"
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
# mount the LUN on the Linux client

# Create a directory directory_path as the mount point for your file system.
directory_path=mnt
mount_point=$VOLUME_NAME

commandDescription="Create a directory /${directory_path}/${mount_point} as the mount point for your file system"
logMessage "${commandDescription}"
sudo mkdir /$directory_path/$mount_point
checkCommand "${commandDescription}"
addUndoCommand "sudo rm -rf /$directory_path/$mount_point"

#check this command
# volume_name=the frindly device name as we set it in the multipath.conf file
commandDescription="Creating the file system for the new partition: /dev/mapper/${ALIAS}"
logMessage "${commandDescription}"
sudo mkfs.ext4 /dev/mapper/$ALIAS
checkCommand "${commandDescription}"

commandDescription="Mount the file system using the following command."
logMessage "${commandDescription}"
sudo mount -t ext4 /dev/mapper/$ALIAS /$directory_path/$mount_point
checkCommand "${commandDescription}"
addUndoCommand "sudo umount /$directory_path/$mount_point"

username=$(whoami)
sudo chown $username:$username /$directory_path/$mount_point

# verify read write
# example: echo "test mount iscsci" > /mnt/myIscsi/testIscsi.txt
echo "test mount iscsci" > /$directory_path/$mount_point/testIscsi.txt
cat /$directory_path/$mount_point/testIscsci.txt

logMessage "Mounting the FSXn iSCSI volume was successful."

rm -f uninstall.sh