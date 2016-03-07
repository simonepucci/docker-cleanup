#!/bin/bash
#
#
#
#
#DISCLAIMER    New etcd2 member join cluster
#DISCLAIMER    The current node must be already a proxy member of the 
#DISCLAIMER      cluster in order to join as an active voting member.
#DISCLAIMER    More Info at https://coreos.com/etcd/docs/latest/admin_guide.html
#DISCLAIMER    If you need to manually remove a node from discovery url, do it via curl
#DISCLAIMER        curl -sSL https://discovery.etcd.io/<DISCOVERYID>/<MEMBERID> -XDELETE
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

ETCD2DIR="/media/etcd";
[ -d /dev/shm ] && TMPCACHEFOLD="/dev/shm" || TMPCACHEFOLD="/tmp"
TMPDIR="${TMPCACHEFOLD}/etcd2nmj";

# Consistency checks
msg "Running Consistency checks."
# Verify if required binaries are present
systemctl_bin=$(which systemctl 2> /dev/null)
[ -z "${systemctl_bin}" ] && { msg "systemctl command not found, can not run this script."; exit 255; }
etcdctl_bin=$(which etcdctl 2> /dev/null)
[ -z "${etcdctl_bin}" ] && { msg "etcdctl command not found, can not run this script."; exit 255; }
etcd2_bin=$(which etcd2 2> /dev/null)
[ -z "${etcd2_bin}" ] && { msg "etcd2 command not found, can not run this script."; exit 255; }
grep_bin=$(which grep 2> /dev/null) 
[ -z "${grep_bin}" ] && { msg "grep command not found, can not run this script."; exit 255; }
cut_bin=$(which cut 2> /dev/null) 
[ -z "${cut_bin}" ] && { msg "cut command not found, can not run this script."; exit 255; }
ps_bin=$(which ps 2> /dev/null) 
[ -z "${ps_bin}" ] && { msg "ps command not found, can not run this script."; exit 255; }
# Verify temp path is accessible
[ -z "${TMPDIR}" ] && { msg "Error: TMPDIR var was unset, doublecheck the content of current script"; exit 255; }
rm -rf ${TMPDIR} || { msg "Error, can not delete folder: ${TMPDIR}, check permissions."; exit 255; }
mkdir -p ${TMPDIR} || { msg "Error, can not create folder: ${TMPDIR}, check permissions."; exit 255; }
# Verify existence of etcd2 media proxy folder
[ -d ${ETCD2DIR}/proxy ] || { msg "Etcd2 Media/proxy dir is missing... The current node must be a proxy."; exit 1; }
# Verify required environment variables are present
MACHINEID=$(cat /etc/machine-id)
[ -z "${MACHINEID}" ] && { msg "MachineId is empty, check the code... and the content of /etc/machine-id"; exit 1; }
PRIVATE_IPV4=$(${grep_bin} "COREOS_PRIVATE_IPV4" /etc/environment | ${grep_bin} -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}')
[ -z "${PRIVATE_IPV4}" ] && { msg "Some error occurred while reading PRIVATE_IPV4 from /etc/environment, check the code..."; exit 1; }
# Verify current cluster has members
${etcdctl_bin} member list > ${TMPDIR}/list 2>/dev/null
[ $? -ne 0 ] && { msg "Some error occurred while listing cluster members, verify that current host is already a proxy member of a healthy cluster"; exit 1; }
[ -s ${TMPDIR}/list ] || { msg "The file: ${TMPDIR}/list is empty, try to check the output of the following command: ${etcdctl_bin} member list"; exit 1; }
${grep_bin} -q ${PRIVATE_IPV4} ${TMPDIR}/list && { msg "Current host is already a member of the cluster. Remove it and retry running this script."; exit 1; }

# Verify current cluster members healthy
${etcdctl_bin} cluster-health > ${TMPDIR}/health 2>/dev/null
[ $? -ne 0 ] && { msg "Some error occurred while checking cluster health, verify that cluster is healthy"; exit 1; }
[ -s ${TMPDIR}/health ] || { msg "The file: ${TMPDIR}/health is empty, try to check the output of the following command: ${etcdctl_bin} cluster-health"; exit 1; }

${cut_bin} -d ':' -f 1 ${TMPDIR}/list | while read CLUHSTID;
do
    ${grep_bin} -Eiq "member(\ *)${CLUHSTID}(\ *)is(\ *)healthy" ${TMPDIR}/health || { msg "Critical error: the following cluster member is unhealthy: ${CLUHSTID}"; exit 1; }
done

# Cluster node join as active member
msg "Consistency checks passed."
if [ "${dryrun}" == true ];
then
    msg "DryRun was set. Printing commands that would be executed:"
    msg "${etcdctl_bin} member add ${MACHINEID} http://${PRIVATE_IPV4}:2380";
    msg "${systemctl_bin} stop etcd2.service";
    msg "rm -rf ${ETCD2DIR}/proxy";
    msg "${etcd2_bin} -listen-client-urls http://${PRIVATE_IPV4}:2379 -advertise-client-urls http://${PRIVATE_IPV4}:2379  -listen-peer-urls http://${PRIVATE_IPV4}:2380 -initial-advertise-peer-urls http://${PRIVATE_IPV4}:2380 -data-dir ${ETCD2DIR}";
else
    msg "Trying to join etcd2 cluster.";
    CLUDETAILS=$(${etcdctl_bin} member add ${MACHINEID} http://${PRIVATE_IPV4}:2380);
    [ $? -ne 0 ] && { msg "Adding member returned an error, system was modified. Remove the member if unhealthy: ${etcdctl_bin} member remove ${MACHINEID}"; exit 1; }
    ${systemctl_bin} stop etcd2.service
    [ $? -ne 0 ] && { msg "Some errors happened while gracefully stopping etcd2 proxy service, tring to kill it.. "; killall -9 etcd2; }
    ${ps_bin} ax | ${grep_bin} -v grep | ${grep_bin} -q "${etcd2_bin}" && { msg "Some errors happened while killing etcd2 proxy service: check it throught: ${systemctl_bin} status etcd2.service"; exit 1; }
    rm -rf ${ETCD2DIR}/proxy;
    eval export $(echo "${CLUDETAILS}" | tail -n-3);
    nohup ${etcd2_bin} -listen-client-urls http://${PRIVATE_IPV4}:2379 -advertise-client-urls http://${PRIVATE_IPV4}:2379  -listen-peer-urls http://${PRIVATE_IPV4}:2380 -initial-advertise-peer-urls http://${PRIVATE_IPV4}:2380 -data-dir ${ETCD2DIR} &> /dev/null &
fi
msg "Check if the current node is now active member of the cluster running the following command on another node: etcdctl cluster-health, then reboot current node.";

