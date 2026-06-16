# MT5 auto-login + auto-run EA Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** After MT5 installs, optionally auto-login to an account and auto-run a compiled `.ex5` EA via MT5's native startup-config mechanism; otherwise open MT5 normally.

**Architecture:** A new `scripts/06-run-ea.sh` (called from `01-start.sh` after install) generates a `startup.ini` from env vars, copies the mounted `.ex5` into `MQL5/Experts`, and launches `terminal64.exe /portable /config:...`. The launch responsibility moves out of `05-install-mt5.sh` (now install-only). Pure bash logic (ini generation, cred check, EA name handling) is factored into sourceable functions and unit-tested on the host; the launch wiring is verified in a container.

**Tech Stack:** Bash, Docker, Wine, KASM (kasmweb/core-ubuntu-noble), MetaTrader 5 portable mode.

---

## File Structure

- `scripts/06-run-ea.sh` — **new**. Sourceable functions + guarded `run_ea_main`. Decides login vs plain launch.
- `scripts/05-install-mt5.sh` — **modify**. Remove the MT5 launch; install-only.
- `scripts/01-start.sh` — **modify**. Call `06-run-ea.sh` after `05`.
- `docker-compose.yml` — **modify**. Add MT5_* env (commented) + `./experts:/ea:ro` mount.
- `tests/test_06_run_ea.sh` — **new**. Host bash unit tests for the pure functions.
- `experts/.gitkeep` — **new**. Placeholder so the mount source dir exists.
- `.gitignore` — **modify**. Ignore `experts/*.ex5`.

Notes that apply to all script tasks:
- `02-common.sh` defines `mt5file="/root/.wine/drive_c/Program Files/MetaTrader 5/terminal64.exe"` and `wine_executable="wine"` and `log_message`.
- The Dockerfile already does `COPY ./scripts /scripts` + `dos2unix /scripts/*.sh && chmod +x /scripts/*.sh`, so `06-run-ea.sh` is picked up automatically — **no Dockerfile change needed**.

---

### Task 1: Create `06-run-ea.sh` with sourceable helper functions

**Files:**
- Create: `scripts/06-run-ea.sh`
- Create: `tests/test_06_run_ea.sh`

- [ ] **Step 1: Write the failing test** (`tests/test_06_run_ea.sh`)

```bash
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

# 06 sources 02-common.sh via /scripts; run from repo so relative source works.
# We stub /scripts by sourcing the repo copies directly.
source "$SCRIPT_DIR/scripts/02-common.sh"
source "$SCRIPT_DIR/scripts/06-run-ea.sh"

check() { if eval "$2"; then echo "ok - $1"; else echo "FAIL - $1"; fail=1; fi; }

# ea_name_noext strips .ex5 (case-insensitive), leaves bare names alone
check "ea_name_noext strips .ex5"      '[ "$(ea_name_noext MyEA.ex5)" = "MyEA" ]'
check "ea_name_noext strips .EX5"      '[ "$(ea_name_noext MyEA.EX5)" = "MyEA" ]'
check "ea_name_noext leaves bare name" '[ "$(ea_name_noext MyEA)" = "MyEA" ]'

# autologin_ready: true only when all three creds set
MT5_LOGIN=1 MT5_PASSWORD=p MT5_SERVER=s ; check "autologin_ready all set" 'autologin_ready'
MT5_LOGIN= ; check "autologin_ready missing login fails" '! autologin_ready'
MT5_LOGIN=1 MT5_PASSWORD= MT5_SERVER=s ; check "autologin_ready missing pw fails" '! autologin_ready'

rm -rf "$TMP"
exit $fail
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/test_06_run_ea.sh`
Expected: FAIL — `scripts/06-run-ea.sh` does not exist yet (source error / functions undefined).

- [ ] **Step 3: Write minimal implementation** (`scripts/06-run-ea.sh`)

```bash
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
```

Note: `source /scripts/02-common.sh` is guarded with `|| true` because the test sources `02-common.sh` directly first; in the container `/scripts/02-common.sh` exists. `run_ea_main` is defined in Task 4 — for now the guard at the bottom would call an undefined function only when executed (not sourced), and tests set `_RUN_EA_NO_MAIN=1`, so tests pass. Container execution is wired only after Task 4.

- [ ] **Step 4: Run test to verify it passes**

Run: `bash tests/test_06_run_ea.sh`
Expected: all `ok -` lines, exit 0.

- [ ] **Step 5: Commit**

```bash
git add scripts/06-run-ea.sh tests/test_06_run_ea.sh
git commit -m "feat: 06-run-ea.sh helper fns (ea_name_noext, autologin_ready) + tests"
```

---

### Task 2: `write_startup_ini` function

**Files:**
- Modify: `scripts/06-run-ea.sh`
- Modify: `tests/test_06_run_ea.sh`

- [ ] **Step 1: Write the failing test** — append before `rm -rf "$TMP"` in `tests/test_06_run_ea.sh`

```bash
# write_startup_ini renders expected sections/values
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

# defaults applied when symbol/timeframe unset
MT5_LOGIN=1 MT5_PASSWORD=1 MT5_SERVER=1 MT5_EA= MT5_SYMBOL= MT5_TIMEFRAME= \
  write_startup_ini "$CONFIG_DIR/def.ini"
check "default symbol EURUSD" 'grep -qx "Symbol=EURUSD" "$CONFIG_DIR/def.ini"'
check "default period H1"     'grep -qx "Period=H1" "$CONFIG_DIR/def.ini"'
check "no Expert line when MT5_EA empty" '! grep -q "^Expert=" "$CONFIG_DIR/def.ini"'
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/test_06_run_ea.sh`
Expected: FAIL — `write_startup_ini: command not found`.

- [ ] **Step 3: Write minimal implementation** — add to `scripts/06-run-ea.sh` after `autologin_ready`

```bash
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bash tests/test_06_run_ea.sh`
Expected: all `ok -`, exit 0.

- [ ] **Step 5: Commit**

```bash
git add scripts/06-run-ea.sh tests/test_06_run_ea.sh
git commit -m "feat: write_startup_ini generates MT5 startup config"
```

---

### Task 3: `copy_ea` function (copy `.ex5` + validate named EA present)

**Files:**
- Modify: `scripts/06-run-ea.sh`
- Modify: `tests/test_06_run_ea.sh`

- [ ] **Step 1: Write the failing test** — append before `rm -rf "$TMP"`

```bash
# copy_ea copies *.ex5 into EXPERTS_DIR and validates the named EA
rm -f "$EXPERTS_DIR"/*.ex5
echo dummy > "$EA_SRC_DIR/MyEA.ex5"
MT5_EA=MyEA.ex5 ; check "copy_ea succeeds when EA present" 'copy_ea'
check "ex5 copied to Experts" '[ -e "$EXPERTS_DIR/MyEA.ex5" ]'

rm -f "$EXPERTS_DIR"/*.ex5 "$EA_SRC_DIR"/*.ex5
MT5_EA=Missing.ex5 ; check "copy_ea fails when named EA absent" '! copy_ea'
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/test_06_run_ea.sh`
Expected: FAIL — `copy_ea: command not found`.

- [ ] **Step 3: Write minimal implementation** — add to `scripts/06-run-ea.sh` after `write_startup_ini`

```bash
copy_ea() {
    mkdir -p "$EXPERTS_DIR"
    if [ -d "$EA_SRC_DIR" ]; then
        cp -f "$EA_SRC_DIR"/*.ex5 "$EXPERTS_DIR"/ 2>/dev/null || true
    fi
    if [ -n "${MT5_EA:-}" ] && [ ! -e "$EXPERTS_DIR/$(ea_name_noext "$MT5_EA").ex5" ]; then
        return 1
    fi
    return 0
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bash tests/test_06_run_ea.sh`
Expected: all `ok -`, exit 0.

- [ ] **Step 5: Commit**

```bash
git add scripts/06-run-ea.sh tests/test_06_run_ea.sh
git commit -m "feat: copy_ea copies .ex5 into MQL5/Experts and validates"
```

---

### Task 4: `run_ea_main` (decision + launch)

**Files:**
- Modify: `scripts/06-run-ea.sh`

- [ ] **Step 1: Write the implementation** — add `run_ea_main` to `scripts/06-run-ea.sh` (place it ABOVE the bottom `if [ "${_RUN_EA_NO_MAIN:-0}" ... ]` guard)

```bash
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
        "$wine_executable" "$mt5file" /portable "/config:config\\startup.ini" &
    else
        if [ -n "${MT5_LOGIN:-}" ]; then
            log_message "ERROR" "MT5_LOGIN set but MT5_PASSWORD/MT5_SERVER missing; launching MT5 normally."
        fi
        log_message "INFO" "No auto-login; launching MT5 normally."
        "$wine_executable" "$mt5file" /portable &
    fi
}
```

- [ ] **Step 2: Verify the function is defined and tests still pass** (tests set `_RUN_EA_NO_MAIN=1`, so `run_ea_main` is defined but not executed)

Run: `bash tests/test_06_run_ea.sh`
Expected: all `ok -`, exit 0.

- [ ] **Step 3: Shellcheck / syntax check**

Run: `bash -n scripts/06-run-ea.sh && echo OK`
Expected: `OK`

- [ ] **Step 4: Commit**

```bash
git add scripts/06-run-ea.sh
git commit -m "feat: run_ea_main launches MT5 with auto-login+EA or plain"
```

---

### Task 5: Make `05-install-mt5.sh` install-only (remove launch)

**Files:**
- Modify: `scripts/05-install-mt5.sh`

- [ ] **Step 1: Replace the recheck/launch block**

Find:
```bash
# Recheck if MetaTrader 5 is installed
if [ -e "$mt5file" ]; then
    log_message "INFO" "File $mt5file is installed. Running MT5..."
    $wine_executable "$mt5file" &
else
    log_message "ERROR" "File $mt5file is not installed. MT5 cannot be run."
fi
```

Replace with:
```bash
# Recheck if MetaTrader 5 is installed (launch handled by 06-run-ea.sh)
if [ -e "$mt5file" ]; then
    log_message "INFO" "File $mt5file is installed."
else
    log_message "ERROR" "File $mt5file is not installed."
fi
```

- [ ] **Step 2: Syntax check**

Run: `bash -n scripts/05-install-mt5.sh && echo OK`
Expected: `OK`

- [ ] **Step 3: Commit**

```bash
git add scripts/05-install-mt5.sh
git commit -m "refactor: 05 install-only; launch moved to 06"
```

---

### Task 6: Wire `06-run-ea.sh` into `01-start.sh`

**Files:**
- Modify: `scripts/01-start.sh`

- [ ] **Step 1: Add the call after 05**

Find:
```bash
/scripts/04-install-mono.sh
/scripts/03-install-webview.sh
/scripts/05-install-mt5.sh
```

Replace with:
```bash
/scripts/04-install-mono.sh
/scripts/03-install-webview.sh
/scripts/05-install-mt5.sh
/scripts/06-run-ea.sh
```

- [ ] **Step 2: Syntax check**

Run: `bash -n scripts/01-start.sh && echo OK`
Expected: `OK`

- [ ] **Step 3: Commit**

```bash
git add scripts/01-start.sh
git commit -m "feat: call 06-run-ea.sh from startup chain"
```

---

### Task 7: docker-compose env vars + EA mount, experts dir, gitignore

**Files:**
- Modify: `docker-compose.yml`
- Create: `experts/.gitkeep`
- Modify: `.gitignore`

- [ ] **Step 1: Update `docker-compose.yml` environment + volumes**

Find:
```yaml
    environment:
      - VNC_PW=password
    volumes:
      - /home/<path>:/root/.wine/
```

Replace with:
```yaml
    environment:
      - VNC_PW=password
      # MT5 auto-login + EA (optional). Omit MT5_LOGIN to just open MT5.
      # - MT5_LOGIN=12345678
      # - MT5_PASSWORD=yourpassword
      # - MT5_SERVER=Broker-Demo
      # - MT5_EA=MyEA.ex5
      # - MT5_SYMBOL=EURUSD
      # - MT5_TIMEFRAME=H1
    volumes:
      - /home/<path>:/root/.wine/
      - ./experts:/ea:ro
```

- [ ] **Step 2: Create the EA mount source dir**

```bash
mkdir -p experts
printf 'Drop your compiled MT5 .ex5 Expert Advisor files here.\n' > experts/.gitkeep
```

- [ ] **Step 3: Ignore user EA binaries**

Append to `.gitignore`:
```
experts/*.ex5
```

- [ ] **Step 4: Validate compose**

Run: `docker compose config >/dev/null && echo OK`
Expected: `OK`

- [ ] **Step 5: Commit**

```bash
git add docker-compose.yml experts/.gitkeep .gitignore
git commit -m "feat: compose MT5_* env vars + ./experts EA mount"
```

---

### Task 8: Build + container verification

**Files:** none (verification only)

- [ ] **Step 1: Build the image**

Run: `docker compose build`
Expected: exit 0.

- [ ] **Step 2: Verify auto-login+EA wiring with fake creds + dummy EA**

```bash
docker rm -f mt5_ea 2>/dev/null
mkdir -p /tmp/ea_test && echo dummy > /tmp/ea_test/MyEA.ex5
docker run -d --name mt5_ea --shm-size=2g \
  -e VNC_PW=password \
  -e MT5_LOGIN=99999999 -e MT5_PASSWORD=fakepw -e MT5_SERVER=Fake-Demo \
  -e MT5_EA=MyEA.ex5 -e MT5_SYMBOL=EURUSD -e MT5_TIMEFRAME=H1 \
  -v /tmp/ea_test:/ea:ro \
  metatrader5_docker-mt5:latest
```

Wait for install + launch (poll up to ~7 min), then check:
```bash
docker exec mt5_ea bash -c '
MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"
echo "=== startup.ini ==="; cat "$MT5/config/startup.ini"
echo "=== EA copied? ==="; ls -l "$MT5/MQL5/Experts/MyEA.ex5"
echo "=== terminal launched with config? ==="; pgrep -af "terminal64.exe" | grep -v pgrep
echo "=== journal mentions login/expert? ==="; grep -rinE "login|expert|MyEA" "$MT5/logs" 2>/dev/null | tail -10'
```
Expected: `startup.ini` shows the env values; `MyEA.ex5` present in Experts; `terminal64.exe` running with `/portable /config:config\startup.ini`; journal shows a login attempt (will FAIL because creds are fake — that is success for wiring).

- [ ] **Step 3: Verify no-creds path still opens MT5 normally**

```bash
docker rm -f mt5_plain 2>/dev/null
docker run -d --name mt5_plain --shm-size=2g -e VNC_PW=password metatrader5_docker-mt5:latest
# wait for install, then:
docker exec mt5_plain bash -c 'pgrep -af terminal64.exe | grep -v pgrep; ls "/root/.wine/drive_c/Program Files/MetaTrader 5/config/startup.ini" 2>/dev/null && echo "UNEXPECTED ini" || echo "no ini (correct)"'
```
Expected: `terminal64.exe` running (no `/config`), and **no** `startup.ini` generated.

- [ ] **Step 4: Cleanup**

```bash
docker rm -f mt5_ea mt5_plain 2>/dev/null
rm -rf /tmp/ea_test
```

- [ ] **Step 5: Final commit (if any verification tweaks were needed)**

```bash
git add -A && git commit -m "test: verify MT5 auto-login+EA wiring" || echo "nothing to commit"
```

---

## Self-Review

**Spec coverage:**
- Env-var + mounted EA provisioning → Tasks 2, 3, 7. ✓
- Symbol/timeframe/EA via env with defaults → Task 2 (defaults), Task 7 (compose). ✓
- Compiled `.ex5`, default params → `copy_ea` + `Expert=` line, no `.set`/compile. ✓
- No-creds → open MT5 normally → `run_ea_main` else-branch (Task 4), verified Task 8 Step 3. ✓
- Native `/config` + portable launch → Task 4. ✓
- Error handling (terminal missing, partial creds, EA missing) → Task 4 branches. ✓
- AllowLiveTrading=true → Task 2 ini. ✓
- Security/risk notes → documented in spec; compose uses commented examples (no real creds). ✓

**Placeholder scan:** No TBD/TODO; all steps contain concrete code/commands. ✓

**Type/name consistency:** `ea_name_noext`, `autologin_ready`, `write_startup_ini`, `copy_ea`, `run_ea_main`, and vars `EXPERTS_DIR`/`CONFIG_DIR`/`STARTUP_INI`/`EA_SRC_DIR`/`MT5DIR` are used identically across Tasks 1–4 and tests. ✓

**Note on testability:** functions read path vars with `${VAR:-default}` so the host tests override `MT5DIR`/`EXPERTS_DIR`/`CONFIG_DIR`/`EA_SRC_DIR` to temp dirs; the container uses defaults derived from `mt5file`.
