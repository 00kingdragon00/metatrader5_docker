#!/bin/bash

source /scripts/02-common.sh

log_message "RUNNING" "03-install-webview.sh"

log_message "INFO" "Downloading and installing Microsoft Edge WebView..."

wget -O /tmp/MicrosoftEdgeWebview2Setup.exe $webview > /dev/null 2>&1

if [ $? -eq 0 ]; then
    wine /tmp/MicrosoftEdgeWebview2Setup.exe /silent /install
    if [ $? -eq 0 ]; then
        log_message "INFO" "Microsoft Edge WebView installed successfully."
    else
        log_message "ERROR" "Failed to install Microsoft Edge WebView."
    fi
    rm -f /tmp/MicrosoftEdgeWebview2Setup.exe
else
    log_message "ERROR" "Failed to download Microsoft Edge WebView installer."
fi

