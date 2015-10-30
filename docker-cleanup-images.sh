#!/bin/bash
#
#
#
#DISCLAIMER    Cleanup docker containers and images: remove unused containers and images.
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

