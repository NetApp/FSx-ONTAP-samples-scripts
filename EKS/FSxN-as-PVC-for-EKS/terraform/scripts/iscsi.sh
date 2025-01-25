#!/bin/bash
sudo yum install -y lsscsi iscsi-initiator-utils sg3_utils device-mapper-multipath
rpm -q iscsi-initiator-utils
sudo sed -i 's/^\(node.session.scan\).*/\1 = manual/' /etc/iscsi/iscsid.conf
cat /etc/iscsi/initiatorname.iscsi
sudo mpathconf --enable --with_multipathd y --find_multipaths n
#
# Blacklist any EBS volume since they don't support them!
sed -i -e '/^blacklist {/,/^}/{/^}/i\    device {\n        vendor "NVME"\n        product "Amazon Elastic Block Store"\n    }\n' -e '}' /etc/multipath.conf
sudo systemctl enable --now iscsid multipathd
sudo systemctl enable --now iscsi
