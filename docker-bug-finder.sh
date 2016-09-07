#!/bin/bash
#
#
#
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

[ -f /etc/environment ] && source /etc/environment;

BUG="";
BUG=$( journalctl -r | grep -m 1 -Ei "Failed to allocate and map port: iptables failed|Daemon has completed initialization" )
#BUG=$( journalctl -r | grep -m 1 -Ei "Failed to allocate and map port: iptables failed|Could not generate persistent MAC address for .*: No such file or directory|Daemon has completed initialization" )
[ -z "${BUG}" ] && exit 0;
echo "${BUG}" | grep -q "Daemon has completed initialization" && msg "Docker Was restarted on Host: ${COREOS_PRIVATE_IPV4}" || msg "Docker Bug is Affecting Host: ${COREOS_PRIVATE_IPV4} - ${BUG}";

#journalctl -r | grep -m 1 -Ei "Failed to allocate and map port: iptables failed|Could not generate persistent MAC address for .*: No such file or directory|Daemon has completed initialization"

#Censimento macchine
curl http://10.21.1.131/$COREOS_PRIVATE_IPV4 > /dev/null
