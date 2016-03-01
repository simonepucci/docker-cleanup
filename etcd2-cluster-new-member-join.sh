#!/bin/bash
#
#
#
#
#DISCLAIMER    New etcd2 member join cluster
#DISCLAIMER    The current node must be already a proxy member of the 
#DISCLAIMER      cluter in order to join as an active voting member.
#DISCLAIMER    Usage Options: [-nh ]
#DISCLAIMER        -n: dry run: display only commands would be executed.
#DISCLAIMER        -h: help: display usage and exit.

dryrun=false

[ -f functions.sh ] && source ./functions.sh || exit 254

[[ "$*" =~ \-{2}+ ]] && error "Double dash sign '--' not supported";
while getopts "hn" opt "$@"
do
        case $opt in
                n) dryrun=true
                ;;
                h) usage
                ;;
                *) error "Unknown option"
                ;;
        esac
done

TMPDIR="/tmp/etcd2newmemberjoin";
# Consistency checks
systemctl_bin=$(which systemctl 2> /dev/null)
[ -z "${systemctl_bin}" ] && { msg "systemctl command not found, can not run this script."; exit 1; }
etcdctl_bin=$(which etcdctl 2> /dev/null)
[ -z "${etcdctl_bin}" ] && { msg "etcdctl command not found, can not run this script."; exit 1; }
etcd2_bin=$(which etcd2 2> /dev/null)
[ -z "${etcd2_bin}" ] && { msg "etcd2 command not found, can not run this script."; exit 1; }
[ -z "${TMPDIR}" ] && { msg "critical error an internal var was unset, doublecheck the content of current script"; exit 255; } || rm -rf ${TMPDIR};
mkdir -p ${TMPDIR};
${etcdctl_bin} member list > ${TMPDIR}/list
[ $? -ne 0 ] && { msg "Some error occurred while listing cluster members, verify that current host is already a proxy member of a healthy cluster"; exit 1; }
grep -q ${COREOS_PRIVATE_IPV4} ${TMPDIR}/list && { msg "Current host is already a member of the cluster."; exit 1; }
${etcdctl_bin} cluster-health > ${TMPDIR}/health
[ $? -ne 0 ] && { msg "Some error occurred while checking cluster health, verify that cluster is healthy"; exit 1; }
cat ${TMPDIR}/list | cut -d ':' -f 1 | while read CLUHSTID;
do
    grep -q "member ${CLUHSTID} is healthy" ${TMPDIR}/health || { msg "Critical error: the following cluster member is unhealthy: ${CLUHSTID}"; exit 1; }
done

msg "Consistency checks passed. Now try to effectively join etcd2 cluster.";
source /etc/environment
ETCD2DIR="/media/etcd";
[ -d ${ETCD2DIR}/proxy ] || { msg "Etcd2 Media dir is missing... exiting without any modification."; exit 1; }
MACHINEID=$(cat /etc/machine-id)
[ -z "${MACHINEID}" ] && { msg "MachineId is empty, check the code... exiting without any modification."; exit 1; }
if [ "${dryrun}" == true ];
then
    msg "${etcdctl_bin} member add ${MACHINEID} http://${COREOS_PRIVATE_IPV4}:2380";
    msg "${systemctl_bin} stop etcd2.service";
    msg "rm -rf ${ETCD2DIR}/proxy";
    msg "${etcd2_bin} -listen-client-urls http://${COREOS_PRIVATE_IPV4}:2379 -advertise-client-urls http://${COREOS_PRIVATE_IPV4}:2379  -listen-peer-urls http://${COREOS_PRIVATE_IPV4}:2380 -initial-advertise-peer-urls http://${COREOS_PRIVATE_IPV4}:2380 -data-dir ${ETCD2DIR}";
else
    CLUDETAILS=$(${etcdctl_bin} member add ${MACHINEID} http://${COREOS_PRIVATE_IPV4}:2380);
    [ $? -ne 0 ] && { msg "Adding member returned an error, system was modified. Remove the member if unhealthy: ${etcdctl_bin} member remove ${MACHINEID}"; exit 1; }
    ${systemctl_bin} stop etcd2.service
    [ $? -ne 0 ] && { msg "Some errors happened while gracefully stopping etcd2 proxy service, tring to kill it.. "; killall -9 etcd2; }
    ps ax | grep -v grep | grep -q "${etcd2_bin}" && { msg "Some errors happened while killing etcd2 proxy service: check it throught: ${systemctl_bin} status etcd2.service"; exit 1; }
    rm -rf ${ETCD2DIR}/proxy;
    eval export $(echo "${CLUDETAILS}" | tail -n-3);
    ${etcd2_bin} -listen-client-urls http://${COREOS_PRIVATE_IPV4}:2379 -advertise-client-urls http://${COREOS_PRIVATE_IPV4}:2379  -listen-peer-urls http://${COREOS_PRIVATE_IPV4}:2380 -initial-advertise-peer-urls http://${COREOS_PRIVATE_IPV4}:2380 -data-dir ${ETCD2DIR} &
fi
msg "Check if the current node is now active member of the cluster running the following command on another node: etcdctl cluster-health, then reboot current node.";

