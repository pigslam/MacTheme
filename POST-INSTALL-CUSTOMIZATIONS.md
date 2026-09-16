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
backups of existing Firefox/Thunderbird `chrome` files and the GTK 4 override
before replacing them.

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
- The profile installer copies `customChrome.css` as well as the MacTahoe
  theme directory and enables the required custom stylesheet preferences.
- Firefox profiles additionally receive compact density, titlebar drawing,
  accelerated rendering, ARGB visuals, rounded bottom corners, and SVG
  context properties.
- Thunderbird profiles additionally receive `mail.tabs.drawInTitlebar` and
  `browser.tabs.drawInTitlebar`.

The refresh script covers both applications so this work survives new
profiles and app updates.

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

The release archives changed in the same commit because they were regenerated
from the adjusted source.

### Window corner radii

Commit `ea6d8a6b` tightened and preserved the rounded-window treatment:

- `$wm_radius`: 26/24 px → 14/12 px for desktop/laptop profiles.
- `$maximized_radius`: `0` → `$wm_radius`.
- GTK 3 and GTK 4 solid CSD, maximized, fullscreen, and tiled rules now use
  those variables instead of forcing square corners.

### Keyboard behavior

Commits `879157f2` and `468aa1fe` documented Toshy as an optional companion.
Toshy is not installed or configured by this repository. On Wayland it also
needs a supported focused-window GNOME extension; current links and guidance
are maintained in `README.md`.

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
  that breadth.
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

The deployment scripts do not require `sudo`; package installation and the
optional GNOME extensions remain explicit system-level prerequisites.
