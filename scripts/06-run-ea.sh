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
    chmod 600 "$out" 2>/dev/null || true
}

config_arg_path() {
    local rel="${STARTUP_INI#"$MT5DIR"/}"
    printf '%s' "${rel//\//\\}"
}

copy_ea() {
    mkdir -p "$EXPERTS_DIR"
    if [ -d "$EA_SRC_DIR" ]; then
        cp -f "$EA_SRC_DIR"/*.[Ee][Xx]5 "$EXPERTS_DIR"/ 2>/dev/null || true
    fi
    if [ -n "${MT5_EA:-}" ]; then
        local base
        base="$(ea_name_noext "$MT5_EA")"
        ls "$EXPERTS_DIR/$base".[Ee][Xx]5 >/dev/null 2>&1 || return 1
    fi
    return 0
}

run_ea_main() {
    log_message "RUNNING" "06-run-ea.sh"

    if [ ! -e "$mt5file" ]; then
        log_message "ERROR" "terminal64.exe not found; cannot launch MT5."
        return 1
    fi

    if autologin_ready; then
        if [ -n "${MT5_EA:-}" ] && ! copy_ea; then
            log_message "ERROR" "EA '$MT5_EA' not found in $EA_SRC_DIR; launching login-only."
            MT5_EA=""
        fi
        write_startup_ini "$STARTUP_INI"
        log_message "INFO" "Auto-login enabled; launching MT5 with startup config."
        "$wine_executable" "$mt5file" /portable "/config:$(config_arg_path)" &
    else
        if [ -n "${MT5_LOGIN:-}" ]; then
            log_message "ERROR" "MT5_LOGIN set but MT5_PASSWORD/MT5_SERVER missing; launching MT5 normally."
        fi
        log_message "INFO" "No auto-login; launching MT5 normally."
        "$wine_executable" "$mt5file" /portable &
    fi
}

if [ "${_RUN_EA_NO_MAIN:-0}" != "1" ]; then
    run_ea_main "$@"
fi
