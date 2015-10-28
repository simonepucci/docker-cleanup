# docker-cleanup
Script used in deis cluster to cleanup docker unused stuff

    Run the script on docker physical machines

## First create fleetctl service configuration files, one per server.

```
cat >docker-clean\@1.service<<EOF
[Unit]
Description=Clean up disk space
Requires=docker.socket
Wants=deis-builder.service deis-controller.service deis-store-admin.service
After=docker.socket deis-builder.service deis-controller.service deis-store-admin.service

[Service]
Type=oneshot
ExecStartPre=-/bin/sh -c 'cd /tmp/ && git clone https://github.com/simonepucci/docker-cleanup.git'
ExecStartPre=-/bin/sh -c 'cd /tmp/docker-cleanup/ && git pull'
ExecStart=/bin/sh -c 'cd /tmp/docker-cleanup/ && ./dockerClean.sh'

[X-Fleet]
Conflicts=docker-clean@*.service
EOF
```

## Then create fleetctl timer configuration files, one per server.

### Check the X-ConditionMachineOf value in docker-clean timer config file
    You have to match a different docker-clean service for each timer you create.
    For ex. on a 3 host cluster you will have 3 docker-clean\@X.timer
    For each of them a proper X-ConditionMachineOf=docker-clean@X.service must be set.

    The docker-clean\@X.service files do not require any modifications, the content is the same for all.

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

    fleetctl load docker-clean\@\*.service

    fleetctl load docker-clean\@\*.timer

## starts the timer

    fleetctl start docker-clean\@\*.timer

## check service and timer

    fleetctl list-units | grep "docker-clean"

