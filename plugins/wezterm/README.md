# TermLink Chrome for WezTerm

Task-aware terminal status bar via TermLink RPC. Shows active TermLink sessions grouped by task ID with role indicators.

## What It Shows

```
                    [T-1063 build] [T-1062 test x2] [3 other]
```

- **Task ID** from session tags (`task:T-XXX`)
- **Session count** per task (when >1)
- **Roles** from session tags (`role:builder`)
- **Non-task sessions** as "N other"

## Install

```bash
# Copy plugin to WezTerm config directory
cp plugins/wezterm/termlink-chrome.lua ~/.config/wezterm/

# Add to your wezterm.lua:
```

```lua
local wezterm = require("wezterm")
local config = wezterm.config_builder()

-- Load TermLink chrome
require("termlink-chrome").apply_to_config(config)

return config
```

## Configuration

```lua
require("termlink-chrome").apply_to_config(config, {
  -- Poll interval in milliseconds (default: 3000)
  update_interval = 5000,

  -- Show status bar even when no TermLink sessions exist
  show_when_empty = false,

  -- Customize colors (Nord theme defaults)
  colors = {
    task_bg = "#4c566a",
    task_fg = "#88c0d0",
    status_bg = "#3b4252",
    status_fg = "#a3be8c",
    role_bg = "#3b4252",
    role_fg = "#b48ead",
  },

  -- Customize icons (requires Nerd Fonts)
  icons = {
    task = "\u{f0ae}",
    session = "\u{f489}",
    role = "\u{f2c2}",
  },
})
```

## How It Works

1. Polls `termlink list --json` every N seconds
2. Groups sessions by `task:T-XXX` tag
3. Displays task IDs with session counts and roles in WezTerm's right status bar
4. Gracefully handles TermLink not running (hides status bar)

## Requirements

- [WezTerm](https://wezfurlong.org/wezterm/) (any recent version)
- [TermLink](https://github.com/DimitriGeelen/termlink) installed and in PATH
- [Nerd Fonts](https://www.nerdfonts.com/) for icons (optional — set icons to empty strings if not available)

## Session Tagging

For sessions to appear grouped by task, tag them when spawning:

```bash
# Via TermLink directly
termlink spawn --name worker-1 --shell --tags "task:T-1063,role:builder"

# Via framework dispatch
fw termlink dispatch --name worker-1 --task T-1063 --prompt "..."
```

The `fw termlink dispatch` command automatically adds the `task:T-XXX` tag.
