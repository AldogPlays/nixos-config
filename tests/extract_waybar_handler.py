"""Compile the real patched method without requiring a graphical Waybar session."""
from pathlib import Path
import sys

source = Path(sys.argv[1]).read_text()
start = source.index('void waybar::Bar::handleSignal(int signal) {')
end = source.index('\n}', start) + 2
Path('handler.inc').write_text(source[start:end] + '\n')
