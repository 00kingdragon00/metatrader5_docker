#!/bin/bash

source /scripts/02-common.sh

if [ ! -d "$WINEPREFIX" ]; then
    log_message "INFO" "Initializing Wine prefix (win11)..."
    WINEDLLOVERRIDES="mscoree=d,mshtml=d" wineboot -i
    WINEDLLOVERRIDES="mscoree=d,mshtml=d" winecfg -v=win11
    wineserver -w
fi

/scripts/04-install-mono.sh
/scripts/03-install-webview.sh
/scripts/05-install-mt5.sh
/scripts/06-run-ea.sh


