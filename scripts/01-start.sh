#!/bin/bash

source /scripts/02-common.sh

if [ ! -d "$WINEPREFIX" ]; then
    log_message "INFO" "Initializing Wine prefix (win11)..."
    winecfg -v=win11
fi

/scripts/04-install-mono.sh
/scripts/03-install-webview.sh
/scripts/05-install-mt5.sh
/scripts/06-run-ea.sh


