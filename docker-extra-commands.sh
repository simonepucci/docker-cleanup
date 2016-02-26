#!/bin/bash
#
#
#
#DISCLAIMER    Run extra commands if the file given as argument is present.
#DISCLAIMER    Read line per line the file content and run fleetctl against the content of each line.
#DISCLAIMER    For example a file could contain:
#DISCLAIMER        start datadog.service
#DISCLAIMER        stop datadog.service
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
[ $# -gt 2 ] && usage || INFILE="$(eval "echo -n \$$#")";

FLEETCMD="";

fleetctl_bin=$(which fleetctl 2> /dev/null)
[ -z "${fleetctl_bin}" ] && { msg "fleetctl command not found, can not run this script."; exit 1; }
#set -eou pipefail

[ -f "${INFILE}" ] || { msg "Exiting without running any extra command."; exit 0; }

cat ${INFILE} | while read line;
do
    if [ "${dryrun}" == true ];
    then
        msg "The following extra commands would be executed: fleetctl ${line}"
    else
        echo "${line}" | cut -d ' '  -f 1 | grep -Eiq 'start|stop';
        [ $? -eq 0 ] && FLEETCMD="Ok";
        [ -z "${FLEETCMD}" ] && { msg "fleet command not parsable, it must be: start or stop."; exit 1; }

        ${fleetctl_bin} ${line};
        [ $? -eq 0 ] && msg "Executed with success: ${fleetctl_bin} ${line}" || msg "Executed with error: ${fleetctl_bin} ${line}";
    fi
done

[ "${dryrun}" == true ] || /bin/mv ${INFILE} ${INFILE}.executed;

