#!/bin/bash
#
#
#
#DISCLAIMER    Run extra commands if /tmp/RUN is present.
#DISCLAIMER    Read line per line /tmp/RUN content and run fleetctl start, if is not already running.
#DISCLAIMER    Usage Options: [-nh ]
#DISCLAIMER        -n: dry run: display only what would get removed.
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

fleetctl_bin=$(which fleetctl 2> /dev/null)
[ -z "${fleetctl_bin}" ] && { msg "fleetctl command not found, can not run this script."; exit 1; }
#set -eou pipefail

[ -f /tmp/RUN ] || { msg "Exiting without running any extra command."; exit 0; }

cat /tmp/RUN | while read line;
do
    if [ "${dryrun}" == true ];
    then
        msg "The following extra commands would be executed: fleetctl start ${line}"
    else
        ${fleetctl_bin} list-units | grep "${line}" | grep "dead";
        [ $? -eq 0 ] && { ${fleetctl_bin} start "${line}"; msg "Executed: fleetctl start ${line}"; } || msg "Skipping: ${line}, because is already running.";
    fi
done

[ "${dryrun}" == true ] || /bin/mv /tmp/RUN /tmp/RUN.executed;

