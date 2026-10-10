#!/usr/bin/env python3
"""Apply the verified Ramon modifier policy without replacing Toshy's config."""
import ast
import datetime
import os
from pathlib import Path
import re
import shutil
import sys
import tempfile

HELPER = '''
def mactheme_is_mx_keys_s(ctx):
    # Ramon's verified MX Keys S policy: Bolt receiver or Bluetooth name.
    name = ctx.device_name.casefold()
    return 'logitech usb receiver' in name or 'mx keys s' in name

'''
CUSTOM = '''
# MacTheme: Ramon's verified physical modifier mapping, scoped to MX Keys S.
# LEFT_META is the physical Alt/Cmd key in this keyboard's current mode.
modmap("MacTheme MX Keys S - Ramon modifiers", {
    Key.LEFT_CTRL: Key.LEFT_CTRL,
    Key.LEFT_ALT:  Key.LEFT_META,
    Key.LEFT_META: Key.RIGHT_CTRL,
}, when = lambda ctx:
    cnfg.screen_has_focus and
    ctx_kbd_is_windows and
    mactheme_is_mx_keys_s(ctx) and
    not ctx_app_is_remote
)

'''

def require(condition, message):
    if not condition:
        raise ValueError(message)


def insert_slice(text, name, content):
    start = f"###  SLICE_MARK_START: {name}"
    end = f"###  SLICE_MARK_END: {name}"
    require(text.count(start) == text.count(end) == 1, f"Missing or ambiguous {name} slice")
    require(text.index(start) < text.index(end), f"Invalid {name} slice")
    return text.replace(end, content + end, 1)


def transform(original):
    text = original
    tree = ast.parse(text)
    helpers = [n for n in tree.body if isinstance(n, ast.FunctionDef) and n.name == 'mactheme_is_mx_keys_s']
    if helpers:
        require(len(helpers) == 1 and ast.dump(helpers[0]) == ast.dump(ast.parse(HELPER).body[0]),
                'Existing MX Keys S helper differs; review manually')
    else:
        text = insert_slice(text, 'user_custom_functions', HELPER)
    for context in ('GUI', 'Terms'):
        for suffix in ('', ' - Cmd held', ' - Opt held'):
            name = f'Cond modmap - {context} - Win kbd{suffix}'
            pattern = rf'^modmap\("{re.escape(name)}", \{{.*?^\)'
            matches = list(re.finditer(pattern, text, re.M | re.S))
            require(len(matches) == 1, f'Missing or ambiguous modmap: {name}')
            match = matches[0]
            block = match.group()
            anchor = '    ctx_kbd_is_windows and\n'
            guard = '    not mactheme_is_mx_keys_s(ctx) and\n'
            require(block.count(anchor) == 1, f'Unrecognized condition: {name}')
            if guard not in block:
                block = block.replace(anchor, anchor + guard)
            text = text[:match.start()] + block + text[match.end():]
    custom_name = 'MacTheme MX Keys S - Ramon modifiers'
    custom_nodes = [n for n in ast.parse(text).body if isinstance(n, ast.Expr)
                    and isinstance(n.value, ast.Call) and n.value.args
                    and isinstance(n.value.args[0], ast.Constant)
                    and n.value.args[0].value == custom_name]
    if custom_nodes:
        require(len(custom_nodes) == 1 and ast.dump(custom_nodes[0]) == ast.dump(ast.parse(CUSTOM).body[0]),
                'Existing Ramon modifier map differs; review manually')
    else:
        text = insert_slice(text, 'user_custom_modmaps', CUSTOM)
    compile(text, '<toshy_config>', 'exec')
    return text


def apply(path):
    original = path.read_text()
    updated = transform(original)
    if updated == original:
        print(f'Ramon MX Keys S mapping already installed: {path}')
        return
    backups = path.with_name(path.name + '.mactheme-backups')
    backups.mkdir(exist_ok=True)
    backup = backups / (path.name + '.' + datetime.datetime.now().strftime('%Y%m%d-%H%M%S-%f'))
    shutil.copy2(path, backup)
    require(backup.read_bytes() == path.read_bytes(), 'Backup verification failed')
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(mode='w', dir=path.parent, prefix='.mactheme-toshy-', delete=False) as stream:
            temporary = Path(stream.name)
            stream.write(updated)
        shutil.copymode(path, temporary)
        os.replace(temporary, path)
    finally:
        if temporary is not None:
            temporary.unlink(missing_ok=True)
    print(f'Applied Ramon MX Keys S mapping: {path}\nBackup: {backup}')


if __name__ == '__main__':
    try:
        apply(Path(sys.argv[1]))
    except (OSError, ValueError, SyntaxError) as exc:
        sys.exit(f'ERROR: {exc}')
