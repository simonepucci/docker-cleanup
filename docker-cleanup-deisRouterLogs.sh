#! /bin/bash
#
#
#
DRAIN=$(etcdctl get /deis/logs/drain);
SERVER=$(echo ${DRAIN} | grep -o '[0-9][0-9]*[.][0-9][0-9]*[.][0-9][0-9]*[.][0-9][0-9]*')
PORT=$(echo ${DRAIN} | grep -o '[0-9]*$');
PROTO=$(echo ${DRAIN} | egrep -io 'tcp|udp|syslog');

set -eou pipefail

docker_bin=$(which docker.io 2> /dev/null || which docker 2> /dev/null)
logger_bin=$(which logger 2> /dev/null)
etcdctl_bin=$(which etcdctl 2> /dev/null)
# Default dir
dockerdir=/var/lib/docker
dockerdir=$(readlink -f $dockerdir)

containersdir=${dockerdir}/containers
dryrun=false

if [ -z "$docker_bin" ] ; then
    echo "Please install docker. You can install docker by running \"wget -qO- https://get.docker.io/ | sh\"."
    exit 1
fi
if [ -z "$etcdctl_bin" ] ; then
    echo "No etcdctl binary found."
    exit 1
fi
PROGNAME=${0##*/}
PORT=${PORT:-"514"};
[ "${PROTO}" == "syslog" ] && PROTO="udp";

[ -z "${SERVER}" ] || LOGGEROPTS="--server ${SERVER} --port ${PORT} --${PROTO}";
[ -z "${PROGNAME}" ] || LOGGEROPTS="${LOGGEROPTS} ${PROGNAME}";
[ -z "${logger_bin}" ] && logger_bin=echo || logger_bin="${logger_bin} ${LOGGEROPTS}"

while [[ $# > 0 ]]
do
    key="$1"

    case $key in
        -n|--dry-run)
            dryrun=true
        ;;
        *)
            echo "Truncate nginx logfile: truncate deis-router container log."
            echo "Usage: ${0##*/} [--dry-run]"
            echo "   -n, --dry-run: dry run: display what would get tuncated."
            exit 1
        ;;
    esac
    shift
done

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
            echo "Truncating file: ${nginx_log_file}";
            ${logger_bin} "Truncated: ${nginx_log_file}";
	    > ${nginx_log_file}
        fi
    else
	echo "File nginx log: ${nginx_log_file}, not found."
	${logger_bin} "File nginx log: ${nginx_log_file}, not found."
    fi
fi
