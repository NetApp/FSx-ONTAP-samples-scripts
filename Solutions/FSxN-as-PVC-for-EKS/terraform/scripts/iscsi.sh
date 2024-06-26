#!/bin/bash
sudo yum install -y lsscsi iscsi-initiator-utils sg3_utils device-mapper-multipath
rpm -q iscsi-initiator-utils
sudo sed -i 's/^\(node.session.scan\).*/\1 = manual/' /etc/iscsi/iscsid.conf
cat /etc/iscsi/initiatorname.iscsi
sudo mpathconf --enable --with_multipathd y --find_multipaths n
sudo systemctl enable --now iscsid multipathd
sudo systemctl enable --now iscsi
