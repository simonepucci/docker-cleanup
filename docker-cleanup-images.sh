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

#set -eou pipefail

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
EffectiveToBeCleanedImageIdList="${TMPCACHEFOLD}/EffectiveToBeCleanedImageIdList"
ToBeCleanedImageIdList="${TMPCACHEFOLD}/ToBeCleanedImageIdList"
ContainerImageIdList="${TMPCACHEFOLD}/ContainerImageIdList"
ImageIdList="${TMPCACHEFOLD}/ImageIdList"
ImageFullList="${TMPCACHEFOLD}/ImageFullList"
InUseByLoweridList="${TMPCACHEFOLD}/InUseByLoweridList"
RunningFleetImages="${TMPCACHEFOLD}/RunningFleetImages"
ToBePreservedImagesNames="alpine|deis|datadog|docker-clean|UNIT"

rm -f ${EffectiveToBeCleanedImageIdList} ${ToBeCleanedImageIdList} ${ContainerImageIdList} ${ImageIdList} ${ImageFullList} ${InUseByLoweridList} ${RunningFleetImages}

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

# Add images actually running to InUseByLoweridList and last 5 deployed images for each appname found via fleetctl
fleetctl list-units | grep -Ev "${ToBePreservedImagesNames}" | awk '{print $1}' > ${RunningFleetImages}
cat ${RunningFleetImages} | while read line;
do
    APPVER=${line%%.*};
    grep "${APPVER%%_*}:${APPVER##*_}" ${ImageFullList} | awk '{print $1}' >> ${InUseByLoweridList}
    ${docker_bin} images --no-trunc ${APPVER%%_*} | grep -v "^REPOSITORY" | head -n 5 >> ${InUseByLoweridList}
done

# Add images to be preserved to InUseByLoweridList
grep -E "${ToBePreservedImagesNames}" ${ImageFullList} | awk '{print $1}' >> ${InUseByLoweridList}

# Find currently in use images and their parents
ls -l /var/lib/docker/overlay/*/lower-id | grep -o "[0-9a-fA-F]\{64\}" | sort | uniq | while read line;
do
    echo "${line}" >> ${InUseByLoweridList};
    cat /var/lib/docker/overlay/${line}/lower-id | xargs >> ${InUseByLoweridList};
done
sort ${InUseByLoweridList} -o ${InUseByLoweridList}
# Remove the images being used by cotnainers from the delete list
comm -23 ${ToBeCleanedImageIdList} ${InUseByLoweridList} | sort | uniq > ${EffectiveToBeCleanedImageIdList}

cat ${EffectiveToBeCleanedImageIdList} | while read line;
do
    if [ "${dryrun}" == true ];
    then
        grep ${line} ${ImageFullList} | awk '{print $2}' | xargs -r echo "The following unused images would be deleted:";
    else
	unset CURIMAGES;
	CURIMAGES=$(grep ${line} ${ImageFullList} | awk '{print $2}' | xargs -r echo)
	[ -z "${CURIMAGES}" ] && continue; 
        msg "Deleting docker unused image: ${line}";
        ${docker_bin} rmi ${CURIMAGES} && msg "Deleted docker unused image: ${line} - ${CURIMAGES}" || echo "Some errors happened while deleting unused image: ${line} - ${CURIMAGES}.";
    fi
done

