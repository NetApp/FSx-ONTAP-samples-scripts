#!/bin/bash
#
# Set the ARN of the secret that should contain just the password for the ONTAP admin user set below.
SECRET_ARN=""
#
# Set the FSx admin IP.
FSXN_ADMIN_IP=""
#
# Set the name of the volume to be created on the FSx for ONTAP file system. Note, volume names cannot have dashes in them.
VOLUME_NAME=""
#
# Set the volume size in GB. It should just be a number, without the 'GB' suffix.
VOLUME_SIZE=
#
# Set the SVM name. The default is 'fsx'.
SVM_NAME="fsx"
#
# Set the ONTAP admin user. The default is fsxadmin.
ONTAP_USER="fsxadmin"
#
################################################################################
# ****  You should not need to edit anything below this line ****
################################################################################
#
# When called from the CloudFormation template, the parameters are passsed as
# arguments.
SECRET_ARN="${SECRET_ARN:=$1}"
FSXN_ADMIN_IP="${FSXN_ADMIN_IP:=$2}"
VOLUME_NAME="${VOLUME_NAME:=$3}"
VOLUME_SIZE="${VOLUME_SIZE:=$4}"
SVM_NAME="${5:-$SVM_NAME}"
ONTAP_USER="${6:-$ONTAP_USER}"
#
# Since AWS only allows up to 16KB for the user data script, the rest of this script
# will be the compressed version of the linux_userData_real.sh file, which will be
# uncompressed and executed on the EC2 instance when it is deployed.
cat <<EOF2 > /tmp/linux_userData.sh
#!/bin/bash
export SECRET_ARN="$SECRET_ARN"
export FSXN_ADMIN_IP="$FSXN_ADMIN_IP"
export VOLUME_NAME="$VOLUME_NAME"
export VOLUME_SIZE="$VOLUME_SIZE"
export SVM_NAME="$SVM_NAME"
export ONTAP_USER="$ONTAP_USER"
EOF2

cat <<EOF3 | base64 -d | gunzip >> /tmp/linux_userData.sh
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
EOF3

chmod +x /tmp/linux_userData.sh
/tmp/linux_userData.sh
