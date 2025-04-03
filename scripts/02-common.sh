#!/bin/bash

# Set variables
mt5setup_url="https://download.mql5.com/cdn/web/metaquotes.software.corp/mt5/mt5setup.exe"
mt5file="/root/.wine/drive_c/Program Files/MetaTrader 5/terminal64.exe"
python_url="https://www.python.org/ftp/python/3.9.13/python-3.12.9-amd64.exe"
webview="https://msedge.sf.dl.delivery.mp.microsoft.com/filestreamingservice/files/c1336fd6-a2eb-4669-9b03-949fc70ace0e/MicrosoftEdgeWebview2Setup.exe"
wine_executable="wine"

# Function to show messages
log_message() {
    local level=$1
    local message=$2
    local logfile="/var/log/mt5_setup.log"
    [ ! -w "$logfile" ] && logfile="/tmp/mt5_setup.log"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - [$level] $message" >> "$logfile"
}