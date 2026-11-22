"""Check evaluated keyboard and Waybar launches against the existing controls."""
import json
from pathlib import Path
import re
import shlex
import sys

bindings = dict(line.split('\t', 1) for line in Path(sys.argv[1]).read_text().splitlines())
bar = json.loads(Path(sys.argv[2]).read_text())['mainBar']
assert bar['visibility-signal'] == 10
assert bar['layer'] == 'top'
assert bar['modes']['invisible'] == {
    'layer': 'bottom', 'exclusive': False, 'passthrough': True, 'visible': False,
}
assert bar['group/app-tray']['drawer']['signal'] == 8
for key, module, app_id, executable in [
    ('SUPER + SHIFT + N', 'network', 'wlctl', 'wlctl'),
    ('SUPER + SHIFT + B', 'bluetooth', 'bluetui', 'bluetui'),
    ('SUPER + SHIFT + A', 'pulseaudio', 'wiremix', 'wiremix'),
    ('SUPER + Escape', 'battery', 'system-monitor', 'btop'),
]:
    command = bindings[key]
    assert command == bar[module]['on-click'], (key, 'launch sites differ')
    args = shlex.split(command)
    assert args[1:3] == ['app', '--']
    assert Path(args[0]).name == 'uwsm'
    assert Path(args[3]).name == 'alacritty'
    assert args[args.index('--class') + 1] == app_id
    assert args[-2] == '-e' and Path(args[-1]).name == executable
    # Store paths make launch dependencies part of the generated configuration closure.
    for path in (args[0], args[3], args[-1]):
        assert path.startswith('/nix/store/') and Path(path).is_file(), path
    options = [args[i + 1] for i, value in enumerate(args) if value == '-o']
    assert 'keyboard.bindings=[{key="Escape",mods="None",action="Quit"}]' in options
    dimensions = [value for value in options if value.startswith('window.dimensions=')]
    assert dimensions == (['window.dimensions={columns=120,lines=36}'] if app_id == 'system-monitor' else [])
    assert re.fullmatch(bindings['float'], app_id)
assert 'keyboard.bindings' not in bindings['SUPER + T']
assert re.fullmatch(bindings['float'], 'theme-switch')
assert not re.fullmatch(bindings['float'], 'Alacritty')
print('PASS: shared keyboard/Waybar launches, dependencies, floating classes and scoped Escape')
