#!/bin/bash
#
#
#	Restart docker if memory leak happened...
cat > /etc/systemd/system/docker.service.d/10-increase-ulimit.conf <<EOF
[Service]
LimitMEMLOCK=infinity
LimitNOFILE=1048576
LimitNPROC=1048576
EOF

systemctl daemon-reload
systemctl restart docker.service

sleep 9;

fleetctl list-units|grep $COREOS_PRIVATE_IPV4 | grep -Ev 'running|docker-clean' | grep 'dead' | awk '{print $1}'| while read line;
do
    systemctl restart "${line}";
    sleep 1;
done


fleetctl list-units|grep $COREOS_PRIVATE_IPV4
