"""Make the framework root importable so `from web.app import ...` works."""

import sys
from pathlib import Path

FRAMEWORK_ROOT = Path(__file__).resolve().parents[2]
if str(FRAMEWORK_ROOT) not in sys.path:
    sys.path.insert(0, str(FRAMEWORK_ROOT))
