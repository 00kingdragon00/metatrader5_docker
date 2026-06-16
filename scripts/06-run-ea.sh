#!/bin/bash

source /scripts/02-common.sh 2>/dev/null || true

MT5DIR="${MT5DIR:-$(dirname "$mt5file")}"
EXPERTS_DIR="${EXPERTS_DIR:-$MT5DIR/MQL5/Experts}"
CONFIG_DIR="${CONFIG_DIR:-$MT5DIR/config}"
STARTUP_INI="${STARTUP_INI:-$CONFIG_DIR/startup.ini}"
EA_SRC_DIR="${EA_SRC_DIR:-/ea}"

ea_name_noext() {
    printf '%s' "${1%.[Ee][Xx]5}"
}

autologin_ready() {
    [ -n "${MT5_LOGIN:-}" ] && [ -n "${MT5_PASSWORD:-}" ] && [ -n "${MT5_SERVER:-}" ]
}

if [ "${_RUN_EA_NO_MAIN:-0}" != "1" ]; then
    run_ea_main "$@"
fi
