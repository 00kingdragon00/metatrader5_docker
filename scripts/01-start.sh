#!/bin/bash

source /scripts/02-common.sh

/scripts/03-install-mono.sh
/scripts/04-install-mt5.sh
# /scripts/05-install-python.sh
# /scripts/06-install-libraries.sh

Xvfb :0 -screen 0 1024x768x16 &
fluxbox &
x11vnc -display :0 -nopw -forever -shared &
websockify --web=/usr/share/novnc/ 8080 localhost:5900 &

exec sleep infinity