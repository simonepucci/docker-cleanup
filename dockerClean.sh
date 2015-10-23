#!/bin/bash

set -eou pipefail

#usage: sudo ./dockerClean.sh [--dry-run]
dryrun=false
verbose=false
docker_bin=$(which docker.io 2> /dev/null || which docker 2> /dev/null)
logger_bin=$(which logger 2> /dev/null)

if [ -z "$docker_bin" ] ; then
    echo "Please install docker. You can install docker by running \"wget -qO- https://get.docker.io/ | sh\"."
    exit 1
fi

[ -z "${logger_bin}" ] && logger_bin=echo || logger_bin="${logger_bin} -t \"${0##*/}\""

while [[ $# > 0 ]]
do
    key="$1"

    case $key in
        -n|--dry-run)
            dryrun=true
        ;;
        *)
            echo "Cleanup docker containers and images: remove unused containers and images."
            echo "Usage: ${0##*/} [--dry-run]"
            echo "   -n, --dry-run: dry run: display what would get removed."
            exit 1
        ;;
    esac
    shift
done

[ "${dryrun}" == true ] && /tmp/docker-cleanup/docker-cleanup-volumes.sh --dry-run || /tmp/docker-cleanup/docker-cleanup-volumes.sh

echo
echo "Removing exited docker containers..."
if [ "${dryrun}" == true ];
then
    ${docker_bin} ps -a -f status=exited -q | xargs -r echo "The following docker containers would be deleted: "
else
    #${docker_bin} ps -a -f status=exited -q | xargs -r ${docker_bin} rm -v || echo "Some errors happened while deleting exited containers, check the logs for details."
    ${docker_bin} ps -a -f status=exited -q | while read line;
    do
        echo "Deleting docker container: ${line}";
        ${docker_bin} rm -v ${line} && ${logger_bin} "Deleted docker container: ${line}" || echo "Some errors happened while deleting exited container: ${line}.";
    done
fi

echo "Removing dangling images..."
if [ "${dryrun}" == true ];
then
    ${docker_bin} images --no-trunc -q -f dangling=true | xargs -r echo "The following dangling images would be deleted: "
else
    #${docker_bin} images --no-trunc -q -f dangling=true | xargs -r ${docker_bin} rmi || echo "Some errors happened while deleting dangling images, check the logs for details."
    ${docker_bin} images --no-trunc -q -f dangling=true | while read line;
    do
        echo "Deleting docker dangling image: ${line}";
        ${docker_bin} rmi ${line} && ${logger_bin} "Deleted docker dangling image: ${line}" || echo "Some errors happened while deleting dangling image: ${line}.";
    done
fi

echo "Removing unused docker images..."
ToBeCleanedImageIdList="/dev/shm/ToBeCleanedImageIdList"
ContainerImageIdList="/dev/shm/ContainerImageIdList"
ImageIdList="/dev/shm/ImageIdList"
ImageFullList="/dev/shm/ImageFullList"
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
        echo "Deleting docker unused image: ${line}";
        ${docker_bin} rmi ${line} && ${logger_bin} "Deleted docker unused image: ${line}" || echo "Some errors happened while deleting unused image: ${line}.";
    fi
done

echo "Truncating deis-router nginx logs.";
[ "${dryrun}" == true ] && /tmp/docker-cleanup/docker-cleanup-deisRouterLogs.sh --dry-run || /tmp/docker-cleanup/docker-cleanup-deisRouterLogs.sh

echo "Done"
