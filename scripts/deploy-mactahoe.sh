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
APPLY_SETTINGS="yes"
INSTALL_LIBADWAITA="yes"
INSTALL_ALL_GTK_RELEASES="no"
INSTALL_FIREFOX="yes"
INSTALL_THUNDERBIRD="yes"
INSTALL_FLATPAK="yes"
ICON_ACCENT="default"
ICON_BOLD="no"
PRINT_DEPS="no"

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
  --no-apply                 Install files but do not change GNOME settings
  --gtk-minimal              Install only Light and Dark GTK releases. Default
  --gtk-all                  Install all bundled GTK release variants
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

ensure_gtk_setting() {
  local settings_file="$1"
  local key="$2"
  local value="$3"

  mkdir -p "$(dirname "${settings_file}")"

  if [[ ! -f "${settings_file}" ]]; then
    printf '[Settings]\n%s=%s\n' "${key}" "${value}" > "${settings_file}"
    return
  fi

  if ! grep -q '^\[Settings\]' "${settings_file}"; then
    printf '\n[Settings]\n%s=%s\n' "${key}" "${value}" >> "${settings_file}"
    return
  fi

  if grep -q "^[[:space:]]*${key}=" "${settings_file}"; then
    sed -i "s|^[[:space:]]*${key}=.*|${key}=${value}|" "${settings_file}"
  else
    sed -i "/^\\[Settings\\]/a ${key}=${value}" "${settings_file}"
  fi
}

apply_gtk_decoration_layout() {
  local layout='close,minimize,maximize:'
  local gtk_theme="${GTK_THEME_DARK}"
  local prefer_dark="1"

  if [[ "${MODE}" == "light" ]]; then
    gtk_theme="${GTK_THEME_LIGHT}"
    prefer_dark="0"
  fi

  ensure_gtk_setting "${HOME}/.config/gtk-3.0/settings.ini" "gtk-decoration-layout" "${layout}"
  ensure_gtk_setting "${HOME}/.config/gtk-3.0/settings.ini" "gtk-theme-name" "${gtk_theme}"
  ensure_gtk_setting "${HOME}/.config/gtk-3.0/settings.ini" "gtk-application-prefer-dark-theme" "${prefer_dark}"
  ensure_gtk_setting "${HOME}/.config/gtk-4.0/settings.ini" "gtk-decoration-layout" "${layout}"
  ensure_gtk_setting "${HOME}/.config/gtk-4.0/settings.ini" "gtk-theme-name" "${gtk_theme}"
  ensure_gtk_setting "${HOME}/.config/gtk-4.0/settings.ini" "gtk-application-prefer-dark-theme" "${prefer_dark}"
}

install_firefox_profile_theme() {
  local profile_dir="$1"
  local chrome_dir="${profile_dir}/chrome"
  local firefox_source="${GTK_REPO}/other/firefox"
  local user_js="${profile_dir}/user.js"

  need_file "${firefox_source}/userChrome.css"
  need_file "${firefox_source}/userContent.css"
  need_file "${firefox_source}/customChrome.css"

  mkdir -p "${chrome_dir}"
  if [[ ! -e "${chrome_dir}/.mactahoe-backup" ]]; then
    mkdir -p "${chrome_dir}/.mactahoe-backup"
    find "${chrome_dir}" -mindepth 1 -maxdepth 1 ! -name '.mactahoe-backup' -exec cp -a {} "${chrome_dir}/.mactahoe-backup/" \;
  fi

  rm -rf "${chrome_dir}/MacTahoe"
  cp -a "${firefox_source}/MacTahoe" "${chrome_dir}/"
  cp -a "${firefox_source}/customChrome.css" "${chrome_dir}/"
  cp -a "${firefox_source}/userChrome.css" "${chrome_dir}/userChrome.css"
  cp -a "${firefox_source}/userContent.css" "${chrome_dir}/userContent.css"

  touch "${user_js}"
  ensure_user_pref "${user_js}" "toolkit.legacyUserProfileCustomizations.stylesheets" "true"
  ensure_user_pref "${user_js}" "browser.tabs.drawInTitlebar" "true"
  ensure_user_pref "${user_js}" "browser.uidensity" "0"
  ensure_user_pref "${user_js}" "layers.acceleration.force-enabled" "true"
  ensure_user_pref "${user_js}" "mozilla.widget.use-argb-visuals" "true"
  ensure_user_pref "${user_js}" "widget.gtk.rounded-bottom-corners.enabled" "true"
  ensure_user_pref "${user_js}" "svg.context-properties.content.enabled" "true"
}

install_thunderbird_profile_theme() {
  local profile_dir="$1"
  local chrome_dir="${profile_dir}/chrome"
  local firefox_source="${GTK_REPO}/other/firefox"
  local user_js="${profile_dir}/user.js"

  need_file "${firefox_source}/MacTahoe/firefox-titlebutton-compat.css"
  need_file "${firefox_source}/userChrome.css"

  mkdir -p "${chrome_dir}"
  if [[ ! -e "${chrome_dir}/.mactahoe-backup" ]]; then
    mkdir -p "${chrome_dir}/.mactahoe-backup"
    find "${chrome_dir}" -mindepth 1 -maxdepth 1 ! -name '.mactahoe-backup' -exec cp -a {} "${chrome_dir}/.mactahoe-backup/" \;
  fi

  rm -rf "${chrome_dir}/MacTahoe"
  cp -a "${firefox_source}/MacTahoe" "${chrome_dir}/"
  cp -a "${firefox_source}/userChrome.css" "${chrome_dir}/userChrome.css"

  touch "${user_js}"
  ensure_user_pref "${user_js}" "toolkit.legacyUserProfileCustomizations.stylesheets" "true"
  ensure_user_pref "${user_js}" "mail.tabs.drawInTitlebar" "true"
  ensure_user_pref "${user_js}" "browser.tabs.drawInTitlebar" "true"
}

ensure_user_pref() {
  local file="$1"
  local pref="$2"
  local value="$3"
  local line="user_pref(\"${pref}\", ${value});"

  if grep -q "^[[:space:]]*user_pref(\"${pref}\"" "${file}"; then
    sed -i "s|^[[:space:]]*user_pref(\"${pref}\".*|${line}|" "${file}"
  else
    printf '%s\n' "${line}" >> "${file}"
  fi
}

firefox_profile_dirs() {
  local base
  for base in \
    "${HOME}/.config/mozilla/firefox" \
    "${HOME}/.mozilla/firefox" \
    "${HOME}/.var/app/org.mozilla.firefox/.mozilla/firefox" \
    "${HOME}/snap/firefox/common/.mozilla/firefox"; do
    [[ -d "${base}" ]] || continue
    find "${base}" -mindepth 1 -maxdepth 1 -type d \
      \( -name '*.default*' -o -name '*default-release*' -o -name '*.dev-edition-default' \) \
      -print
  done
}

thunderbird_profile_dirs() {
  local base
  for base in \
    "${HOME}/.thunderbird" \
    "${HOME}/.config/thunderbird" \
    "${HOME}/.var/app/org.mozilla.Thunderbird/.thunderbird" \
    "${HOME}/snap/thunderbird/common/.thunderbird"; do
    [[ -d "${base}" ]] || continue
    find "${base}" -mindepth 1 -maxdepth 1 -type d \
      \( -name '*.default*' -o -name '*default-release*' -o -name '*.default-esr' \) \
      -print
  done
}

apply_panel_contrast_override() {
  local theme_root="$1"
  local shell_css="${theme_root}/gnome-shell/gnome-shell.css"
  local marker="/* MacTheme solid top bar override */"

  [[ -f "${shell_css}" ]] || return 0

  if grep -qF "${marker}" "${shell_css}"; then
    return 0
  fi

  cat >> "${shell_css}" <<'EOF'

/* MacTheme solid top bar override */
#panel {
  background-color: #242424;
  box-shadow: inset 0 -1px rgba(255, 255, 255, 0.08);
  color: #ffffff;
}

#panel .panel-corner {
  -panel-corner-background-color: #242424;
}

#panel StLabel,
#panel StIcon,
#panel .panel-button,
#panel .panel-button:hover,
#panel .panel-button:active,
#panel .panel-button:overview,
#panel .panel-button:focus,
#panel .panel-button:checked {
  color: #ffffff;
}

#panel:overview,
#panel.unlock-screen,
#panel.login-screen,
#panel.lock-screen {
  background-color: transparent;
  box-shadow: none;
}

#panel:overview .panel-corner,
#panel.unlock-screen .panel-corner,
#panel.login-screen .panel-corner,
#panel.lock-screen .panel-corner {
  -panel-corner-background-color: transparent;
}
EOF
}

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
sudo zypper install git-core glib2-tools gtk3-tools gnome-tweaks gnome-shell-extension-user-theme

Optional extension bundle:
sudo zypper install gnome-shell-extensions
EOF
      ;;
    *" debian"*|*" ubuntu"*)
      cat <<'EOF'
Debian/Ubuntu:
sudo apt update
sudo apt install git libglib2.0-bin gtk-update-icon-cache gnome-shell-extensions gnome-tweaks
EOF
      ;;
    *)
      cat <<'EOF'
Generic GNOME prerequisites:
- git
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

log "Installing GTK themes into ${THEME_DIR}"
if [[ "${INSTALL_ALL_GTK_RELEASES}" == "yes" ]]; then
  find "${GTK_REPO}/release" -maxdepth 1 -type f -name 'MacTahoe-*.tar.xz' -print0 |
    while IFS= read -r -d '' archive; do
      tar -xJf "${archive}" -C "${THEME_DIR}"
    done
else
  tar -xJf "${GTK_REPO}/release/${GTK_THEME_DARK}.tar.xz" -C "${THEME_DIR}"
  tar -xJf "${GTK_REPO}/release/${GTK_THEME_LIGHT}.tar.xz" -C "${THEME_DIR}"
fi

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

if [[ "${INSTALL_LIBADWAITA}" == "yes" ]]; then
  log "Installing GTK 4/libadwaita files into ~/.config/gtk-4.0"
  if [[ "${MODE}" == "light" ]]; then
    libadwaita_source="${THEME_DIR}/${GTK_THEME_LIGHT}/gtk-4.0"
  else
    libadwaita_source="${THEME_DIR}/${GTK_THEME_DARK}/gtk-4.0"
  fi
  need_file "${libadwaita_source}/gtk.css"
  mkdir -p "${HOME}/.config/gtk-4.0"
  backup_dir="${HOME}/.config/gtk-4.0.mactahoe-backup"
  if [[ ! -e "${backup_dir}" ]]; then
    mkdir -p "${backup_dir}"
    find "${HOME}/.config/gtk-4.0" -mindepth 1 -maxdepth 1 -exec cp -a {} "${backup_dir}/" \;
  fi
  find "${HOME}/.config/gtk-4.0" -mindepth 1 -maxdepth 1 -exec rm -rf {} +
  cp -a "${libadwaita_source}/." "${HOME}/.config/gtk-4.0/"
fi

log "Refreshing GTK and Mozilla profile settings"
profile_refresh_args=(--mode "${MODE}")
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
  gsettings set org.gnome.desktop.interface gtk-theme "${applied_gtk_theme}"
  gsettings set org.gnome.desktop.interface icon-theme "${ICON_THEME}"
  gsettings set org.gnome.desktop.interface cursor-theme "${CURSOR_THEME}"
  gsettings set org.gnome.desktop.interface color-scheme "${color_scheme}" || true
  gsettings set org.gnome.desktop.wm.preferences button-layout 'close,minimize,maximize:'

  if user_theme_uuid="$(first_user_theme_uuid)"; then
    if gnome_extensions_knows_uuid "${user_theme_uuid}"; then
      if ! gnome-extensions enable "${user_theme_uuid}"; then
        warn "Could not enable ${user_theme_uuid} from this process. Run this in your terminal, then rerun this script:"
        printf '  gnome-extensions enable %s\n' "${user_theme_uuid}" >&2
      fi
    elif command_exists gnome-extensions; then
      warn "User Themes is installed on disk (${user_theme_uuid}), but GNOME Shell has not loaded it yet. Log out and back in, then rerun this script."
    fi
    if gsettings writable org.gnome.shell.extensions.user-theme name >/dev/null 2>&1; then
      gsettings set org.gnome.shell.extensions.user-theme name "${applied_gtk_theme}" || true
    else
      warn "User Themes extension was found (${user_theme_uuid}), but its settings schema is not active yet. Log out/in or restart GNOME Shell, then rerun this script."
    fi
  else
    print_shell_theme_help
  fi
else
  log "Skipping GNOME settings because --no-apply was used"
fi

log "MacTahoe install complete"
