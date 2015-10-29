
function usage(){
    PNAME=${0##*/}
    grep '#DISCLAIMER' ${PNAME}|sed 's/#DISCLAIMER//g'
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
function msg(){
    PNAME=${0##*/};
    TMPCACHEFOLD="/tmp";
    [ -d ${TMPCACHEFOLD} ] || mkdir -p "${TMPCACHEFOLD}";
    XTRLGDST="${TMPCACHEFOLD}/VerboseLog_${PNAME}_$$.log";

    if [ -z "$1" ];
    then
        colecho "2" "Warning: No msg to display";
    else
        [ $# -eq 2 ] && colecho "$2" "$1" || colecho "" "$1"
        [ -z "${LOGGERBIN}" ] || ${LOGGERBIN} "$1";
        [ -f ${XTRLGDST} ] && echo "$1" >> ${XTRLGDST} || { echo "This file is logged also via: ${LOGGERBIN}" > ${XTRLGDST}; echo ""; echo "$1" >> ${XTRLGDST}; }
    fi
}


