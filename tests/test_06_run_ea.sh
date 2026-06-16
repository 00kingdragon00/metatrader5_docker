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

rm -rf "$TMP"
exit $fail
