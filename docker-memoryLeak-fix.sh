#!/bin/bash
#
#
#	Restart docker if memory leak happened...

systemctl restart docker.service

sleep 9;

fleetctl list-units|grep $COREOS_PRIVATE_IPV4 | grep -Ev 'running|docker-clean' | grep 'dead' | awk '{print $1}'| while read line;
do
    systemctl restart "${line}";
    sleep 1;
done


fleetctl list-units|grep $COREOS_PRIVATE_IPV4
