#Global variables used by functions
#Placed here for convenience

#Required tools
GREP_BIN=$(which grep 2> /dev/null) || exit -1
SED_BIN=$(which sed 2> /dev/null) || exit -1

#Specific initialization for LOGGERBIN
function logbininit(){
    PROGNAME=${0##*/}
    LOG_BIN=$(which logger 2> /dev/null)
    DATE_BIN=$(which date 2> /dev/null)

    #Get syslog server from deis configuration via etcdctl
    ETCDCTL_BIN=$(which etcdctl 2> /dev/null);
    [ -z "${ETCDCTL_BIN}" ] || DRAIN=$(${ETCDCTL_BIN} get /deis/logs/drain)

    #Parse syslog url and populate variables
    [ -z "${DRAIN}" ] || SERVER=$(echo ${DRAIN} | ${GREP_BIN} -o '[0-9][0-9]*[.][0-9][0-9]*[.][0-9][0-9]*[.][0-9][0-9]*');
    [ -z "${DRAIN}" ] || PORT=$(echo ${DRAIN} | ${GREP_BIN} -o '[0-9]*$');
    [ -z "${DRAIN}" ] || PROTO=$(echo ${DRAIN} | ${GREP_BIN} -Eio 'tcp|udp|syslog');

    #LOGGERBIN variable construction
    PORT=${PORT:-"514"}
    PROTO=${PROTO:-"udp"}
    [ "${PROTO}" == "syslog" ] && PROTO="udp";
    [ -z "${SERVER}" ] || LOGGEROPTS="--server ${SERVER} --port ${PORT} --${PROTO}";
    [ -z "${DATE_BIN}" ] || CDATE=$(${DATE_BIN} +%Y-%m-%dT%H:%M:%SZ)
    [ -z "${CDATE}" ] || LOGGEROPTS="${LOGGEROPTS} ${CDATE}";
    [ -z "${PROGNAME}" ] || LOGGEROPTS="${LOGGEROPTS} ${PROGNAME}[$$]:";
    [ -z "${LOG_BIN}" ] || export LOGGERBIN="${LOG_BIN} ${LOGGEROPTS}";
}

#Functions definition
function usage(){
    PROGNAME=${0##*/}
    ${GREP_BIN} '#DISCLAIMER' ${PROGNAME} | ${SED_BIN} 's/#DISCLAIMER//g'
    exit 0;
}

# Write colored output recieve "colournumber" "message"
function colecho(){
    SETCOLOR_SUCCESS="echo -en \\033[1;32m";
    SETCOLOR_NORMAL="echo -en \\033[0;39m";
    SETCOLOR_FAILURE="echo -en \\033[1;31m";
    SETCOLOR_WARNING="echo -en \\033[1;33m";
    [ "$1" == "" ] && $SETCOLOR_NORMAL;
    [ "$1" == "0" ] && $SETCOLOR_SUCCESS;
    [ "$1" == "1" ] && $SETCOLOR_FAILURE;
    [ "$1" == "2" ] && $SETCOLOR_WARNING;
    [ "$2" == "" ] || echo "$2";
    $SETCOLOR_NORMAL;
}

function error(){
    [ "$1" == "" ] && usage || colecho "1" "$1";
    exit 1;
}

#Require LOGGERBIN global variable to be populated...
logbininit
function msg(){
    PROGNAME=${0##*/}
    TMPCACHEFOLD="/tmp";
    [ -d ${TMPCACHEFOLD} ] || mkdir -p "${TMPCACHEFOLD}";
    XTRLGDST="${TMPCACHEFOLD}/VerboseLog_${PROGNAME}_$$.log";

    if [ -z "$1" ];
    then
        colecho "2" "Warning: No msg to display";
    else
        [ $# -eq 2 ] && colecho "$2" "$1" || colecho "" "$1"
        [ -z "${LOGGERBIN}" ] || ${LOGGERBIN} "$1";
        [ -f ${XTRLGDST} ] && echo "$1" >> ${XTRLGDST} || { echo "This file is logged also via: ${LOGGERBIN}" > ${XTRLGDST}; echo ""; echo "$1" >> ${XTRLGDST}; }
    fi
}


