# T-536: PyYAML Phantom Dependency

## Finding
`grep -r 'import yaml'` across the entire framework found zero matches. PyYAML was checked by install.sh but never imported by any Python file. PEP 668 on modern Python/macOS blocks `pip install` outside venvs, making this phantom check a hard blocker for new installs.

## Decision: GO — remove the check from install.sh
