#!/bin/bash

set -eou pipefail

#usage: sudo ./dockerClean.sh [--dry-run]
dryrun=false
verbose=false
docker_bin=$(which docker.io 2> /dev/null || which docker 2> /dev/null)

if [ -z "$docker_bin" ] ; then
    echo "Please install docker. You can install docker by running \"wget -qO- https://get.docker.io/ | sh\"."
    exit 1
fi

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
    ${docker_bin} ps -a -f status=exited -q | xargs -r echo "The following docker containers would be deleted:"
else
    ${docker_bin} ps -a -f status=exited -q | xargs -r ${docker_bin} rm -v
fi

echo "Removing dangling images..."
if [ "${dryrun}" == true ];
then
    ${docker_bin} images --no-trunc -q -f dangling=true | xargs -r echo "The following dangling images would be deleted: "
else
    ${docker_bin} images --no-trunc -q -f dangling=true | xargs -r ${docker_bin} rmi
fi

echo "Removing unused docker images..."
images=($(${docker_bin} images | tail -n +2 | awk '{print $1":"$2}'))
containers=($(${docker_bin} ps -a | tail -n +2 | awk '{print $2}'))

containers_reg=" ${containers[*]} "
remove=()

for item in ${images[@]}; do
  if [[ ! $containers_reg =~ " $item " ]]; then
    remove+=($item)
  fi
done

if [ ${#remove[@]} -gt 0 ];
then
    remove_images=" ${remove[*]} "
    if [ "${dryrun}" == true ];
    then
        echo ${remove_images} | xargs -r echo "The following unused images would be deleted: "
    else
        echo ${remove_images} | xargs -r ${docker_bin} rmi || echo "Some errors happened while deleting unused images, check the logs for details."
    fi
fi

echo "Done"
