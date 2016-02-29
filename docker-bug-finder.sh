#!/bin/bash
#
#
#
#DISCLAIMER    This script is intended to be run from ctl-machine.
#DISCLAIMER    Run docker check parsing system logs
#DISCLAIMER    Usage Options: [-nh ]
#DISCLAIMER        -n: dry run: display only what would get removed.
#DISCLAIMER        -h: help: display usage and exit.



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
[ $# -gt 2 ] && usage || IPADDRESS="$(eval "echo -n \$$#")";
TUNHOST=$(echo ${IPADDRESS} | grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}');
[ -z "${TUNHOST}" ] && { echo -e "Missing required argument.\nUsage: $0 IPADDRESS"; exit 1; }

ssh -i .ssh/deis core@${TUNHOST} "fleetctl list-units|grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}'" | sort | uniq | xargs > /dev/shm/ip
for IPADDRESS in $(cat /dev/shm/ip);
do
    BUG="";
    BUG=$( ssh -i .ssh/deis core@$IPADDRESS 'journalctl -r | grep -m 1 -Ei "Failed to allocate and map port: iptables failed|Could not generate persistent MAC address for .*: No such file or directory|Daemon has completed initialization"
' )
    [ -z "${BUG}" ] && continue;
    echo "${BUG}" | grep -q "Daemon has completed initialization" && msg "Docker Was restarted on Host: ${IPADDRESS}" || msg "Docker Bug is Affecting Host: ${IPADDRESS} - ${BUG}";
done

#journalctl -r | grep -m 1 -Ei "Failed to allocate and map port: iptables failed|Could not generate persistent MAC address for .*: No such file or directory|Daemon has completed initialization"


