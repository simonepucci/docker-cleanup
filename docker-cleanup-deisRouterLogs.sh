#! /bin/bash
#
#
#
#DISCLAIMER    Truncate nginx logfile: truncate deis-router container log.
#DISCLAIMER    Usage Options: [-dopsh ]
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
# Default dir
dockerdir=/var/lib/docker
dockerdir=$(readlink -f $dockerdir)
containersdir=${dockerdir}/containers

if [ -z "$docker_bin" ] ; then
    echo "Please install docker. You can install docker by running \"wget -qO- https://get.docker.io/ | sh\"."
    exit 1
fi

set -eou pipefail

# Make sure that we can talk to docker daemon. If we cannot, we fail here.
${docker_bin} info >/dev/null

deis_rotuer_id=$(${docker_bin} inspect deis-router | grep '"Id": ' | grep -Eo '[0-9a-f]{64}')
if [[ "${deis_rotuer_id}" =~ [0-9a-f]{64} ]];
then
    nginx_log_file=${containersdir}/${deis_rotuer_id}/${deis_rotuer_id}-json.log
    if [ -f ${nginx_log_file} ];
    then
	if [ "${dryrun}" == true ];
	then
            echo "File to truncate: ${nginx_log_file}";
	else
            msg "TruncatingFile: ${nginx_log_file}";
            msg "Truncated: ${nginx_log_file}";
	    > ${nginx_log_file}
        fi
    else
	msg "File nginx log: ${nginx_log_file}, not found."
    fi
fi

