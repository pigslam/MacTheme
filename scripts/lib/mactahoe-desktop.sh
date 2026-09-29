#!/usr/bin/env bash
# Shared desktop adjustments; caller supplies log/warn helpers.

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

# Resolve both distribution-installed and per-user extension schemas.
set_extension_preference() {
  local uuid="$1" schema="$2" key="$3" value="$4" dir writable
  local args=()
  command_exists gsettings || { warn "gsettings unavailable; skipping ${schema}"; return 0; }
  for dir in "${HOME}/.local/share/gnome-shell/extensions/${uuid}/schemas" \
             "/usr/share/gnome-shell/extensions/${uuid}/schemas"; do
    if [[ -f "${dir}/gschemas.compiled" ]]; then
      args=(--schemadir "${dir}")
      break
    fi
  done
  if ! writable="$(gsettings "${args[@]}" writable "${schema}" "${key}" 2>/dev/null)"; then
    warn "${schema} is not installed; skipping ${key}."
    return 0
  fi
  if [[ "${writable}" != "true" ]]; then
    warn "${schema} ${key} is locked; skipping."
    return 0
  fi
  if ! gsettings "${args[@]}" set "${schema}" "${key}" "${value}"; then
    warn "Could not set ${schema} ${key}."
    return 0
  fi
  log "Applied ${schema} ${key}=${value}"
}

apply_desktop_adjustments() {
  set_extension_preference dash-to-dock@micxgx.gmail.com \
    org.gnome.shell.extensions.dash-to-dock show-apps-at-top true
  set_extension_preference appindicatorsupport@rgcjonas.gmail.com \
    org.gnome.shell.extensions.appindicator compact-mode-enabled false
  set_extension_preference moveclock@kuvaus.org \
    org.gnome.shell.extensions.moveclock clock-before-statusmenu false
  if command_exists gnome-extensions && \
      gnome-extensions list 2>/dev/null | grep -Fxq moveclock@kuvaus.org; then
    # Move Clock reads placement on enable; cycle it after updating the setting.
    if gnome-extensions list --enabled 2>/dev/null | grep -Fxq moveclock@kuvaus.org; then
      gnome-extensions disable moveclock@kuvaus.org || warn "Could not reload Move Clock."
    fi
    gnome-extensions enable moveclock@kuvaus.org || warn "Could not enable Move Clock; log out/in and rerun."
  fi
}

extension_summary_row() {
  local name="$1" purpose="$2" url="$3"
  shift 3
  local uuid state='not found' on_disk='no'
  for uuid in "$@"; do
    if grep -Fxq "${uuid}" <<< "${summary_enabled}"; then
      state='enabled'
      break
    elif grep -Fxq "${uuid}" <<< "${summary_installed}"; then
      state='installed; enable/check in Extensions'
    elif [[ -d "${HOME}/.local/share/gnome-shell/extensions/${uuid}" ||
            -d "/usr/share/gnome-shell/extensions/${uuid}" ]]; then
      on_disk='yes'
    fi
  done
  if [[ "${state}" == 'not found' ]]; then
    if [[ "${on_disk}" == 'yes' ]]; then
      state='on disk; log out/in if GNOME has not loaded it'
    elif [[ "${summary_available}" == 'no' ]]; then
      state='status unavailable outside a GNOME session'
    fi
  fi
  printf '  %-18s [%s]\n    %s\n    %s\n' "${name}" "${state}" "${purpose}" "${url}"
}

print_setup_summary() {
  local summary_installed='' summary_enabled='' summary_available='no'
  if command_exists gnome-extensions; then
    if summary_installed="$(gnome-extensions list 2>/dev/null)"; then
      summary_available='yes'
      summary_enabled="$(gnome-extensions list --enabled 2>/dev/null)" || summary_enabled=''
    fi
  fi
  printf '\nNext steps — extensions and keyboard shortcuts\n\n'
  extension_summary_row 'User Themes' 'Loads the MacTahoe GNOME Shell theme.' \
    'https://extensions.gnome.org/extension/19/user-themes/' \
    user-theme@gnome-shell-extensions.gcampax.github.com user-theme@gnome-shell-extensions.gnome.org
  extension_summary_row 'Dash to Dock' 'Optional dock; MacTheme places its app launcher at the top.' \
    'https://extensions.gnome.org/extension/307/dash-to-dock/' dash-to-dock@micxgx.gmail.com
  extension_summary_row 'AppIndicator' 'Optional tray icons; MacTheme disables compact mode for aligned bubbles.' \
    'https://extensions.gnome.org/extension/615/appindicator-support/' appindicatorsupport@rgcjonas.gmail.com
  extension_summary_row 'Move Clock' 'Optional date/notification menu at the far right.' \
    'https://extensions.gnome.org/extension/6949/moveclock/' moveclock@kuvaus.org
  printf '\nInstall missing extensions using the links above, then enable them in Extensions.\n'
  printf 'After a new extension install, log out/in if needed and rerun the theme installer.\n'
  printf '\nToshy — optional macOS-style keyboard shortcuts\n'
  if [[ -f "${XDG_CONFIG_HOME:-${HOME}/.config}/toshy/toshy_config.py" ]]; then
    printf '  Existing Toshy configuration found (service status not checked).\n'
  else
    printf '  No Toshy configuration found. To start its interactive installer:\n'
    printf '    bash %q\n' "${ROOT_DIR}/scripts/install-toshy.sh"
    printf '  Or add --install-toshy to the deploy/refresh command.\n'
  fi
  printf '  Upstream instructions: https://github.com/RedBearAK/Toshy#how-to-install\n'
  printf '  On GNOME Wayland, enable ONE supported window-focus extension:\n'
  printf '    Xremap: https://extensions.gnome.org/extension/5060/xremap/\n'
  printf '    Window Calls Extended: https://extensions.gnome.org/extension/4974/window-calls-extended/\n'
  printf '    Focused Window D-Bus: https://extensions.gnome.org/extension/5592/focused-window-d-bus/\n'
  printf '  For the optional MX Keys S mapping, after installing Toshy:\n'
  printf '    bash %q\n' "${ROOT_DIR}/scripts/configure-toshy-mx-keys-s.sh"
  printf '    toshy-services-restart\n'
  printf '\nFully quit and reopen Firefox, Ghostty, and other themed apps to load new styles.\n'
}

finish_mactahoe_setup() {
  local status=0
  if [[ "${INSTALL_TOSHY:-no}" == 'yes' ]]; then
    bash "${ROOT_DIR}/scripts/install-toshy.sh" || status=$?
    if [[ "${status}" -ne 0 ]]; then
      warn "Theme setup completed, but Toshy installation did not finish (exit ${status})."
    fi
  fi
  if [[ "${SHOW_SUMMARY:-yes}" == 'yes' ]]; then
    print_setup_summary
  fi
  return "${status}"
}
