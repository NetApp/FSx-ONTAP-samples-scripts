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
