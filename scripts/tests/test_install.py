#!/usr/bin/env python3
"""Integration checks in disposable homes; desktop commands are stubbed."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]


class InstallTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.base = Path(self.tmp.name)
        self.user = self.base / 'home'
        self.user.mkdir()
        self.bin = self.base / 'bin'
        self.bin.mkdir()
        self.calls = self.base / 'desktop-calls'
        self.env = dict(os.environ, HOME=str(self.user), PATH=str(self.bin) + ':' + os.environ['PATH'],
                        TEST_CALLS=str(self.calls), XDG_CONFIG_HOME=str(self.user / '.config'),
                        XDG_DATA_HOME=str(self.user / '.local/share'))
        self.stub('gsettings', '''printf '%s\\n' "$*" >> "$TEST_CALLS"
case "$*" in *writable*) echo true;; esac
''')
        self.stub('gnome-extensions', '''printf '%s\\n' "$*" >> "$TEST_CALLS"
case "$1" in list) echo moveclock@kuvaus.org;; esac
''')
        self.stub('flatpak', 'exit 1\n')

    def stub(self, name, body):
        path = self.bin / name
        path.write_text('#!/bin/bash\n' + body)
        path.chmod(0o755)

    def run_cmd(self, *args):
        result = subprocess.run(args, env=self.env, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        self.assertEqual(result.returncode, 0, result.stdout)
        return result.stdout

    def write(self, relative, content):
        path = self.user / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content)
        return path

    def refresh(self, *args):
        return self.run_cmd('bash', str(ROOT / 'scripts/refresh-mactahoe-profiles.sh'), *args)

    def test_stale_themes_and_repeat_refresh(self):
        css = self.write('.config/gtk-4.0/gtk.css', 'old square theme\n')
        settings = self.write('.config/gtk-4.0/settings.ini', '[Settings]\ngtk-enable-animations=false\n')
        self.write('.themes/MacTahoe-Dark/gtk-3.0/gtk.css', 'old 24px theme\n')
        self.refresh('--no-firefox', '--no-thunderbird', '--no-flatpak', '--no-desktop')
        self.assertIn('window.csd.maximized, window.csd.fullscreen {\n  border-radius: 12px;', css.read_text())
        self.assertIn('gtk-enable-animations=false', settings.read_text())
        before = css.read_bytes()
        backups = list((self.user / '.local/state/mactheme').glob('refresh-*'))
        self.assertEqual(len(backups), 1)
        self.assertTrue(any(p.read_text() == 'old square theme\n' for p in backups[0].rglob('gtk.css')))
        self.refresh('--no-firefox', '--no-thunderbird', '--no-flatpak', '--no-desktop')
        self.assertEqual(css.read_bytes(), before)
        self.assertEqual(list((self.user / '.local/state/mactheme').glob('refresh-*')), backups)
        self.assertFalse(self.calls.exists() and any(line.startswith(('set ', 'enable ', 'disable ')) for line in self.calls.read_text().splitlines()))

    def test_named_profiles_and_personal_css(self):
        profile = self.user / '.config/mozilla/firefox/named work'
        chrome = profile / 'chrome'
        chrome.mkdir(parents=True)
        self.write('.config/mozilla/firefox/profiles.ini', '[Profile0]\nName=Work\nIsRelative=1\nPath=named work\n')
        (chrome / 'userChrome.css').write_text('@import "MacTahoe/firefox-titlebutton-compat.css"; #inline-personal {color:blue;}\n@namespace url("http://www.mozilla.org/keymaster/gatekeeper/there.is.only.xul");\n#personal {color:red;}\n')
        (chrome / 'customChrome.css').write_text('/* my custom CSS */\n')
        (chrome / 'userContent.css').write_text('/* my content CSS */\n')
        (profile / 'user.js').write_text('user_pref("personal.setting", true);\n')
        thunder = self.user / '.thunderbird/a.default'
        thunder.mkdir(parents=True)
        flags = ('--no-theme-files', '--no-gtk', '--no-flatpak', '--no-desktop')
        self.refresh(*flags)
        first = (chrome / 'userChrome.css').read_text()
        self.refresh(*flags)
        self.assertEqual((chrome / 'userChrome.css').read_text(), first)
        self.assertIn('#personal {color:red;}', first)
        self.assertIn('#inline-personal {color:blue;}', first)
        self.assertEqual(first.count('@import "MacTahoe/rounded-window-maximized.css";'), 1)
        self.assertEqual((chrome / 'customChrome.css').read_text(), '/* my custom CSS */\n')
        self.assertEqual((chrome / 'userContent.css').read_text(), '/* my content CSS */\n')
        self.assertIn('personal.setting', (profile / 'user.js').read_text())
        self.assertEqual((profile / 'user.js').read_text().count('widget.gtk.rounded-bottom-corners.enabled'), 1)
        self.assertTrue((thunder / 'chrome/customChrome.css').exists())
        self.assertNotIn('rounded-window-maximized', (thunder / 'chrome/userChrome.css').read_text())
        self.assertFalse((self.user / '.themes').exists())

    def test_light_and_no_libadwaita(self):
        css = self.write('.config/gtk-4.0/gtk.css', 'personal override')
        self.refresh('--mode', 'light', '--no-libadwaita', '--no-firefox', '--no-thunderbird', '--no-flatpak', '--no-desktop')
        self.assertEqual(css.read_text(), 'personal override')
        self.assertIn('gtk-theme-name=MacTahoe-Light', (css.parent / 'settings.ini').read_text())
        self.refresh('--mode', 'light', '--no-firefox', '--no-thunderbird', '--no-flatpak', '--no-desktop')
        self.assertEqual(css.read_bytes(), (self.user / '.themes/MacTahoe-Light/gtk-4.0/gtk.css').read_bytes())

    def test_desktop_settings(self):
        self.write('.local/share/gnome-shell/extensions/appindicatorsupport@rgcjonas.gmail.com/schemas/gschemas.compiled', '')
        self.refresh('--no-theme-files', '--no-gtk', '--no-firefox', '--no-thunderbird', '--no-flatpak')
        calls = self.calls.read_text()
        self.assertIn('compact-mode-enabled false', calls)
        self.assertIn('--schemadir ' + str(self.user / '.local/share/gnome-shell/extensions/appindicatorsupport@rgcjonas.gmail.com/schemas'), calls)
        self.assertIn('clock-before-statusmenu false', calls)
        self.assertIn('show-apps-at-top true', calls)
        self.assertIn('enable moveclock@kuvaus.org', calls)

    def test_missing_and_locked_extensions(self):
        self.stub('gsettings', 'printf "%s\\n" "$*" >> "$TEST_CALLS"; exit 1\n')
        self.stub('gnome-extensions', 'exit 0\n')
        flags = ('--no-theme-files', '--no-gtk', '--no-firefox', '--no-thunderbird', '--no-flatpak')
        self.assertIn('is not installed', self.refresh(*flags))
        self.assertNotIn('set ', self.calls.read_text())
        self.calls.unlink()
        self.stub('gsettings', 'printf "%s\\n" "$*" >> "$TEST_CALLS"; echo false\n')
        self.assertIn('is locked', self.refresh(*flags))
        self.assertNotIn('set ', self.calls.read_text())

    def test_external_profile(self):
        external = self.base / 'external profile'
        external.mkdir()
        self.write('.mozilla/firefox/profiles.ini', '[Profile0]\nIsRelative=0\nPath=' + str(external) + '\n')
        self.refresh('--no-theme-files', '--no-gtk', '--no-desktop', '--no-thunderbird', '--no-flatpak')
        self.assertTrue((external / 'chrome/MacTahoe/rounded-window-maximized.css').exists())

    def test_setup_summary_and_opt_out(self):
        flags = ('--no-theme-files', '--no-gtk', '--no-desktop', '--no-firefox', '--no-thunderbird', '--no-flatpak')
        self.stub('git', 'echo unexpected-network-access >&2; exit 99\n')
        output = self.refresh(*flags)
        self.assertIn('Move Clock         [enabled]', output)
        self.assertIn('User Themes', output)
        self.assertIn('--install-toshy', output)
        self.assertIn('configure-toshy-mx-keys-s.sh', output)
        self.assertNotIn('unexpected-network-access', output)
        self.assertNotIn('Next steps', self.refresh(*flags, '--no-summary'))
        self.stub('gnome-extensions', 'exit 1\n')
        self.assertIn('status unavailable outside a GNOME session', self.refresh(*flags))
        self.env['XDG_CONFIG_HOME'] = str(self.user / '.config')
        self.write('.config/toshy/toshy_config.py', '# already configured\n')
        self.assertIn('Existing Toshy configuration found', self.refresh(*flags))

    def test_explicit_toshy_install_and_failure(self):
        self.env['XDG_DATA_HOME'] = str(self.user / '.local/share')
        self.stub('git', """dest="${@: -1}"
cat > "$dest/setup_toshy.py" <<'MOCK'
import os, sys
from pathlib import Path
assert sys.argv[1:] == ['install']
Path(os.environ['TEST_CALLS']).write_text('mock Toshy install')
MOCK
""")
        flags = ('--no-theme-files', '--no-gtk', '--no-desktop', '--no-firefox', '--no-thunderbird', '--no-flatpak', '--install-toshy', '--no-summary')
        self.assertIn('Toshy installer finished', self.refresh(*flags))
        self.assertEqual(self.calls.read_text(), 'mock Toshy install')
        self.stub('git', 'exit 23\n')
        result = subprocess.run(['bash', str(ROOT / 'scripts/refresh-mactahoe-profiles.sh'), *flags],
                                env=self.env, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        self.assertEqual(result.returncode, 23)
        self.assertIn('Theme setup completed, but Toshy installation did not finish', result.stdout)

    def test_full_deploy_no_apply(self):
        # Exercise the real deploy orchestration, stubbing only icon/cursor installers.
        repo = self.base / 'repo'
        shutil.copytree(ROOT / 'scripts', repo / 'scripts', ignore=shutil.ignore_patterns('__pycache__'))
        vendor = repo / 'vendor'
        vendor.mkdir()
        (vendor / 'MacTahoe-gtk-theme').symlink_to(ROOT / 'vendor/MacTahoe-gtk-theme', target_is_directory=True)
        icons = vendor / 'MacTahoe-icon-theme'
        (icons / 'cursors').mkdir(parents=True)
        for path in (icons / 'install.sh', icons / 'cursors/install.sh'):
            path.write_text('#!/bin/bash\nexit 0\n')
        output = self.run_cmd('bash', str(repo / 'scripts/deploy-mactahoe.sh'), '--no-apply', '--no-libadwaita', '--no-flatpak')
        self.assertEqual(output.count('Next steps — extensions and keyboard shortcuts'), 1)
        self.assertFalse(self.calls.exists() and any(line.startswith(('set ', 'enable ', 'disable ')) for line in self.calls.read_text().splitlines()))
        self.assertFalse((self.user / '.config/gtk-4.0/gtk.css').exists())
        shell = self.user / '.themes/MacTahoe-Dark/gnome-shell/gnome-shell.css'
        self.assertEqual(shell.read_text().count('/* MacTheme solid top bar override */'), 1)


if __name__ == '__main__':
    unittest.main()
