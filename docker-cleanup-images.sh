#!/bin/bash
#
#
#
#DISCLAIMER    Cleanup docker containers and images: remove unused containers and images.
#DISCLAIMER    Usage Options: [-dopsh ]
#DISCLAIMER        -n: dry run: display only what would get removed.
#DISCLAIMER        -h: help: display usage and exit.
#DISCLAIMER        -s: server: ipv4 address of syslog server to send logs to.
#DISCLAIMER        -p: port: numeric port of syslog server.
#DISCLAIMER        -o: protocol: syslog protocl to use. Must be one of "tcp-udp-syslog".

dryrun=false

[ -f functions.sh ] && source ./functions.sh || exit 254

[[ "$*" =~ \-{2}+ ]] && error "Double dash sign '--' not supported";

while getopts "hno:p:s:" opt "$@"
do
        case $opt in
                n) dryrun=true
                ;;
                o) PROTO=$(echo ${OPTARG} | egrep -io 'tcp|udp|syslog')
                   [ -z "${PROTO}" ] && error "Protocol unknown: \"${OPTARG}\""
                   [ "${PROTO}" == "syslog" ] && PROTO="udp"
                ;;
                p) PORT=$(echo ${OPTARG} | grep -o '[0-9]*')
                   [ -z "${PORT}" ] && error "Port Must be a number: \"${OPTARG}\""
                ;;
                s) SERVER=$(echo ${OPTARG} | grep -o '[0-9][0-9]*[.][0-9][0-9]*[.][0-9][0-9]*[.][0-9][0-9]*')
                   [ -z "${SERVER}" ] && error "Server must be an ipv4 address: \"${OPTARG}\""
                ;;
                h) usage
                ;;
                *) error "Unknown option"
                ;;
        esac
done
logger_bin=$(which logger 2> /dev/null)
PROGNAME=${0##*/}
PORT=${PORT:-"514"}
PROTO=${PROTO:-"udp"}
[ "${PROTO}" == "syslog" ] && PROTO="udp";
[ -z "${SERVER}" ] || LOGGEROPTS="--server ${SERVER} --port ${PORT} --${PROTO}";
[ -z "${PROGNAME}" ] || LOGGEROPTS="${LOGGEROPTS} ${PROGNAME}";
[ -z "${logger_bin}" ] || LOGGERBIN="${logger_bin} ${LOGGEROPTS}";

docker_bin=$(which docker.io 2> /dev/null || which docker 2> /dev/null)

if [ -z "$docker_bin" ] ; then
    echo "Please install docker. You can install docker by running \"wget -qO- https://get.docker.io/ | sh\"."
    exit 1
fi

set -eou pipefail

msg "Removing exited docker containers..."
if [ "${dryrun}" == true ];
then
    ${docker_bin} ps -a -f status=exited -q | xargs -r echo "The following docker containers would be deleted: "
else
    ${docker_bin} ps -a -f status=exited -q | while read line;
    do
        msg "Deleting docker container: ${line}";
        ${docker_bin} rm -v ${line} && msg "Deleted docker container: ${line}" || echo "Some errors happened while deleting exited container: ${line}.";
    done
fi

msg "Removing dangling images..."
if [ "${dryrun}" == true ];
then
    ${docker_bin} images --no-trunc -q -f dangling=true | xargs -r echo "The following dangling images would be deleted: "
else
    ${docker_bin} images --no-trunc -q -f dangling=true | while read line;
    do
        msg "Deleting docker dangling image: ${line}";
        ${docker_bin} rmi ${line} && msg "Deleted docker dangling image: ${line}" || echo "Some errors happened while deleting dangling image: ${line}.";
    done
fi

msg "Removing unused docker images..."
[ -d /dev/shm ] && TMPCACHEFOLD="/dev/shm" || TMPCACHEFOLD="/tmp"
ToBeCleanedImageIdList="${TMPCACHEFOLD}/ToBeCleanedImageIdList"
ContainerImageIdList="${TMPCACHEFOLD}/ContainerImageIdList"
ImageIdList="${TMPCACHEFOLD}/ImageIdList"
ImageFullList="${TMPCACHEFOLD}/ImageFullList"
rm -f ${ToBeCleanedImageIdList} ${ContainerImageIdList} ${ImageIdList} ${ImageFullList}

# Get all image ID
${docker_bin} images -q --no-trunc | sort -o ${ImageIdList}
CONTAINER_ID_LIST=$(${docker_bin} ps -aq --no-trunc)
${docker_bin} images --no-trunc | tail -n +2 | awk '{print $3" "$1":"$2}' > ${ImageFullList}

# Get Image ID that is used by a containter
rm -f ${ContainerImageIdList}
touch ${ContainerImageIdList}
for CONTAINER_ID in ${CONTAINER_ID_LIST}; do
    LINE=$(${docker_bin} inspect ${CONTAINER_ID} | grep "\"Image\": \"[0-9a-fA-F]\{64\}\"")
    IMAGE_ID=$(echo ${LINE} | awk -F '"' '{print $4}')
    echo "${IMAGE_ID}" >> ${ContainerImageIdList}
done
sort ${ContainerImageIdList} -o ${ContainerImageIdList}

# Remove the images being used by cotnainers from the delete list
comm -23 ${ImageIdList} ${ContainerImageIdList} > ${ToBeCleanedImageIdList}

cat ${ToBeCleanedImageIdList} | while read line;
do
    if [ "${dryrun}" == true ];
    then
        grep ${line} ${ImageFullList} | awk '{print $2}' | xargs -r echo "The following unused images would be deleted:";
    else
        msg "Deleting docker unused image: ${line}";
        ${docker_bin} rmi ${line} && msg "Deleted docker unused image: ${line}" || echo "Some errors happened while deleting unused image: ${line}.";
    fi
done

