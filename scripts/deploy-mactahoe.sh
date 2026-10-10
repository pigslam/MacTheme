#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GTK_REPO="${ROOT_DIR}/vendor/MacTahoe-gtk-theme"
ICON_REPO="${ROOT_DIR}/vendor/MacTahoe-icon-theme"
CURSOR_REPO="${ICON_REPO}/cursors"

THEME_DIR="${HOME}/.themes"
ICON_DIR="${HOME}/.local/share/icons"
GTK_THEME_DARK="MacTahoe-Dark"
GTK_THEME_LIGHT="MacTahoe-Light"
ICON_THEME="MacTahoe-dark"
CURSOR_THEME="MacTahoe-cursors"
MODE="dark"
INSTALL_TOSHY="no"
SHOW_SUMMARY="yes"
APPLY_SETTINGS="yes"
INSTALL_LIBADWAITA="yes"
INSTALL_ALL_GTK_RELEASES="no"
INSTALL_FIREFOX="yes"
INSTALL_THUNDERBIRD="yes"
INSTALL_FLATPAK="yes"
ICON_ACCENT="default"
ICON_BOLD="no"
PRINT_DEPS="no"
CONFIGURE_TOSHY="no"

usage() {
  cat <<'EOF'
Usage: scripts/deploy-mactahoe.sh [options]

Installs MacTahoe GTK, icon, and cursor themes for the current user.
No sudo is used.

Options:
  --print-deps               Print distro-specific prerequisite commands
  --mode dark|light          GNOME color mode to apply. Default: dark
  --icon-accent NAME         Icon accent: default, blue, purple, green, red,
                             orange, yellow, grey, nord, or all. Default: default
  --bold-icons               Install bold panel icon variant
  --libadwaita               Copy MacTahoe GTK 4 files into ~/.config/gtk-4.0. Default
  --no-libadwaita            Do not copy GTK 4/libadwaita files into ~/.config/gtk-4.0
  --firefox                  Install the Firefox userChrome theme into detected profiles. Default
  --no-firefox               Do not modify detected Firefox profiles
  --thunderbird              Install traffic-light buttons into detected Thunderbird profiles. Default
  --no-thunderbird           Do not modify detected Thunderbird profiles
  --flatpak                  Refresh known installed Flatpak theme access. Default
  --no-flatpak               Do not modify Flatpak overrides
  --toshy-mx-keys-s           Apply Ramon's MX Keys S mapping to existing Toshy; restart unless --no-apply
  --no-apply                 Install files but do not change GNOME settings
  --gtk-minimal              Install only Light and Dark GTK releases. Default
  --gtk-all                  Install all bundled GTK release variants
  --install-toshy           Run the optional upstream interactive Toshy installer afterward
  --no-summary              Hide the final extensions/keyboard setup guide
  --help                     Show this help
EOF
}

log() {
  printf '\033[1;34m==>\033[0m %s\n' "$*"
}

warn() {
  printf '\033[1;33mWARN:\033[0m %s\n' "$*" >&2
}

die() {
  printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2
  exit 1
}

need_file() {
  [[ -e "$1" ]] || die "Missing required file: $1"
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

source "${ROOT_DIR}/scripts/lib/mactahoe-desktop.sh"

user_theme_extension_dirs() {
  find \
    "${HOME}/.local/share/gnome-shell/extensions" \
    "/usr/share/gnome-shell/extensions" \
    -mindepth 1 -maxdepth 1 -type d \
    \( -name 'user-theme@gnome-shell-extensions.gcampax.github.com' -o -name 'user-theme@gnome-shell-extensions.gnome.org' \) \
    2>/dev/null || true
}

first_user_theme_uuid() {
  local dir
  dir="$(user_theme_extension_dirs | head -n 1)"
  [[ -n "${dir}" ]] || return 1
  basename "${dir}"
}

gnome_extensions_knows_uuid() {
  local uuid="$1"
  command_exists gnome-extensions || return 1
  gnome-extensions list 2>/dev/null | grep -Fxq "${uuid}"
}

os_field() {
  local key="$1"
  if [[ -r /etc/os-release ]]; then
    awk -F= -v key="$key" '$1 == key { gsub(/^"|"$/, "", $2); print $2 }' /etc/os-release
  fi
}

print_dependency_commands() {
  local os_id os_like
  os_id="$(os_field ID)"
  os_like="$(os_field ID_LIKE)"

  case " ${os_id} ${os_like} " in
    *" opensuse"*|*" suse"*)
      cat <<'EOF'
openSUSE:
sudo zypper refresh
sudo zypper install git-core glib2-tools gtk3-tools python3 gnome-tweaks gnome-shell-extension-user-theme

Optional extension bundle:
sudo zypper install gnome-shell-extensions
EOF
      ;;
    *" debian"*|*" ubuntu"*)
      cat <<'EOF'
Debian/Ubuntu:
sudo apt update
sudo apt install git libglib2.0-bin gtk-update-icon-cache python3 gnome-shell-extensions gnome-tweaks
EOF
      ;;
    *)
      cat <<'EOF'
Generic GNOME prerequisites:
- git and python3
- gsettings / GLib tools
- gtk-update-icon-cache / GTK tools
- gnome-tweaks
- GNOME Shell User Themes extension
EOF
      ;;
  esac
}

print_shell_theme_help() {
  local os_id os_like
  os_id="$(os_field ID)"
  os_like="$(os_field ID_LIKE)"

  warn "GNOME Shell User Themes extension is not installed/enabled, so the shell theme was not applied."
  case " ${os_id} ${os_like} " in
    *" opensuse"*|*" suse"*)
      cat >&2 <<'EOF'
Run these, then rerun this deploy script:
  sudo zypper refresh
  sudo zypper install gnome-shell-extension-user-theme gnome-tweaks

If that package name is unavailable in your enabled repositories:
  zypper search user-theme
EOF
      ;;
    *" debian"*|*" ubuntu"*)
      cat >&2 <<'EOF'
Run these, then rerun this deploy script:
  sudo apt update
  sudo apt install gnome-shell-extensions gnome-tweaks
EOF
      ;;
    *)
      cat >&2 <<'EOF'
Install the GNOME Shell User Themes extension, enable it, then rerun this deploy script.
EOF
      ;;
  esac
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --print-deps)
      PRINT_DEPS="yes"
      shift
      ;;
    --mode)
      MODE="${2:-}"
      [[ "$MODE" == "dark" || "$MODE" == "light" ]] || die "--mode must be dark or light"
      shift 2
      ;;
    --icon-accent)
      ICON_ACCENT="${2:-}"
      shift 2
      ;;
    --bold-icons)
      ICON_BOLD="yes"
      shift
      ;;
    --libadwaita)
      INSTALL_LIBADWAITA="yes"
      shift
      ;;
    --no-libadwaita)
      INSTALL_LIBADWAITA="no"
      shift
      ;;
    --firefox)
      INSTALL_FIREFOX="yes"
      shift
      ;;
    --no-firefox)
      INSTALL_FIREFOX="no"
      shift
      ;;
    --thunderbird)
      INSTALL_THUNDERBIRD="yes"
      shift
      ;;
    --no-thunderbird)
      INSTALL_THUNDERBIRD="no"
      shift
      ;;
    --flatpak)
      INSTALL_FLATPAK="yes"
      shift
      ;;
    --no-flatpak)
      INSTALL_FLATPAK="no"
      shift
      ;;
    --toshy-mx-keys-s)
      CONFIGURE_TOSHY="yes"
      shift
      ;;
    --no-apply)
      APPLY_SETTINGS="no"
      shift
      ;;
    --gtk-minimal)
      INSTALL_ALL_GTK_RELEASES="no"
      shift
      ;;
    --gtk-all)
      INSTALL_ALL_GTK_RELEASES="yes"
      shift
      ;;
    --install-toshy) INSTALL_TOSHY="yes"; shift ;;
    --no-summary) SHOW_SUMMARY="no"; shift ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      die "Unknown option: $1"
      ;;
  esac
done

if [[ "${PRINT_DEPS}" == "yes" ]]; then
  print_dependency_commands
  exit 0
fi

need_file "${GTK_REPO}/release/${GTK_THEME_DARK}.tar.xz"
need_file "${GTK_REPO}/release/${GTK_THEME_LIGHT}.tar.xz"
need_file "${ICON_REPO}/install.sh"
need_file "${CURSOR_REPO}/install.sh"

mkdir -p "${THEME_DIR}" "${ICON_DIR}"

command_exists python3 || die "python3 is required for verified theme installation."
log "Installing and verifying GTK theme files"
theme_args=(themes --full --mode "${MODE}")
[[ "${INSTALL_ALL_GTK_RELEASES}" == "yes" ]] && theme_args+=(--all)
[[ "${INSTALL_LIBADWAITA}" == "no" ]] && theme_args+=(--no-libadwaita)
python3 "${ROOT_DIR}/scripts/lib/mactahoe-files.py" "${theme_args[@]}"

log "Applying solid top bar contrast override"
find "${THEME_DIR}" -mindepth 1 -maxdepth 1 -type d -name 'MacTahoe*' -print0 |
  while IFS= read -r -d '' gtk_theme_dir; do
    apply_panel_contrast_override "${gtk_theme_dir}"
  done

log "Installing icon themes into ${ICON_DIR}"
icon_args=(-d "${ICON_DIR}")
if [[ "${ICON_ACCENT}" != "default" ]]; then
  icon_args+=(-t "${ICON_ACCENT}")
fi
if [[ "${ICON_BOLD}" == "yes" ]]; then
  icon_args+=(-b)
fi
bash "${ICON_REPO}/install.sh" "${icon_args[@]}"

log "Installing cursor themes into ${ICON_DIR}"
bash "${CURSOR_REPO}/install.sh" -d "${ICON_DIR}"

log "Refreshing GTK and Mozilla profile settings"
profile_refresh_args=(--mode "${MODE}" --no-theme-files --no-desktop --no-summary)
if [[ "${INSTALL_FIREFOX}" == "no" ]]; then
  profile_refresh_args+=(--no-firefox)
fi
if [[ "${INSTALL_THUNDERBIRD}" == "no" ]]; then
  profile_refresh_args+=(--no-thunderbird)
fi
if [[ "${INSTALL_FLATPAK}" == "no" ]]; then
  profile_refresh_args+=(--no-flatpak)
fi
bash "${ROOT_DIR}/scripts/refresh-mactahoe-profiles.sh" "${profile_refresh_args[@]}"

if command_exists gtk-update-icon-cache; then
  log "Refreshing icon caches"
  find "${ICON_DIR}" -mindepth 1 -maxdepth 1 -type d -name 'MacTahoe*' -print0 |
    while IFS= read -r -d '' icon_theme_dir; do
      gtk-update-icon-cache -q -f "${icon_theme_dir}" >/dev/null 2>&1 || true
    done
fi

if [[ "${APPLY_SETTINGS}" == "yes" ]]; then
  command_exists gsettings || die "gsettings is not installed; rerun with --no-apply or install GLib/GNOME tools."

  if [[ "${MODE}" == "light" ]]; then
    applied_gtk_theme="${GTK_THEME_LIGHT}"
    color_scheme="prefer-light"
  else
    applied_gtk_theme="${GTK_THEME_DARK}"
    color_scheme="prefer-dark"
  fi

  log "Applying GNOME settings"
  # On a horizontal dock, the leading ("top") position is the left edge.
  if gsettings list-schemas | grep -Fx org.gnome.shell.extensions.dash-to-dock >/dev/null; then
    gsettings set org.gnome.shell.extensions.dash-to-dock show-apps-at-top true
  fi
  gsettings set org.gnome.desktop.interface gtk-theme "${applied_gtk_theme}"
  gsettings set org.gnome.desktop.interface icon-theme "${ICON_THEME}"
  gsettings set org.gnome.desktop.interface cursor-theme "${CURSOR_THEME}"
  gsettings set org.gnome.desktop.interface color-scheme "${color_scheme}" || true
  gsettings set org.gnome.desktop.wm.preferences button-layout 'close,minimize,maximize:'
  apply_desktop_adjustments

  if user_theme_uuid="$(first_user_theme_uuid)"; then
    if gnome_extensions_knows_uuid "${user_theme_uuid}"; then
      if ! gnome-extensions enable "${user_theme_uuid}"; then
        warn "Could not enable ${user_theme_uuid} from this process. Run this in your terminal, then rerun this script:"
        printf '  gnome-extensions enable %s\n' "${user_theme_uuid}" >&2
      fi
    elif command_exists gnome-extensions; then
      warn "User Themes is installed on disk (${user_theme_uuid}), but GNOME Shell has not loaded it yet. Log out and back in, then rerun this script."
    fi
    set_extension_preference "${user_theme_uuid}" \
      org.gnome.shell.extensions.user-theme name "${applied_gtk_theme}"
  else
    print_shell_theme_help
  fi
else
  log "Skipping GNOME settings because --no-apply was used"
fi

warn "Fully restart Firefox, Ghostty, and other themed applications to load the installed styles."
if [[ "${CONFIGURE_TOSHY}" == "yes" ]]; then
  toshy_args=()
  [[ "${APPLY_SETTINGS}" == "yes" ]] && toshy_args+=(--restart)
  bash "${ROOT_DIR}/scripts/configure-toshy-mx-keys-s.sh" "${toshy_args[@]}"
fi

log "MacTahoe install complete"
finish_mactahoe_setup
