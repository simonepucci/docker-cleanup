#!/bin/bash
#
#
#
#
#DISCLAIMER    Mantain discoveryurl aligned with current members
#DISCLAIMER    The current node must be already a proxy or an active member of the
#DISCLAIMER      cluster in order to run this script successfully.
#DISCLAIMER    More Info at https://coreos.com/etcd/docs/latest/admin_guide.html
#DISCLAIMER    This script will print out curls that must be manually run.
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

[ -d /dev/shm ] && TMPCACHEFOLD="/dev/shm" || TMPCACHEFOLD="/tmp"
TMPDIR="${TMPCACHEFOLD}/fixdiscoveryurl";

# Consistency checks
msg "Running Consistency checks."
# Verify if required binaries are present
systemctl_bin=$(which systemctl 2> /dev/null)
[ -z "${systemctl_bin}" ] && { msg "systemctl command not found, can not run this script."; exit 255; }
etcdctl_bin=$(which etcdctl 2> /dev/null)
[ -z "${etcdctl_bin}" ] && { msg "etcdctl command not found, can not run this script."; exit 255; }
grep_bin=$(which grep 2> /dev/null)
[ -z "${grep_bin}" ] && { msg "grep command not found, can not run this script."; exit 255; }
cat_bin=$(which cat 2> /dev/null)
[ -z "${cat_bin}" ] && { msg "cat command not found, can not run this script."; exit 255; }
cut_bin=$(which cut 2> /dev/null)
[ -z "${cut_bin}" ] && { msg "cut command not found, can not run this script."; exit 255; }
curl_bin=$(which curl 2> /dev/null)
[ -z "${curl_bin}" ] && { msg "curl command not found, can not run this script."; exit 255; }
# Verify temp path is accessible
[ -z "${TMPDIR}" ] && { msg "Error: TMPDIR var was unset, doublecheck the content of current script"; exit 255; }
rm -rf ${TMPDIR} || { msg "Error, can not delete folder: ${TMPDIR}, check permissions."; exit 255; }
mkdir -p ${TMPDIR} || { msg "Error, can not create folder: ${TMPDIR}, check permissions."; exit 255; }


TMPDUCURRENT="${TMPDIR}/tduc.txt";
TMPDUTXT="${TMPDIR}/tduc-json.txt";
TMPMLCURRENT="${TMPDIR}/tmlc.txt";
DISCOVERYURL=$( ${systemctl_bin} cat etcd2.service | ${grep_bin} ETCD_DISCOVERY | ${grep_bin} -Eo 'https://discovery.etcd.io/.[0-9a-z]+'|${cut_bin} -d '/' -f 4 );

${curl_bin} https://discovery.etcd.io/${DISCOVERYURL} -o ${TMPDUCURRENT};
${cat_bin} ${TMPDUCURRENT} | ./JSON.sh > ${TMPDUTXT};
${etcdctl_bin} member list > ${TMPMLCURRENT};

${grep_bin} -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}' ${TMPDUCURRENT} | while read ipaddress;
do
    #Remove if not actually member
    ${grep_bin} -q ${ipaddress} ${TMPMLCURRENT};
    if [ $? -ne 0 ];
    then
	NODEID=$( grep ${ipaddress} ${TMPDUTXT} | awk '{print $1}' | cut -f '3' -d ',' | grep -o '[0-9]*' | sort -n | uniq );
        NODE=$(egrep "\[\"node\"\,\"nodes\"\,${NODEID}\,\"key\"\]" ${TMPDUTXT} | cut -f '8' -d '"' | cut -d '/' -f 5);
        echo "${curl_bin} https://discovery.etcd.io/${DISCOVERYURL}/${NODE} -XDELETE";
    fi
done

${grep_bin} -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}' ${TMPMLCURRENT} | while read ipaddress;
do
    #Add node if not present in DISCOVERYURL
    ${grep_bin} -q ${ipaddress} ${TMPDUCURRENT};
    if [ $? -ne 0 ];
    then
        NODE=$( ${grep_bin} ${ipaddress} ${TMPMLCURRENT} | ${cut_bin} -d ':' -f 1 );
	NODEID=$( grep ${ipaddress} ${TMPDUTXT} | awk '{print $1}' | cut -f '3' -d ',' | grep -o '[0-9]*' | sort -n | uniq );
        LNODE=$(egrep "\[\"node\"\,\"nodes\"\,${NODEID}\,\"value\"\]" ${TMPDUTXT} | cut -f '8' -d '"');
        echo "${curl_bin} -H \"Content-Type: application/json\" -XPUT -sSL \"https://discovery.etcd.io/${DISCOVERYURL}/${NODE}?value=${LNODE}\"";
    fi
done

rm -rf ${TMPDIR}
