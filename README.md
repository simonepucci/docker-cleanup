# docker-cleanup
Script used in deis cluster to cleanup docker unused stuff

    Run the script on docker physical machines
    The main script will call a subset of specialized sub-scripts 
    This approach is hopefully more clear and easy to mantain and customize.
    

## First create fleetctl service configuration files, one per server.

```
cat >docker-clean\@1.service<<EOF
[Unit]
Description=Clean up disk space
Requires=docker.socket fleet.socket
Wants=deis-controller.service
After=docker.socket fleet.socket

[Service]
Type=oneshot
ExecStartPre=-/bin/sh -c 'cd /tmp/ && git clone https://github.com/simonepucci/docker-cleanup.git'
ExecStartPre=-/bin/sh -c 'cd /tmp/docker-cleanup/ && git ls-files -d -z | xargs -0 git checkout --'
ExecStartPre=-/bin/sh -c 'cd /tmp/docker-cleanup/ && git pull'
ExecStart=/bin/sh -c 'cd /tmp/docker-cleanup/ && ./dockerClean.sh'

[X-Fleet]
Conflicts=docker-clean@*.service
EOF
```

## Then create fleetctl timer configuration files, one per server.

### Check the X-ConditionMachineOf value in docker-clean timer config file
    You have to match a different docker-clean service for each timer you create.
    For ex. on a 3 host cluster you will have 3 docker-clean@X.timer
    For each of them a proper X-ConditionMachineOf=docker-clean@X.service must be set.

    The docker-clean@X.service files do not require any modifications, the content is the same for all.

```
cat >docker-clean\@1.timer<<EOF
[Unit]
Description=Runs docker-clean.service every day 

[Timer]
OnCalendar=03:00:00

[X-Fleet]
X-ConditionMachineOf=docker-clean@1.service
EOF
```

## loads the service and timer units

    fleetctl load docker-clean@*.service

    fleetctl load docker-clean@*.timer

## starts the timer

    fleetctl start docker-clean@*.timer

## check service and timer

    fleetctl list-units | grep "docker-clean"

## Included scripts

###   functions.sh
    A subset of basic utils used by other scripts
###   dockerClean.sh
    The main program called by fleetctl, in other words an orchestration script
###   docker-cleanup-images.sh
    A cleaning unused docker images and volumes if overlay driver is used by docker
###   docker-cleanup-volumes.sh
    The original script used to clenup disk space if docker use VFS driver
###   docker-cleanup-dangling-volumes.sh
    A small cleanup script that clean orphaned volumes in one shot, it use built-in docker volume functionality added in version 1.9.0 and later
###   docker-cleanup-deisRouterLogs.sh
    Simply truncate nginx routers logfile
###   docker-extra-commands.sh
    A tool used to startup fleet units at the end of cleanup procedure, useful when cleaning deis-builder stuff
    In order to start some units, a file named /tmp/RUN must exist on a node.
    The /tmp/RUN can contain fleet services names one per line. 
    At the moment that docker-extra-commands.sh will be executed, each service contained in the file /tmp/RUN will be triggered, if not already running.

