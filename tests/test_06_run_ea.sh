#!/usr/bin/env bash
# Host unit tests for scripts/06-run-ea.sh pure functions.
set -u
fail=0
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

# Prevent main from running and isolate paths to temp dirs.
export _RUN_EA_NO_MAIN=1
TMP="$(mktemp -d)"
export MT5DIR="$TMP/mt5"
export EXPERTS_DIR="$MT5DIR/MQL5/Experts"
export CONFIG_DIR="$MT5DIR/config"
export EA_SRC_DIR="$TMP/ea"
mkdir -p "$EXPERTS_DIR" "$CONFIG_DIR" "$EA_SRC_DIR"

source "$SCRIPT_DIR/scripts/02-common.sh"
source "$SCRIPT_DIR/scripts/06-run-ea.sh"

check() { if eval "$2"; then echo "ok - $1"; else echo "FAIL - $1"; fail=1; fi; }

check "ea_name_noext strips .ex5"      '[ "$(ea_name_noext MyEA.ex5)" = "MyEA" ]'
check "ea_name_noext strips .EX5"      '[ "$(ea_name_noext MyEA.EX5)" = "MyEA" ]'
check "ea_name_noext leaves bare name" '[ "$(ea_name_noext MyEA)" = "MyEA" ]'

MT5_LOGIN=1 MT5_PASSWORD=p MT5_SERVER=s ; check "autologin_ready all set" 'autologin_ready'
MT5_LOGIN= ; check "autologin_ready missing login fails" '! autologin_ready'
MT5_LOGIN=1 MT5_PASSWORD= MT5_SERVER=s ; check "autologin_ready missing pw fails" '! autologin_ready'
MT5_LOGIN=1 MT5_PASSWORD=p MT5_SERVER= ; check "autologin_ready missing server fails" '! autologin_ready'

MT5_LOGIN=12345 MT5_PASSWORD=secret MT5_SERVER=Broker-Demo \
MT5_EA=MyEA.ex5 MT5_SYMBOL=EURUSD MT5_TIMEFRAME=H1 \
  write_startup_ini "$CONFIG_DIR/startup.ini"
INI="$CONFIG_DIR/startup.ini"
check "ini has Login"            'grep -qx "Login=12345" "$INI"'
check "ini has Password"         'grep -qx "Password=secret" "$INI"'
check "ini has Server"           'grep -qx "Server=Broker-Demo" "$INI"'
check "ini has AllowLiveTrading" 'grep -qx "AllowLiveTrading=true" "$INI"'
check "ini Expert no ext"        'grep -qx "Expert=MyEA" "$INI"'
check "ini Symbol"               'grep -qx "Symbol=EURUSD" "$INI"'
check "ini Period"               'grep -qx "Period=H1" "$INI"'
check "ini StartUp section"      'grep -qx "\[StartUp\]" "$INI"'
MT5_LOGIN=1 MT5_PASSWORD=1 MT5_SERVER=1 MT5_EA= MT5_SYMBOL= MT5_TIMEFRAME= \
  write_startup_ini "$CONFIG_DIR/def.ini"
check "default symbol EURUSD" 'grep -qx "Symbol=EURUSD" "$CONFIG_DIR/def.ini"'
check "default period H1"     'grep -qx "Period=H1" "$CONFIG_DIR/def.ini"'
check "no Expert line when MT5_EA empty" '! grep -q "^Expert=" "$CONFIG_DIR/def.ini"'

rm -f "$EXPERTS_DIR"/*.ex5
echo dummy > "$EA_SRC_DIR/MyEA.ex5"
MT5_EA=MyEA.ex5 ; check "copy_ea succeeds when EA present" 'copy_ea'
check "ex5 copied to Experts" '[ -e "$EXPERTS_DIR/MyEA.ex5" ]'
rm -f "$EXPERTS_DIR"/*.ex5 "$EA_SRC_DIR"/*.ex5
MT5_EA=Missing.ex5 ; check "copy_ea fails when named EA absent" '! copy_ea'

# config_arg_path derives backslash relative path from STARTUP_INI under MT5DIR
STARTUP_INI="$MT5DIR/config/startup.ini" ; check "config_arg_path default" '[ "$(config_arg_path)" = "config\\startup.ini" ]'
STARTUP_INI="$MT5DIR/sub/dir/x.ini" ; check "config_arg_path nested" '[ "$(config_arg_path)" = "sub\\dir\\x.ini" ]'
STARTUP_INI="$CONFIG_DIR/startup.ini"

# copy_ea handles uppercase .EX5 source files
rm -f "$EXPERTS_DIR"/*.ex5 "$EXPERTS_DIR"/*.EX5 "$EA_SRC_DIR"/*.ex5 "$EA_SRC_DIR"/*.EX5
echo dummy > "$EA_SRC_DIR/UpperEA.EX5"
MT5_EA=UpperEA.EX5 ; check "copy_ea handles .EX5 source" 'copy_ea'
check "uppercase ex5 copied" '[ -e "$EXPERTS_DIR/UpperEA.EX5" ]'

rm -rf "$TMP"
exit $fail
