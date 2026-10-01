# MacTahoe GNOME Theme Bundle

This workspace vendors the MacTahoe GTK, icon, and cursor themes and adds a
single deploy script for GNOME systems.

For the complete audit of post-install changes and the exact current-state
ledger, see [POST-INSTALL-CUSTOMIZATIONS.md](POST-INSTALL-CUSTOMIZATIONS.md).

The ledger also records the manual
[Executor GPU usage top-bar setup on Ramon and Garagebox](POST-INSTALL-CUSTOMIZATIONS.md#gnome-gpu-usage-top-bar-setup-ramon-and-garagebox)
for monitoring TheRidge's R9700.

## Install For The Current User

On a fresh machine, print the prerequisite commands first:

```bash
./scripts/deploy-mactahoe.sh --print-deps
```

For openSUSE, that prints the `zypper` path. For Debian/Ubuntu, it prints the
`apt` path.

```bash
./scripts/deploy-mactahoe.sh
```

The default install is user-scope only:

- GTK themes: `~/.themes`
- icon themes: `~/.local/share/icons`
- cursor themes: `~/.local/share/icons`
- GTK 4/libadwaita override: `~/.config/gtk-4.0` for apps such as Nautilus and Ptyxis
- GTK 3/4 settings: theme name, dark preference, and left-side decoration layout
- Firefox profiles: traffic-light buttons and consistent floating/maximized/tiled corners
- Thunderbird profiles: traffic-light buttons, when profiles already exist
- known Flatpak apps: user theme access for apps such as Plex
- GNOME settings: applied through `gsettings`
- window controls: moved to the upper left with close, minimize, maximize
- installed GNOME extensions: dock launcher at the top, aligned tray bubbles, and clock at the far right

Useful options:

```bash
./scripts/deploy-mactahoe.sh --mode light
./scripts/deploy-mactahoe.sh --icon-accent blue
./scripts/deploy-mactahoe.sh --bold-icons
./scripts/deploy-mactahoe.sh --libadwaita
./scripts/deploy-mactahoe.sh --no-libadwaita
./scripts/deploy-mactahoe.sh --firefox
./scripts/deploy-mactahoe.sh --no-firefox
./scripts/deploy-mactahoe.sh --thunderbird
./scripts/deploy-mactahoe.sh --no-thunderbird
./scripts/deploy-mactahoe.sh --flatpak
./scripts/deploy-mactahoe.sh --no-flatpak
./scripts/deploy-mactahoe.sh --no-apply
./scripts/deploy-mactahoe.sh --gtk-all
./scripts/deploy-mactahoe.sh --install-toshy
```

Both deploy and refresh finish with an extension checklist: User Themes, Dash
to Dock, AppIndicator, and Move Clock. It shows whether each is enabled,
installed, missing, or unavailable to inspect, with installation links. It also
lists optional Toshy setup and app restart steps. Use `--no-summary` to hide it.

## macOS-Style Keyboard Shortcuts

For macOS-style input behavior as well as appearance, use
[Toshy](https://github.com/RedBearAK/toshy) as an optional companion to this
theme. Toshy provides application-aware mappings for shortcuts such as
`Cmd+A`, `Cmd+Z`, `Cmd+X`, `Cmd+C`, and `Cmd+V`, including the different
behavior expected in terminal applications.

On Wayland GNOME, Toshy requires at least one supported GNOME Shell extension
to identify the focused application:

- [Xremap](https://extensions.gnome.org/extension/5060/xremap/)
- [Window Calls Extended](https://extensions.gnome.org/extension/4974/window-calls-extended/)
- [Focused Window D-Bus](https://extensions.gnome.org/extension/5592/focused-window-d-bus/)

To download Toshy and launch its official interactive installer after theme
setup, use `--install-toshy` with either deploy or refresh. You can also run it
independently:

```bash
./scripts/install-toshy.sh
```

This downloads a fresh upstream checkout into
`~/.local/share/mactheme/toshy-sources/` (or `$XDG_DATA_HOME/mactheme/toshy-sources/`)
and runs `setup_toshy.py install`. The source is retained for inspection/retry.
Run it in your desktop terminal: Toshy may request administrator access for
packages and input rules, and may require logout or reboot. Its prompts remain
interactive. Default theme runs do not download or install Toshy; even with
`--no-apply`, an explicit `--install-toshy` still starts that separate installer.
If Toshy fails, the completed theme setup remains and the command exits nonzero.
The MX Keys S policy is a separate opt-in after installation.

Follow Toshy's current installation and compatibility guidance when choosing
an extension. The optional `scripts/configure-toshy-mx-keys-s.sh` applies the
small, reproducible MX Keys S modifier policy used by this workstation. It
edits only Toshy's supported editable config slices plus the two Windows GUI
modifier entries that Toshy does not expose as preferences, and makes a
timestamped backup before changing anything. It preserves the existing
screenshot key mapping and clears any stale global Toshy keyboard-type
override so the MX Keys S can be classified automatically. The two device
names currently used by this model are matched: `Logitech USB Receiver` for
Bolt and `MX Keys S` for Bluetooth.

Run it after installing Toshy and connect the keyboard through the Bolt
receiver first:

```bash
./scripts/configure-toshy-mx-keys-s.sh
toshy-services-restart
```

The policy keeps physical Ctrl as Ctrl, leaves the middle Start/Opt key as
Linux Super, retains Toshy's normal Command behavior for the physical
Alt/Cmd key, and maps that key with F4 to Alt+F4. The Bolt receiver and the
Bluetooth representation share this one policy; no duplicated shortcut map
is maintained.

Firefox and Thunderbird draw their own titlebar controls, so the deploy script
installs a small `userChrome` override into detected profiles. Launch those apps
once before deploying so their profiles exist, then restart them afterwards.

## Refresh Profiles

After installing Firefox/Thunderbird later, creating new profiles, installing a
known Flatpak app such as Plex, or receiving a major app update, rerun only the
per-user app settings:

```bash
./scripts/refresh-mactahoe-profiles.sh
```

That now refreshes **GTK 3/4 theme files as well as settings**, the shared
GTK 4/libadwaita override used by Ghostty, Firefox/Thunderbird profiles,
installed dock/tray/clock extension settings, and known Flatpak theme access.
It installs the primary light/dark GTK files and refreshes already-installed
bundled variants. This prevents the stale 24 px floating and square maximized
corners that a profile-only refresh previously left behind. Icons and cursors
are not reinstalled by a refresh.

To limit the refresh:

```bash
# Browser profiles only
./scripts/refresh-mactahoe-profiles.sh --no-theme-files --no-gtk --no-desktop --no-flatpak
# Theme refresh without changing a personal GTK 4/libadwaita override
./scripts/refresh-mactahoe-profiles.sh --no-libadwaita
```

Other opt-outs include `--no-firefox`, `--no-thunderbird`, and `--no-flatpak`.
`--no-gtk` skips GTK settings; `--no-theme-files` separately skips theme assets.
Both install and refresh require Python 3 and verify the bundled GTK corner
rules before copying theme files. Rebuild the vendored release archives after
changing Sass; installing does not compile Sass.

Changed managed files and existing browser preferences are backed up under
`~/.local/state/mactheme/refresh-*`, with the backup path printed during the run.
Browser profile discovery reads `profiles.ini`, including named and external
profiles. Existing `customChrome.css`, `userContent.css`, and unrelated rules in
`userChrome.css` are preserved. Managed button placement lives under
`chrome/MacTahoe/mactheme-placement.css`; personal overrides load after it.
GTK 4 `settings.ini` and unrelated files are preserved too.

Dash to Dock, AppIndicator, and Move Clock are configured only when their
schemas are available. Move Clock is enabled/reloaded when GNOME recognizes
it; missing extensions are reported and are not installed automatically.
Use refresh's `--no-desktop` or deploy's `--no-apply` to skip these settings.
Toshy installation is an explicit `--install-toshy` opt-in; the MX Keys S
configuration remains a separate step.

Fully quit and reopen Firefox and Ghostty after a refresh. Merely opening a
new window in an existing process may retain the old styles.

Plex is included as a best-effort Flatpak target. If its titlebar still ignores
the theme after restarting Plex, it is likely using its own Qt/custom window
chrome; the rest of the theme setup can stay as-is.

## Package

```bash
./scripts/package-mactahoe.sh
```

The archive is written to `dist/` and includes `vendor/`, `scripts/`, and this
README.

## Optional Sudo Commands

The deploy script does not use `sudo`. On a fresh GNOME machine, install the
packages that match your distro before running the script.

openSUSE:

```bash
sudo zypper refresh
sudo zypper install git-core glib2-tools gtk3-tools python3 gnome-tweaks gnome-shell-extension-user-theme
```

Debian/Ubuntu:

```bash
sudo apt update
sudo apt install git libglib2.0-bin gtk-update-icon-cache python3 gnome-shell-extensions gnome-tweaks
```

To apply the GNOME Shell theme, enable the User Themes extension in GNOME
Extensions, then rerun:

```bash
./scripts/deploy-mactahoe.sh
```

On openSUSE, if that package name is unavailable in your enabled repositories,
search for the exact package name:

```bash
zypper search user-theme
```

The deploy script checks for the common User Themes UUIDs and enables the
extension automatically when it is installed.

If you install the User Themes extension while GNOME is already running, GNOME
Shell may not see it until the next login. Log out and back in, then rerun:

```bash
./scripts/deploy-mactahoe.sh
```

## Installer verification

```bash
python3 scripts/tests/test_install.py
```

These integration tests use disposable homes and stub desktop commands; they
do not change the current desktop. They cover stale theme upgrades, repeat
refreshes, personal browser CSS, named profiles, light mode, opt-outs, desktop
preferences, and full deployment orchestration.
