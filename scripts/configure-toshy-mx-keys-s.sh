#!/usr/bin/env bash
set -euo pipefail

CONFIG_FILE="${XDG_CONFIG_HOME:-${HOME}/.config}/toshy/toshy_config.py"
BACKUP_DIR="${CONFIG_FILE}.mactheme-backups"
PREF_DB="$(dirname "${CONFIG_FILE}")/toshy_user_preferences.sqlite"
MARKER="# MacTheme MX Keys S modifier policy"

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

[[ -f "${CONFIG_FILE}" ]] || die "Toshy config not found: ${CONFIG_FILE}"

clear_global_kbtype_override() {
  [[ -f "${PREF_DB}" ]] || return 0

  if ! PREF_DB="${PREF_DB}" python3 - <<'PY'
import os
import sqlite3

with sqlite3.connect(os.environ["PREF_DB"]) as db:
    row = db.execute(
        "select value from config_preferences where name = 'override_kbtype'"
    ).fetchone()
raise SystemExit(0 if not row or not row[0] else 1)
PY
  then
    mkdir -p "${BACKUP_DIR}"
    pref_backup="${BACKUP_DIR}/toshy_user_preferences.sqlite.$(date +%Y%m%d-%H%M%S)"
    cp -a "${PREF_DB}" "${pref_backup}"
    PREF_DB="${PREF_DB}" python3 - <<'PY'
import os
import sqlite3

with sqlite3.connect(os.environ["PREF_DB"]) as db:
    db.execute(
        "update config_preferences set value = '' where name = 'override_kbtype'"
    )
    db.commit()
PY
    printf 'Cleared Toshy global keyboard-type override; MX Keys S will use automatic classification.\n'
    printf 'Preference backup: %s\n' "${pref_backup}"
  fi
}

clear_global_kbtype_override

if grep -qF "${MARKER}" "${CONFIG_FILE}"; then
  if ! grep -A 10 'Cond modmap.*Terms - Win kbd - Opt held' "${CONFIG_FILE}" | grep -q 'not mactheme_is_mx_keys_s(ctx)'; then
    mkdir -p "${BACKUP_DIR}"
    backup_path="${BACKUP_DIR}/toshy_config.py.$(date +%Y%m%d-%H%M%S)"
    cp -a "${CONFIG_FILE}" "${backup_path}"
    CONFIG_FILE="${CONFIG_FILE}" python3 - <<'PY'
import os
import re
from pathlib import Path

path = Path(os.environ["CONFIG_FILE"])
text = path.read_text()
pattern = (
    r'(modmap\("Cond modmap - Terms - Win kbd - Opt held".*?'
    r'ctx_kbd_is_windows and\n)(    ctx_app_is_terminal)'
)
text, count = re.subn(pattern, r'\1    not mactheme_is_mx_keys_s(ctx) and\n\2', text, count=1, flags=re.S)
if count != 1:
    raise SystemExit("expected Toshy Windows terminal Opt-held modmap was not found; no changes made")
path.write_text(text)
PY
    printf 'Updated MacTheme MX Keys S policy in %s\nBackup: %s\n' "${CONFIG_FILE}" "${backup_path}"
    printf 'Restart Toshy with: toshy-services-restart\n'
  else
    printf 'MacTheme MX Keys S policy is already installed in %s\n' "${CONFIG_FILE}"
  fi
  exit 0
fi

mkdir -p "${BACKUP_DIR}"
backup_path="${BACKUP_DIR}/toshy_config.py.$(date +%Y%m%d-%H%M%S)"
cp -a "${CONFIG_FILE}" "${backup_path}"

CONFIG_FILE="${CONFIG_FILE}" MARKER="${MARKER}" python3 - <<'PY'
import os
import re
from pathlib import Path

path = Path(os.environ["CONFIG_FILE"])
marker = os.environ["MARKER"]
text = path.read_text()

functions_start = re.search(r"###\s+SLICE_MARK_START:\s+user_custom_functions", text)
device_helper = """

def mactheme_is_mx_keys_s(ctx):
    # Bolt exposes the keyboard as Logitech USB Receiver; Bluetooth exposes
    # the product name. Toshy calls this for keyboard contexts only.
    name = ctx.device_name.casefold()
    return (\"logitech usb receiver\" in name or \"mx keys s\" in name)
"""
if not functions_start:
    raise SystemExit("expected Toshy user_custom_functions slice was not found; no changes made")
text, count = re.subn(
    r"\n(###\s+SLICE_MARK_END:\s+user_custom_functions)",
    device_helper + r"\n\1",
    text,
    count=1,
)
if count != 1:
    raise SystemExit("expected Toshy user_custom_functions end marker was not found; no changes made")

win_gui_old = """modmap(\"Cond modmap - GUI - Win kbd\", {
    # - Default Mac/Win
    # - Default Win
    Key.LEFT_CTRL:              Key.LEFT_META,                  # WinMac
    # LEFT_ALT (Cmd) and LEFT_META (Opt) handled by the held companions / Super tap multis
}, when = lambda ctx:
    cnfg.screen_has_focus and
    ctx_kbd_is_windows and
    not ctx_app_is_terminal and not ctx_app_is_remote
)"""
win_gui_new = """modmap(\"Cond modmap - GUI - Win kbd\", {
    # - Default Mac/Win
    # - Default Win
    ${marker}: keep the physical Ctrl key as Ctrl for the MX Keys S policy.
    Key.LEFT_CTRL:              Key.LEFT_CTRL,                  # MacTheme MX Keys S
    # LEFT_ALT (Cmd) and LEFT_META (Opt) handled by the held companions / Super tap multis
}, when = lambda ctx:
    cnfg.screen_has_focus and
    ctx_kbd_is_windows and
    mactheme_is_mx_keys_s(ctx) and
    not ctx_app_is_terminal and not ctx_app_is_remote
)""".replace("${marker}", marker)

if win_gui_old not in text:
    raise SystemExit("expected Toshy Windows GUI modmap was not found; no changes made")
text = text.replace(win_gui_old, win_gui_new, 1)

opt_old = """modmap(\"Cond modmap - GUI - Win kbd - Opt held\", {
    Key.LEFT_META:              Key.LEFT_ALT,                   # WinMac - Opt (held)
}, when = lambda ctx:
    not cnfg.l_opt_is_sup_and_opt and
    cnfg.screen_has_focus and
    ctx_kbd_is_windows and
    not ctx_app_is_terminal and not ctx_app_is_remote
)"""
opt_new = """modmap(\"Cond modmap - GUI - Win kbd - Opt held\", {
    Key.LEFT_META:              Key.LEFT_ALT,                   # WinMac - Opt (held)
}, when = lambda ctx:
    not cnfg.l_opt_is_sup_and_opt and
    cnfg.screen_has_focus and
    ctx_kbd_is_windows and
    not mactheme_is_mx_keys_s(ctx) and
    not ctx_app_is_terminal and not ctx_app_is_remote
)""".replace("${marker}", marker)

if opt_old not in text:
    raise SystemExit("expected Toshy Windows Opt-held modmap was not found; no changes made")
text = text.replace(opt_old, opt_new, 1)

terms_pattern = (
    r'(modmap\("Cond modmap - Terms - Win kbd - Opt held".*?'
    r'ctx_kbd_is_windows and\n)(    ctx_app_is_terminal)'
)
text, count = re.subn(
    terms_pattern,
    r'\1    not mactheme_is_mx_keys_s(ctx) and\n\2',
    text,
    count=1,
    flags=re.S,
)
if count != 1:
    raise SystemExit("expected Toshy Windows terminal Opt-held modmap was not found; no changes made")

user_apps_start = re.search(r"###\s+SLICE_MARK_START:\s+user_apps", text)
insert_before = "keymap(\"User terminal Cmd+A\", {"
policy = """

keymap(\"MacTheme MX Keys S Cmd-F4\", {
    # Physical left Alt/Cmd is Toshy's virtual Command (RC). Reserve only
    # this chord for the familiar Linux close-window action.
    C(\"RC-F4\"):              C(\"Alt-F4\"),
}, when = lambda ctx:
    cnfg.screen_has_focus and
    mactheme_is_mx_keys_s(ctx) and
    not ctx_app_is_remote
)
"""
if not user_apps_start or insert_before not in text:
    raise SystemExit("expected Toshy user_apps slice was not found; no changes made")
text = text.replace(insert_before, policy.lstrip("\n") + insert_before, 1)

path.write_text(text)
PY

printf 'Installed MacTheme MX Keys S policy in %s\nBackup: %s\n' "${CONFIG_FILE}" "${backup_path}"
printf 'Restart Toshy with: toshy-services-restart\n'
