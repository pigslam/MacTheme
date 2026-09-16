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
- `rounded-window-maximized.css` keeps Firefox clipped to the theme's 12 px
  window radius when GNOME marks it maximized or tiled, while leaving true
  fullscreen mode unclipped.
- The profile installer copies `customChrome.css` as well as the MacTahoe
  theme directory and enables the required custom stylesheet preferences.
- Firefox profiles additionally receive compact density, titlebar drawing,
  accelerated rendering, ARGB visuals, rounded bottom corners, and SVG
  context properties.
- Thunderbird profiles additionally receive `mail.tabs.drawInTitlebar` and
  `browser.tabs.drawInTitlebar`.

The refresh script covers both applications so this work survives new
profiles and app updates.

#### Firefox maximized and tiled window corners

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
  :root[customtitlebar]:not([inFullscreen], [sizemode="fullscreen"]):is([sizemode="maximized"], [tiled]) body,
  :root[customtitlebar]:not([inFullscreen], [sizemode="fullscreen"]):is([sizemode="maximized"], [tiled]) dialog::backdrop {
    border-radius: 12px !important;
    overflow: clip !important;
  }
}
```

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
