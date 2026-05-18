#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GTK_REPO="${ROOT_DIR}/vendor/MacTahoe-gtk-theme"
GTK_THEME_DARK="MacTahoe-Dark"
GTK_THEME_LIGHT="MacTahoe-Light"
MODE="dark"
REFRESH_GTK="yes"
REFRESH_FIREFOX="yes"
REFRESH_THUNDERBIRD="yes"
REFRESH_FLATPAK="yes"

usage() {
  cat <<'EOF'
Usage: scripts/refresh-mactahoe-profiles.sh [options]

Refreshes per-user settings that app updates or new profiles may miss:
GTK decoration/theme settings, Firefox/Thunderbird userChrome traffic lights,
and known Flatpak theme access.

Options:
  --mode dark|light          GTK theme mode to write. Default: dark
  --gtk                      Refresh GTK 3/4 settings. Default
  --no-gtk                   Do not write GTK settings
  --firefox                  Refresh detected Firefox profiles. Default
  --no-firefox               Do not modify Firefox profiles
  --thunderbird              Refresh detected Thunderbird profiles. Default
  --no-thunderbird           Do not modify Thunderbird profiles
  --flatpak                  Refresh known installed Flatpak theme access. Default
  --no-flatpak               Do not modify Flatpak overrides
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

flatpak_app_installed() {
  local app_id="$1"
  command_exists flatpak || return 1
  flatpak info "${app_id}" >/dev/null 2>&1
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

refresh_gtk_settings() {
  local layout='close,minimize,maximize:'
  local gtk_theme="${GTK_THEME_DARK}"
  local prefer_dark="1"

  if [[ "${MODE}" == "light" ]]; then
    gtk_theme="${GTK_THEME_LIGHT}"
    prefer_dark="0"
  fi

  log "Refreshing GTK decoration and theme settings"
  ensure_gtk_setting "${HOME}/.config/gtk-3.0/settings.ini" "gtk-decoration-layout" "${layout}"
  ensure_gtk_setting "${HOME}/.config/gtk-3.0/settings.ini" "gtk-theme-name" "${gtk_theme}"
  ensure_gtk_setting "${HOME}/.config/gtk-3.0/settings.ini" "gtk-application-prefer-dark-theme" "${prefer_dark}"
  ensure_gtk_setting "${HOME}/.config/gtk-4.0/settings.ini" "gtk-decoration-layout" "${layout}"
  ensure_gtk_setting "${HOME}/.config/gtk-4.0/settings.ini" "gtk-theme-name" "${gtk_theme}"
  ensure_gtk_setting "${HOME}/.config/gtk-4.0/settings.ini" "gtk-application-prefer-dark-theme" "${prefer_dark}"
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

install_firefox_profile_theme() {
  local profile_dir="$1"
  local chrome_dir="${profile_dir}/chrome"
  local firefox_source="${GTK_REPO}/other/firefox"
  local user_js="${profile_dir}/user.js"

  need_file "${firefox_source}/userChrome.css"
  need_file "${firefox_source}/userContent.css"

  mkdir -p "${chrome_dir}"
  if [[ ! -e "${chrome_dir}/.mactahoe-backup" ]]; then
    mkdir -p "${chrome_dir}/.mactahoe-backup"
    find "${chrome_dir}" -mindepth 1 -maxdepth 1 ! -name '.mactahoe-backup' -exec cp -a {} "${chrome_dir}/.mactahoe-backup/" \;
  fi

  rm -rf "${chrome_dir}/MacTahoe"
  cp -a "${firefox_source}/MacTahoe" "${chrome_dir}/"
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

refresh_firefox() {
  log "Refreshing Firefox profiles"
  mapfile -t firefox_profiles < <(firefox_profile_dirs)
  if [[ "${#firefox_profiles[@]}" -eq 0 ]]; then
    warn "No Firefox profiles were found. Launch Firefox once, then rerun this script."
    return
  fi

  local profile
  for profile in "${firefox_profiles[@]}"; do
    log "Applying Firefox buttons to ${profile}"
    install_firefox_profile_theme "${profile}"
  done
  warn "Restart Firefox to load the updated userChrome.css."
}

refresh_thunderbird() {
  log "Refreshing Thunderbird profiles"
  mapfile -t thunderbird_profiles < <(thunderbird_profile_dirs)
  if [[ "${#thunderbird_profiles[@]}" -eq 0 ]]; then
    warn "No Thunderbird profiles were found. Launch Thunderbird once, then rerun this script."
    return
  fi

  local profile
  for profile in "${thunderbird_profiles[@]}"; do
    log "Applying Thunderbird buttons to ${profile}"
    install_thunderbird_profile_theme "${profile}"
  done
  warn "Restart Thunderbird to load the updated userChrome.css."
}

refresh_known_flatpaks() {
  local gtk_theme="${GTK_THEME_DARK}"
  if [[ "${MODE}" == "light" ]]; then
    gtk_theme="${GTK_THEME_LIGHT}"
  fi

  if ! command_exists flatpak; then
    warn "Flatpak is not installed; skipping Flatpak theme access."
    return
  fi

  local known_flatpaks=(
    tv.plex.PlexDesktop
  )

  local app_id found_any="no"
  log "Refreshing known Flatpak theme access"
  for app_id in "${known_flatpaks[@]}"; do
    if ! flatpak_app_installed "${app_id}"; then
      continue
    fi

    found_any="yes"
    log "Allowing host theme files for ${app_id}"
    flatpak override --user \
      --filesystem=xdg-config/gtk-3.0:ro \
      --filesystem=xdg-config/gtk-4.0:ro \
      --filesystem="${HOME}/.themes:ro" \
      --filesystem="${HOME}/.local/share/icons:ro" \
      --env="GTK_THEME=${gtk_theme}" \
      --env="XCURSOR_THEME=MacTahoe-cursors" \
      "${app_id}"
  done

  if [[ "${found_any}" == "no" ]]; then
    warn "No known Flatpak apps were found."
  else
    warn "Restart affected Flatpak apps to pick up theme access."
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode)
      MODE="${2:-}"
      [[ "${MODE}" == "dark" || "${MODE}" == "light" ]] || die "--mode must be dark or light"
      shift 2
      ;;
    --gtk)
      REFRESH_GTK="yes"
      shift
      ;;
    --no-gtk)
      REFRESH_GTK="no"
      shift
      ;;
    --firefox)
      REFRESH_FIREFOX="yes"
      shift
      ;;
    --no-firefox)
      REFRESH_FIREFOX="no"
      shift
      ;;
    --thunderbird)
      REFRESH_THUNDERBIRD="yes"
      shift
      ;;
    --no-thunderbird)
      REFRESH_THUNDERBIRD="no"
      shift
      ;;
    --flatpak)
      REFRESH_FLATPAK="yes"
      shift
      ;;
    --no-flatpak)
      REFRESH_FLATPAK="no"
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

[[ "${REFRESH_GTK}" == "yes" ]] && refresh_gtk_settings
[[ "${REFRESH_FIREFOX}" == "yes" ]] && refresh_firefox
[[ "${REFRESH_THUNDERBIRD}" == "yes" ]] && refresh_thunderbird
[[ "${REFRESH_FLATPAK}" == "yes" ]] && refresh_known_flatpaks

log "MacTahoe profile refresh complete"
