# MacTahoe GNOME Theme Bundle

This workspace vendors the MacTahoe GTK, icon, and cursor themes and adds a
single deploy script for GNOME systems.

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
- Firefox and Thunderbird profiles: traffic-light buttons only, when profiles already exist
- known Flatpak apps: user theme access for apps such as Plex
- GNOME settings: applied through `gsettings`
- window controls: moved to the upper left with close, minimize, maximize

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
```

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

That refreshes GTK 3/4 settings, detected Firefox and Thunderbird profiles, and
known installed Flatpak theme access. Use `--no-firefox`, `--no-thunderbird`,
`--no-gtk`, or `--no-flatpak` to narrow the pass.

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
sudo zypper install git-core glib2-tools gtk3-tools gnome-tweaks gnome-shell-extension-user-theme
```

Debian/Ubuntu:

```bash
sudo apt update
sudo apt install git libglib2.0-bin gtk-update-icon-cache gnome-shell-extensions gnome-tweaks
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
