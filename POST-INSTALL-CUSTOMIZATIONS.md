# Post-install customization ledger

This file records the work added after the original MacTahoe bundle was
imported. The repository's current `main` tree is the reproducible source of
truth; the deploy scripts apply the settings and generated theme assets on a
new machine.

## Reproduce the current theme

From this directory, after installing the distro prerequisites described in
`README.md`, run:

```bash
./scripts/deploy-mactahoe.sh --gtk-all --mode dark
```

That installs the GTK releases, icons, cursors, GTK 3/4 settings, libadwaita
override, Firefox/Thunderbird profile chrome, Flatpak theme access, GNOME
settings, and the dock launcher position. If only the primary dark/light
releases are wanted, omit `--gtk-all`.

For profiles created later or after browser updates, run:

```bash
./scripts/refresh-mactahoe-profiles.sh --mode dark
```

Restart affected applications after either operation. The scripts make
per-run backups of changed managed theme/chrome files and browser `user.js`
under `~/.local/state/mactheme/refresh-*`. Personal browser CSS and unrelated
GTK 4 settings are preserved.

## Changes made after the initial import

The initial import is commit `633a86ec` (`Initial MacTahoe GNOME theme bundle`).
The subsequent changes are:

### Firefox and Thunderbird traffic lights

Commits `c45ab938`, `3f977e51`, and `750b434a` added and then synchronized a
Firefox/Thunderbird chrome override:

- `vendor/MacTahoe-gtk-theme/other/firefox/userChrome.css` imports
  `customChrome.css`.
- `customChrome.css` places titlebar buttons 18 px from either edge, centers
  them in a 32 px button box, gives buttons 3 px inline spacing, and reserves
  a 10 px pre-tab spacer.
- `rounded-window-maximized.css` keeps Firefox clipped to the theme's 12 px
  window radius in floating, maximized, and tiled states, while leaving true
  fullscreen mode unclipped.
- The profile installer copies `customChrome.css` as well as the MacTahoe
  theme directory and enables the required custom stylesheet preferences.
- Firefox profiles additionally receive normal density, titlebar drawing,
  accelerated rendering, ARGB visuals, rounded bottom corners, and SVG
  context properties.
- Thunderbird profiles additionally receive `mail.tabs.drawInTitlebar` and
  `browser.tabs.drawInTitlebar`.

The refresh script covers both applications so this work survives new
profiles and app updates.

#### Firefox floating, maximized, and tiled window corners

Firefox needs an additional application-level fix beyond the GTK theme. On
Linux, Firefox draws browser chrome into its own child surface. Its packaged
`browser.css` reads the GTK titlebar radius through
`env(-moz-gtk-csd-titlebar-radius)`, but Firefox 155 only applies that rounded
clip when the window has `sizemode="normal"` and does not have the `[tiled]`
attribute. Maximizing the window or asking GNOME to fill/tile an area therefore
removes Firefox's own clip even when the surrounding GTK theme correctly keeps
maximized and tiled decorations rounded.

The working fix has several required pieces:

1. GTK 3 must expose the same nonzero radius for normal, maximized, tiled,
   fullscreen, and solid-CSD decorations. The source of truth is
   `src/sass/_variables.scss` plus the decoration selectors in
   `src/sass/gtk/_common-3.0.scss`.
2. The GTK release archives must be rebuilt after changing Sass. The top-level
   deploy script extracts `vendor/MacTahoe-gtk-theme/release/*.tar.xz`; it does
   not compile Sass. A source-only change has no effect on a deployed machine.
3. Firefox must have
   `widget.gtk.rounded-bottom-corners.enabled=true`. The profile refresh script
   writes that preference into each detected profile's `user.js`.
4. Firefox's native browser-document clip must be overridden. Styling
   `#nav-bar`, `#TabsToolbar`, `#navigator-toolbox`, or the root element alone
   only rounds visible toolbar backgrounds; it does not restore the transparent
   Wayland window corners. The override must target the HTML `body` and
   `dialog::backdrop`, matching Firefox's own GTK CSD rule.
5. Current Firefox uses the root `[tiled]` attribute. The older
   `[gtktiledwindow="true"]` selector does not match Firefox 155 and must not be
   used for this fix. Maximized windows still use `sizemode="maximized"`.
6. The override must use the XHTML namespace. Current `browser.xhtml` has an
   HTML root and body; a stylesheet whose default namespace is XUL will not
   match them.
7. The rule is limited by `-moz-gtk-csd-transparency-available` and excludes
   actual fullscreen. This prevents black clipped corners on configurations
   where GTK CSD transparency is unavailable and avoids cutting into video or
   presentation fullscreen.

The implemented selector lives in
`other/firefox/MacTahoe/rounded-window-maximized.css` and is imported by
`other/firefox/userChrome.css`. It intentionally mirrors the structure of the
Firefox 155 rule shipped in
`chrome/browser/skin/classic/browser/browser.css`:

```css
@namespace url("http://www.w3.org/1999/xhtml");

@media (-moz-gtk-csd-transparency-available) {
  :root[customtitlebar]:not([inFullscreen], [sizemode="fullscreen"]) body,
  :root[customtitlebar]:not([inFullscreen], [sizemode="fullscreen"]) dialog::backdrop {
    border-radius: 12px !important;
    overflow: clip !important;
  }
}
```

The override also covers normal floating windows so restoring a window does
not switch back to a different GTK environment radius. The native GTK
outline and Firefox content clip must agree. A later floating-window report
revealed installed GTK 3 files with a 24 px radius and an older Firefox
profile override, although the repository release archive already used 12 px.
The old profile-only refresh did not update installed GTK theme files. The
refresh script now updates those assets by default, alongside profile chrome.
The user confirmed that refreshing the installed GTK 3 stylesheets and Firefox
profile overrides corrected the floating-window radius and dotted arc.

To deploy or refresh this fix:

```bash
./scripts/refresh-mactahoe-profiles.sh --mode dark
```

Then fully quit Firefox and confirm that no Firefox process remains before
relaunching it. Merely closing one window is insufficient when Firefox remains
resident. On Fedora, the packaged rule that this override tracks can be
inspected with:

```bash
unzip -p /usr/lib64/firefox/browser/omni.ja \
  chrome/browser/skin/classic/browser/browser.css | \
  grep -A40 -B5 -- '-moz-gtk-csd-transparency-available'
```

This procedure was visually verified on September 15, 2026 with Fedora 44,
GNOME Shell 50.4 on Wayland, and Firefox 155.0. After refreshing both detected
profiles and launching Firefox from a fully stopped state, the browser retained
the 12 px transparent window corners when GNOME expanded it to fill a tiled
area. Normal and maximized states use the same radius; actual fullscreen remains
square by design.

The successful result specifically depended on all of the following being true:

- the rebuilt GTK release archives, rather than only the edited Sass source,
  were installed;
- Firefox read `widget.gtk.rounded-bottom-corners.enabled=true` from the active
  profile;
- `userChrome.css` imported `rounded-window-maximized.css`;
- the override selected Firefox's XHTML `body` with the current `[tiled]`
  attribute; and
- Firefox was fully restarted after the profile files were copied.

Earlier attempts that rounded `#nav-bar`, `#TabsToolbar`,
`#navigator-toolbox`, or `:root`, or that selected
`[gtktiledwindow="true"]`, changed internal toolbar backgrounds at most and did
not restore the native transparent corners. Keep this distinction when adapting
the rule for future Firefox releases.

After a major Firefox update, recheck that packaged rule and the attributes in
`chrome/browser/content/browser/browser.xhtml`. Mozilla can rename the tiled
state attribute or change which element owns the native clip. The authoritative
implementation is Mozilla's GTK look-and-feel code and packaged browser CSS;
toolbar-only userChrome recipes are not sufficient for this problem. Relevant
upstream references are [Firefox GTK look-and-feel source](https://searchfox.org/mozilla-central/source/widget/gtk/nsLookAndFeel.cpp)
and [Mozilla bug 1982979](https://bugzilla.mozilla.org/show_bug.cgi?id=1982979).

### GNOME Shell contrast and dock layout

Commit `74d87ed2` made the shell controls more legible and more consistent:

- Quick Settings translucent toggle backgrounds were raised from the original
  0.15/0.20/0.25 levels to approximately 0.20/0.25/0.30 across the GNOME 42,
  44, and 48 Sass variants.
- Shell menu asset shadow opacity changed from `0.25` to `0.32` at every
  bundled scale (`x1` through `x2`).
- The deploy script appends a guarded solid top-bar override to every
  installed MacTahoe GTK theme: `#242424` background, a subtle light bottom
  inset, white panel text/icons, and transparent panel corners on overview,
  lock, and login screens.
- The deploy script sets Dash to Dock's `show-apps-at-top` to `true` when the
  extension schema is available.

The bundled release archives are generated from the adjusted source. After
changing the Sass variables or selectors, rerun
`vendor/MacTahoe-gtk-theme/make-release.sh` before deploying; the deploy script
extracts those archives and does not compile Sass itself.

### System tray bubble alignment

With the MacTahoe-Dark shell theme, AppIndicator compact mode left tray icons
horizontally off-center inside their hover/active bubbles. Compact mode requests
10 px natural horizontal padding, while the theme specifies a 16 px minimum
for these buttons. Disabling compact mode restores matching theme padding.
The user confirmed that this corrected the alignment on the source machine.

For the per-user AppIndicator extension installation, apply the fix with:

```bash
gsettings --schemadir "$HOME/.local/share/gnome-shell/extensions/appindicatorsupport@rgcjonas.gmail.com/schemas" \
  set org.gnome.shell.extensions.appindicator compact-mode-enabled false
```

The change takes effect immediately and may make tray spacing slightly wider.
To undo it, run the same command with `true` instead of `false`. If the
extension's schema is installed system-wide, omit `--schemadir` and its path.
Deploy and refresh now apply this setting when the extension schema is
available, including per-user schema installations.

### Date, clock, and notification menu position

The source machine uses [Move Clock](https://extensions.gnome.org/extension/6949/moveclock/)
(`moveclock@kuvaus.org`, version 11), verified active on GNOME Shell 50.4.
With `clock-before-statusmenu=false`, it moves the entire date menu to the
far right of the top bar, after Quick Settings. The date, clock, notification
indicator, and calendar/notification panel opened by clicking it move together.
The user confirmed this is the desired behavior. New notification pop-up
banners remain at the top center.

To reproduce, install Move Clock from the linked GNOME Extensions page. If
GNOME does not recognize the new extension immediately, log out and back in.
Then run:

```bash
gsettings --schemadir "$HOME/.local/share/gnome-shell/extensions/moveclock@kuvaus.org/schemas" \
  set org.gnome.shell.extensions.moveclock clock-before-statusmenu false
gnome-extensions enable moveclock@kuvaus.org
```

If changing the setting while the extension is already active, disable and
re-enable it. To restore the centered date menu, run
`gnome-extensions disable moveclock@kuvaus.org`.
Deploy and refresh now configure this setting and enable/reload Move Clock
when GNOME recognizes it. They do not install the extension.

### Ghostty GTK 4 corner refresh

Ghostty 1.3.1 on this machine uses GTK 4 with libadwaita. Its installed
`~/.config/gtk-4.0/gtk.css` and `gtk-dark.css` still had 24 px floating corners
and 0 px maximized/tiled corners. The repository release archive already had
12 px rules for these states. Both GTK 4 override stylesheets and the GTK 4
stylesheets in the installed MacTahoe-Dark/Light themes were refreshed from
those archives, with backups under
`~/.local/state/mactheme/gtk4-corner-backup-20260928-211717`.

The installed files were verified against the archive, including asset paths.
The user confirmed that a full Ghostty restart corrected both floating and
maximized corners. The GTK 4 override is shared by other GTK 4 applications, so those
applications also receive the corrected radii after restarting. The existing
`deploy-mactahoe.sh` default libadwaita installation reproduces this update;
`refresh-mactahoe-profiles.sh` now also copies GTK theme stylesheets by default.

### Installer consolidation after corner fixes

The deploy and refresh paths now share `scripts/lib/mactahoe-files.py` for
validated GTK installation and per-run backups. Refresh updates primary and
already-installed bundled GTK variants, plus the GTK 4 override, by default.
`--no-theme-files` retains a profile/settings-only pass; `--no-libadwaita`
preserves a personal GTK 4 override. The helper checks normal and maximized
12 px rules before any theme files are installed and verifies written bytes.

Mozilla profiles are discovered through `profiles.ini` as well as legacy
folder naming. Managed imports and placement CSS are refreshed without replacing
personal CSS. Thunderbird receives its missing placement file but does not
import Firefox's browser-document clipping rule. The unused duplicate browser
installer functions were removed from the deploy script.

Shared extension configuration covers the dock launcher, tray alignment, clock
position, and per-user schema lookup. Python integration tests exercise the
installer in disposable homes with desktop commands stubbed.

### Window corner radii

Commit `ea6d8a6b` tightened and preserved the rounded-window treatment:

- `$wm_radius`: 26/24 px → 14/12 px for desktop/laptop profiles.
- `$maximized_radius`: `0` → `$wm_radius`.
- GTK 3 and GTK 4 solid CSD, maximized, fullscreen, and tiled rules now use
  those variables instead of forcing square corners.

### Keyboard behavior

Commits `879157f2` and `468aa1fe` documented Toshy as an optional companion.
Toshy is not installed by default. Deploy/refresh offer `--install-toshy` to
launch the upstream interactive installer after theme setup. The
separate optional `scripts/configure-toshy-mx-keys-s.sh` reproduces the confirmed
MX Keys S modifier mapping, preserves the screenshot shortcut, and restores
terminal Select All by mapping `Cmd+A` to `Ctrl+Shift+A`. Upstream Toshy maps
terminal `Cmd+C/V` but deliberately leaves `Cmd+A` disabled, so the explicit
terminal rule is part of the verified MacTheme policy. On Wayland it also needs
a supported focused-window GNOME extension; current links and guidance are
maintained in `README.md`.

### Activities Overview shortcut and hot corner

On October 11, 2026, the Windows/Start key was restored to open GNOME's
Activities Overview, which shows previews of running windows. Toshy's installer
had disabled the `org.gnome.mutter` `overlay-key` setting. Restoring it to
`Super_L` preserved the existing Toshy Command-key mappings, and the user
confirmed that the Windows/Start key worked again.

On October 12, 2026, GNOME's hot corner was disabled at the user's request.
The Windows/Start key remains enabled for opening Activities Overview.

To reproduce these manual desktop settings:

```bash
gsettings set org.gnome.mutter overlay-key 'Super_L'
gsettings set org.gnome.desktop.interface enable-hot-corners false
```

The applied values were verified as `'Super_L'` and `false`, respectively.
Deploy and refresh do not currently apply these settings. Recheck `overlay-key`
after reinstalling Toshy, since its installer disables that binding.

## GNOME GPU usage top-bar setup (Ramon and Garagebox)

Added manually on Ramon and Garagebox on September 30, 2026. Both machines
use the **Executor** GNOME extension to show live utilization for the R9700
in TheRidge directly in their GNOME top bars. This is a reference for manual
setup; deploy and refresh do not configure it.

### Prerequisites

Install Executor on each display machine. TheRidge needs `rocm-smi` and `jq`;
the display machine needs `ssh`, `timeout`, and `awk`.

Run this test from Ramon or Garagebox:

```bash
ssh theridge true
```

It should complete without asking for a password or host-key confirmation.
The `theridge` SSH destination must resolve and allow noninteractive access
from each machine.

### Executor command

Paste this command into Executor on Ramon and Garagebox:

```bash
timeout 2 ssh -o BatchMode=yes -o ConnectTimeout=1 theridge 'rocm-smi --showuse --json 2>/dev/null | jq -r '\''to_entries[0].value["GPU use (%)"]'\''' 2>/dev/null | awk '{print "R9700 "$1"%"}'
```

Expected output, with utilization varying over time:

```text
R9700 64%
```

Recommended Executor settings:

- Refresh interval: 1–2 seconds.
- Display: command output.
- Position: left side of the GNOME top bar, if desired.

The command SSHes to TheRidge, runs `rocm-smi`, uses `jq` to extract
`GPU use (%)` from the first JSON entry, and formats it as `R9700 NN%`.
This assumes the first entry is the R9700. SSH and `rocm-smi` error output is
suppressed; if SSH produces no output, the top-bar item is blank.

The SSH options and timeout keep Executor from hanging when TheRidge is
unavailable:

- `BatchMode=yes` prevents interactive password prompts.
- `ConnectTimeout=1` limits the SSH connection wait to one second.
- `timeout 2` stops a stuck SSH process after two seconds.

For exact control over the Executor item's position among GNOME top-bar
items, optionally use **Top Bar Organizer Plus**.

## Verified state on the source machine

The audit found the following theme-related state:

- GNOME GTK theme: `MacTahoe-Dark`
- Icon theme: `MacTahoe-dark`
- Cursor theme: `MacTahoe-cursors`
- Color scheme: `prefer-dark`
- Window buttons: `close,minimize,maximize:` (left side)
- User Themes shell theme: `MacTahoe-Dark`
- Dash to Dock: `show-apps-at-top=true`
- GTK 3 and GTK 4 settings contain the same theme, dark preference, and
  decoration layout.
- Firefox and Thunderbird profiles contain the managed preferences listed
  above and the installed MacTahoe chrome files.
- The machine currently has all bundled GTK variants installed, including
  dark/light, solid, Nord, hdpi, and xhdpi variants. `--gtk-all` reproduces
  the eight bundled light/dark, solid, and Nord releases. The hdpi/xhdpi
  directories are not separate bundled release archives.
- A small piece of live-state drift remains: the solid top-bar marker is
  present in the installed solid/Nord variants but not in the primary
  `MacTahoe-Dark` and `MacTahoe-Light` directories. Rerunning the deploy
  script reconciles those installed copies; no live files were changed during
  this audit.

## Deliberately machine-specific

The following were visible in the desktop configuration but are not theme
customizations and are therefore not copied into this bundle: wallpaper and
wallpaper slideshow data, blur pipeline settings, the complete extension
roster, application favorites, and any personal Toshy configuration. Those
should be exported separately if an exact workstation clone is desired.

Default theme deployment does not require `sudo`; package installation and
optional GNOME extensions remain explicit prerequisites. The optional Toshy
installer can request administrator access for its dependencies and input rules.

Deploy and refresh finish with extension status/install links, Toshy installation
options, its GNOME Wayland focus-extension choices, the MX Keys S configuration
command, and restart reminders. `--no-summary` hides this guide. Nested refreshes
during deploy suppress it so the guide appears only once.
