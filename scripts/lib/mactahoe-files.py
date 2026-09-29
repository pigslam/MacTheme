#!/usr/bin/env python3
"""Install bundled assets with per-run backups and preserve local browser CSS."""
import argparse
import configparser
import re
import shutil
import tarfile
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
GTK = ROOT / 'vendor/MacTahoe-gtk-theme'
USER_DIR = Path.home()
backup_root = None


def backup(path):
    global backup_root
    if not path.exists() and not path.is_symlink():
        return
    if backup_root is None:
        parent = USER_DIR / '.local/state/mactheme'
        parent.mkdir(parents=True, exist_ok=True)
        backup_root = Path(tempfile.mkdtemp(prefix='refresh-', dir=parent))
        print(f'Backup: {backup_root}', flush=True)
    # Absolute paths also support Mozilla profiles outside the home directory.
    target = backup_root / str(path.absolute()).lstrip('/')
    target.parent.mkdir(parents=True, exist_ok=True)
    if path.is_dir() and not path.is_symlink():
        shutil.copytree(path, target, symlinks=True)
    else:
        shutil.copy2(path, target, follow_symlinks=False)


def replace_file(path, data):
    if path.is_file() and not path.is_symlink() and path.read_bytes() == data:
        return
    backup(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.is_symlink():
        path.unlink()
    path.write_bytes(data)
    if path.read_bytes() != data:
        raise RuntimeError(f'Failed verification: {path}')


def copy_tree(source, dest):
    # Only bundled files are managed; leave unrelated local files intact.
    for path in sorted(source.rglob('*')):
        if path.is_file():
            replace_file(dest / path.relative_to(source), path.read_bytes())


def themes(args):
    archives = sorted((GTK / 'release').glob('MacTahoe-*.tar.xz'))
    primary = {'MacTahoe-Dark', 'MacTahoe-Light'}
    selected = [p for p in archives if args.all or p.name[:-7] in primary
                or (not args.full and (USER_DIR / '.themes' / p.name[:-7]).is_dir())]
    if not primary.issubset({p.name[:-7] for p in selected}):
        raise RuntimeError('Missing primary GTK release archives')
    with tempfile.TemporaryDirectory(prefix='mactahoe-') as tmp:
        stage = Path(tmp)
        # Validate every selected archive before changing installed files.
        for archive in selected:
            name = archive.name[:-7]
            with tarfile.open(archive) as bundle:
                for member in bundle.getmembers():
                    path = Path(member.name)
                    if path.is_absolute() or '..' in path.parts or path.parts[0] != name:
                        raise RuntimeError(f'Unsafe archive member: {member.name}')
                    if member.isdir():
                        continue
                    if member.issym() and (Path(member.linkname).is_absolute() or ".." in Path(member.linkname).parts):
                        raise RuntimeError(f"Unsafe archive link: {member.name}")
                    if not (member.isfile() or member.issym()):
                        raise RuntimeError(f'Unsupported archive member: {member.name}')
                    target = stage / path
                    target.parent.mkdir(parents=True, exist_ok=True)
                    target.write_bytes(bundle.extractfile(member).read())
            for version in ('gtk-3.0', 'gtk-4.0'):
                for css in ('gtk.css', 'gtk-dark.css'):
                    text = (stage / name / version / css).read_text()
                    selector = 'decoration' if version == 'gtk-3.0' else 'window.csd'
                    if not re.search(re.escape(selector) + r'\s*\{[^}]*border-radius: 12px;', text):
                        raise RuntimeError(f'{name}/{version}/{css}: stale window radius; rebuild releases')
                    if not re.search(r'\.maximized[^{}]*\{[^}]*border-radius: 12px;', text):
                        raise RuntimeError(f'{name}/{version}/{css}: stale maximized radius')
        for archive in selected:
            name = archive.name[:-7]
            dest = USER_DIR / '.themes' / name
            if args.full:
                copy_tree(stage / name, dest)
            else:
                for version in ('gtk-3.0', 'gtk-4.0'):
                    copy_tree(stage / name / version, dest / version)
            print(f'Verified installed GTK theme: {name}')
        if not args.no_libadwaita:
            name = 'MacTahoe-' + args.mode.capitalize()
            copy_tree(stage / name / 'gtk-4.0', USER_DIR / '.config/gtk-4.0')
            print('Verified installed GTK 4 override (including Ghostty corners)')


def profiles(bases):
    found = set()
    for base_text in bases:
        base = Path(base_text)
        ini = base / 'profiles.ini'
        if ini.is_file():
            config = configparser.ConfigParser(interpolation=None)
            config.read(ini)
            for section in config.sections():
                if not section.startswith('Profile') or not config.has_option(section, 'Path'):
                    continue
                value = Path(config.get(section, 'Path'))
                path = base / value if config.get(section, 'IsRelative', fallback='1') == '1' else value
                if path.is_dir():
                    found.add(path.resolve())
        if base.is_dir():
            for path in base.iterdir():
                if path.is_dir() and ('.default' in path.name or path.name.endswith('.dev-edition-default')):
                    found.add(path.resolve())
    for path in sorted(found):
        print(path)


def chrome(args):
    profile = Path(args.profile)
    dest = profile / 'chrome'
    source = GTK / 'other/firefox'
    copy_tree(source / 'MacTahoe', dest / 'MacTahoe')
    replace_file(dest / 'MacTahoe/mactheme-placement.css', (source / 'customChrome.css').read_bytes())
    # Keep user overrides last. Move the bundled placement CSS into our namespace
    # so future refreshes can update it without replacing customChrome.css.
    main = dest / 'userChrome.css'
    text = main.read_text() if main.exists() else ''
    managed = ['firefox-titlebutton-compat.css', 'mactheme-placement.css']
    if args.app == 'firefox':
        managed.insert(1, 'rounded-window-maximized.css')
    for filename in ('firefox-titlebutton-compat.css', 'rounded-window-maximized.css', 'mactheme-placement.css'):
        text = re.sub(r'^[ \t]*@import\s+["\']MacTahoe/' + re.escape(filename)
                      + r'["\'];[ \t]*(?:/\*\*/[ \t]*)?\n?', '', text, flags=re.M)
    custom = dest / 'customChrome.css'
    if not custom.exists():
        replace_file(custom, b'/* Add personal overrides here; MacTahoe preserves this file. */\n')
    if not re.search(r'@import\s+["\']customChrome\.css["\']', text):
        text = '@import "customChrome.css";\n' + text
    imports = ''.join(f'@import "MacTahoe/{name}";\n' for name in managed)
    replace_file(main, (imports + text).encode())
    # Existing userContent.css is personal content styling and is not replaced.
    prefs = profile / 'user.js'
    backup(prefs)
    print(f'Installed {args.app} chrome; preserved personal CSS: {profile}')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='command', required=True)
    theme = sub.add_parser('themes')
    theme.add_argument('--mode', choices=('dark', 'light'), default='dark')
    theme.add_argument('--all', action='store_true')
    theme.add_argument('--full', action='store_true')
    theme.add_argument('--no-libadwaita', action='store_true')
    prof = sub.add_parser('profiles')
    prof.add_argument('bases', nargs='+')
    browser = sub.add_parser('chrome')
    browser.add_argument('--app', choices=('firefox', 'thunderbird'), required=True)
    browser.add_argument('profile')
    args = parser.parse_args()
    if args.command == 'themes':
        themes(args)
    elif args.command == 'profiles':
        profiles(args.bases)
    else:
        chrome(args)


if __name__ == '__main__':
    main()
