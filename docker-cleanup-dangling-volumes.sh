#!/bin/bash
#
#
#
#DISCLAIMER    Cleanup docker orphaned volumes: remove unused volumes.
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

docker_bin=$(which docker.io 2> /dev/null || which docker 2> /dev/null)

if [ -z "$docker_bin" ] ; then
    echo "Please install docker. You can install docker by running \"wget -qO- https://get.docker.io/ | sh\"."
    exit 1
fi

DOCKERVERSION=$(${docker_bin} --version | grep -Eo '[[:digit:]]{1,3}\.[[:digit:]]{1,3}\.[[:digit:]]{1,3}' | tr -d '.');
if [ ${DOCKERVERSION} -lt 190 ]; then
    msg "You can run this script only with newer docker versions."
    exit 1
fi


#set -eou pipefail

msg "Removing dangling volumes..."
if [ "${dryrun}" == true ];
then
    ${docker_bin} volume ls -qf dangling=true | xargs -r echo "The following dangling volumes would be deleted: "
else
    ${docker_bin} volume ls -qf dangling=true | while read line;
    do
        msg "Deleting docker dangling volume: ${line}";
        ${docker_bin} volume rm ${line} && msg "Deleted docker dangling volume: ${line}" || msg "Some errors happened while deleting dangling volume: ${line}.";
    done
fi

