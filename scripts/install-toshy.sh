#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == '--help' || "${1:-}" == '-h' ]]; then
  cat <<'EOF'
Usage: scripts/install-toshy.sh

Download a fresh checkout of the official Toshy repository and run its
interactive installer (setup_toshy.py install). Run in your desktop terminal.
Toshy may request administrator access to install packages and input rules.
Its prompts are passed through unchanged. No MX Keys S policy is applied.
EOF
  exit 0
fi
[[ $# -eq 0 ]] || { printf 'Unknown option; use --help.\n' >&2; exit 1; }
command -v git >/dev/null || { printf 'Install git first.\n' >&2; exit 1; }
command -v python3 >/dev/null || { printf 'Install python3 first.\n' >&2; exit 1; }

printf 'Starting the optional Toshy installer from https://github.com/RedBearAK/Toshy\n'
printf 'Toshy may request administrator access for dependencies and input rules.\n'
source_parent="${XDG_DATA_HOME:-${HOME}/.local/share}/mactheme/toshy-sources"
mkdir -p "${source_parent}"
source_dir="$(mktemp -d "${source_parent}/install-XXXXXXXX")"
printf 'Installer source (retained for inspection/retry): %s\n' "${source_dir}"
git clone --depth 1 https://github.com/RedBearAK/Toshy.git "${source_dir}"
[[ -f "${source_dir}/setup_toshy.py" ]] || { printf 'Toshy installer was not found in the checkout.\n' >&2; exit 1; }
cd "${source_dir}"
python3 ./setup_toshy.py install
printf '\nToshy installer finished. Follow its logout/reboot instructions.\n'
