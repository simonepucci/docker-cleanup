# docker-cleanup
Script used in deis cluster to cleanup docker unused stuff

## Run the script on docker physical machine
## First create fleetctl configuration files, one per server
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
ExecStart=/bin/sh -c '/tmp/docker-cleanup/dockerClean.sh'

[X-Fleet]
Conflicts=docker-clean@*.service
EOF
```
# Check the X-ConditionMachineOf value in docker-clean timer config file, you have to match a different docker-clean service for each timer you create.

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
fleetctl load docker-clean\@*.service
fleetctl load docker-clean\@*.timer

## starts the timer
fleetctl start docker-clean\@*.timer

## check service and timer
fleetctl list-units | grep "docker-clean"

