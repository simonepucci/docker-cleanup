#!/bin/bash
#
#
#
#
#DISCLAIMER    Maintenace script: run a pool of maintenance scripts
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

#Call other maintenace scripts with proper params
#################################################
msg "Running: extemporaneous commands only if /tmp/RUNPRE exists";
[ "${dryrun}" == true ] || ./docker-extra-commands.sh /tmp/RUNPRE

msg "Running: clanup images and containers.";
[ "${dryrun}" == true ] && ./docker-cleanup-images.sh -n || ./docker-cleanup-images.sh

#msg "Running: cleanup volumes.";
#[ "${dryrun}" == true ] && ./docker-cleanup-volumes.sh --dry-run || ./docker-cleanup-volumes.sh

msg "Running: cleanup dangling volumes.";
[ "${dryrun}" == true ] && ./docker-cleanup-dangling-volumes.sh -n || ./docker-cleanup-dangling-volumes.sh -n

msg "Running: truncate deis-router nginx logs.";
[ "${dryrun}" == true ] && ./docker-cleanup-deisRouterLogs.sh -n || ./docker-cleanup-deisRouterLogs.sh

msg "Running: cleanup obsolete logs of maintenace scripts.";
[ "${dryrun}" == true ] || /usr/bin/find /tmp/ -type f -name VerboseLog_\*_\*.log -mtime +7 -delete

msg "Running: extemporaneous commands only if /tmp/RUN exists";
[ "${dryrun}" == true ] || ./docker-extra-commands.sh /tmp/RUN

msg "Running: docker bug check";
[ "${dryrun}" == true ] || ./docker-bug-finder.sh
