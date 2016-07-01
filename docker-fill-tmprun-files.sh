#!/bin/bash
#
#
#	Fill /tmp/RUN and /tmp/RUNPRE files with stop and start deis-builder.service
cat > /tmp/RUNPRE <<EOF
stop deis-builder.service
EOF

cat > /tmp/RUN <<EOF
start deis-builder.service
EOF

