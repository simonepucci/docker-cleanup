#!/bin/bash

set -eou pipefail

#usage: sudo ./dockerClean.sh [--dry-run]
dryrun=false
verbose=false
docker_bin=$(which docker.io 2> /dev/null || which docker 2> /dev/null)
docker_bin_safe=${docker_bin}

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

[ "${dryrun}" = true ] && docker_bin="echo docker"

echo "Removing exited docker containers..."
${docker_bin} ps -a -f status=exited -q | xargs -r ${docker_bin} rm -v

echo "Removing dangling images..."
${docker_bin} images --no-trunc -q -f dangling=true | xargs -r ${docker_bin} rmi

echo "Removing unused docker images"
images=($(${docker_bin_safe} images | tail -n +2 | awk '{print $1":"$2}'))
containers=($(${docker_bin_safe} ps -a | tail -n +2 | awk '{print $2}'))

containers_reg=" ${containers[*]} "
remove=()

for item in ${images[@]}; do
  if [[ ! $containers_reg =~ " $item " ]]; then
    remove+=($item)
  fi
done

remove_images=" ${remove[*]} "

echo ${remove_images} | xargs -r ${docker_bin} rmi || echo "Some errors happened while deleting unused images, check the logs for details."

echo "Done"
