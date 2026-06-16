# MT5 auto-login + auto-run EA — design

Date: 2026-06-16

## Goal

After MT5 finishes installing in the container, optionally log in to a trading
account and auto-attach/run a compiled Expert Advisor (`.ex5`) — using MT5's
native startup-config mechanism, no GUI automation.

Opt-in: the feature activates only when account env vars are set. Otherwise the
container behaves exactly as today (MT5 opens, user logs in manually).

## Decisions (from brainstorming)

- Provisioning: env vars (compose / `.env`) + a mounted host folder of `.ex5` files.
- Symbol / timeframe / EA name: env vars with sensible defaults.
- EA form: pre-compiled `.ex5`, default inputs (no `.set` file, no compile step).
- No-creds behavior: just open MT5 normally (safe default, image stays usable).
- Mechanism: `terminal64.exe /portable /config:<startup.ini>` (Approach A).
  Portable mode keeps data paths deterministic inside the mounted `/root/.wine`
  volume (`<install>/MQL5/Experts`, `<install>/config`) instead of a per-instance
  roaming hash dir.

## Components & control flow

New script `scripts/06-run-ea.sh`, invoked from `01-start.sh` after
`05-install-mt5.sh`. To avoid launching MT5 twice, the launch moves OUT of `05`
(which becomes install-only) into `06`:

```
01-start.sh
  ├─ init wine prefix (win11)
  ├─ 04 mono → 03 webview → 05 install MT5      (05: install ONLY)
  └─ 06-run-ea.sh
        if MT5_LOGIN && MT5_PASSWORD && MT5_SERVER:
           copy /ea/*.ex5 → <install>/MQL5/Experts/
           generate <install>/config/startup.ini
           wine terminal64.exe /portable /config:config\startup.ini
        else:
           wine terminal64.exe /portable           (today's behavior)
```

`terminal64.exe` path: `/root/.wine/drive_c/Program Files/MetaTrader 5/terminal64.exe`.

## Generated startup.ini

```ini
[Common]
Login=<MT5_LOGIN>
Password=<MT5_PASSWORD>
Server=<MT5_SERVER>
[Experts]
AllowLiveTrading=true
Enabled=true
Account=false
Profile=false
[StartUp]
Expert=<MT5_EA without .ex5>
Symbol=<MT5_SYMBOL>
Period=<MT5_TIMEFRAME>
```

- `Expert=` is relative to `MQL5\Experts`, no `.ex5` extension, backslash paths.
- `[Experts] AllowLiveTrading=true` enables Algo Trading so the EA can trade.

## Environment variables

| Var | Default | Purpose |
|---|---|---|
| `MT5_LOGIN` | (unset) | account number — presence enables auto-login |
| `MT5_PASSWORD` | (unset) | account password |
| `MT5_SERVER` | (unset) | broker server name |
| `MT5_EA` | (unset) | EA filename, e.g. `MyEA.ex5` (`.ex5` optional) |
| `MT5_SYMBOL` | `EURUSD` | chart symbol |
| `MT5_TIMEFRAME` | `H1` | chart period (e.g. M15, H1, D1) |

## docker-compose changes

- Add the env vars above (commented examples).
- Add read-only EA mount: `./experts:/ea:ro` — user drops `.ex5` files in `./experts/`.

## Error handling

- `terminal64.exe` missing → log ERROR, exit (do not hang).
- `MT5_LOGIN` set but password/server missing → log ERROR, fall back to plain launch.
- `MT5_EA` set but file not found in `/ea` → log ERROR, launch login-only (no Expert line).
- `/ea` not mounted / empty → skip EA copy.
- No `MT5_LOGIN` → plain launch (unchanged behavior).

## Verification

Automated (by us, no real account needed):
- `startup.ini` generated with correct sections/values from env.
- `.ex5` copied into `<install>/MQL5/Experts/`.
- `terminal64.exe` launched with `/portable /config:...`.
- MT5 journal shows login attempt + EA load (fake creds will fail login, but the
  attempt + EA-load entries confirm the wiring).
- No-creds path still opens MT5 normally.

Manual (by user): real login + live EA behavior with their account.

## Security & risk notes

- Password lives in env and in `startup.ini` (plaintext, inside the mounted
  volume) — inherent to MT5. Use a gitignored `.env`; never commit real creds.
- Enables unattended live auto-trading. Test on a DEMO account first.

## Out of scope

- `.set` parameter files, `.mq5` compilation, chart templates/profiles.
- Mono-install flakiness observed during probing (separate robustness item).
