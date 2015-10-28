#!/bin/bash
#
#
#
#
#DISCLAIMER    Maintenace script: run a pool of maintenance scripts
#DISCLAIMER    Usage Options: [-dopsh ]
#DISCLAIMER        -n: dry run: display only what would get removed.
#DISCLAIMER        -h: help: display usage and exit.
#DISCLAIMER        -s: server: ipv4 address of syslog server to send logs to.
#DISCLAIMER        -p: port: numeric port of syslog server.
#DISCLAIMER        -o: protocol: syslog protocl to use. Must be one of "tcp-udp-syslog".

which etcdctl 2> /dev/null && SERVER=$(etcdctl get /deis/logs/drain | grep -o '[0-9][0-9]*[.][0-9][0-9]*[.][0-9][0-9]*[.][0-9][0-9]*');

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

#Call other maintenace scripts with proper params
msg "Running: clanup images and containers";
[ "${dryrun}" == true ] && ./docker-cleanup-images.sh -n || ./docker-cleanup-images.sh $@

msg "Running: cleanup volumes.";
[ "${dryrun}" == true ] && ./docker-cleanup-volumes.sh --dry-run || ./docker-cleanup-volumes.sh

msg "Truncating deis-router nginx logs.";
[ "${dryrun}" == true ] && ./docker-cleanup-deisRouterLogs.sh -n || ./docker-cleanup-deisRouterLogs.sh $@

