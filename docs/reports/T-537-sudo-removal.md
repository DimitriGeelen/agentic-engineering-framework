# T-537: Remove sudo from installer

## Finding
install.sh used `sudo` to copy `fw` to `/usr/local/bin`. This requires root on Linux and triggers password prompts on macOS. User-space install to `~/.local/bin` is standard practice and avoids privilege escalation.

## Decision: GO — install to ~/.local/bin, remove all sudo calls
