#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESTART=no
for arg in "$@"; do
  case "$arg" in
    --restart) RESTART=yes ;;
    --help|-h)
      printf 'Usage: %s [--restart]\nApply the verified Ramon MX Keys S modifier mapping to an existing Toshy install.\n' "$0"
      exit 0 ;;
    *) printf 'Unknown option: %s\n' "$arg" >&2; exit 1 ;;
  esac
done
CONFIG_FILE="${XDG_CONFIG_HOME:-${HOME}/.config}/toshy/toshy_config.py"
python3 "${ROOT_DIR}/scripts/lib/configure-toshy-mx-keys-s.py" "$CONFIG_FILE"
if [[ "$RESTART" == yes ]]; then
  restart_command="$(command -v toshy-services-restart || true)"
  [[ -n "$restart_command" ]] || restart_command="${HOME}/.local/bin/toshy-services-restart"
  [[ -x "$restart_command" ]] || { printf 'Mapping saved; Toshy restart command not found. Restart Toshy manually.\n' >&2; exit 1; }
  "$restart_command"
  systemctl --user is-active --quiet toshy-config.service
else
  printf 'Restart Toshy to load the mapping: toshy-services-restart\n'
fi
