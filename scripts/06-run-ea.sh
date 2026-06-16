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

write_startup_ini() {
    local out="$1"
    local sym="${MT5_SYMBOL:-EURUSD}"
    local tf="${MT5_TIMEFRAME:-H1}"
    mkdir -p "$(dirname "$out")"
    {
        echo "[Common]"
        echo "Login=${MT5_LOGIN:-}"
        echo "Password=${MT5_PASSWORD:-}"
        echo "Server=${MT5_SERVER:-}"
        echo "[Experts]"
        echo "AllowLiveTrading=true"
        echo "Enabled=true"
        echo "Account=false"
        echo "Profile=false"
        echo "[StartUp]"
        [ -n "${MT5_EA:-}" ] && echo "Expert=$(ea_name_noext "$MT5_EA")"
        echo "Symbol=$sym"
        echo "Period=$tf"
    } > "$out"
}

if [ "${_RUN_EA_NO_MAIN:-0}" != "1" ]; then
    run_ea_main "$@"
fi
