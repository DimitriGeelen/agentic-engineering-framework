# check-visual-verification — Visual Verification Hook

> PreToolUse gate: blocks `git commit` when CSS/HTML is staged but the active
> task has no `## Visual Verification` section with at least one screenshot reference.

## Purpose

DOM measurements (`getBoundingClientRect`, `scrollWidth`) confirm geometry —
they do **not** confirm rendered output. Font hinting, kerning, ellipsis
behaviour, sub-pixel rounding, and contenteditable span spacing can add
3-10 px that DOM math misses entirely. An agent can pass its own measurement
test and still ship a regression visible to any human in 2 seconds.

**Canonical failure case (PL-018, 025-WokrshopDesigner T-489):** agent fixed a
column overflow using `scrollWidth=113 → set width to 110px + ellipsis`. Mono
mode then truncated as "11:00 → …" because mono actually renders ~3-10 px wider
than the serif measurement the agent took. The user caught it on first
inspection. T-490 fixed it properly using element-level Playwright screenshots
in all 3 font modes.

This is a **class** of bug, not a one-off. Any project doing CSS/HTML work is
exposed. The hook enforces the three-layer structure: learning (PL-018) → rule
(CLAUDE.md) → gate (this script).

## What it gates

| Condition | Action |
|-----------|--------|
| Tool is not Bash | Pass-through (exit 0) |
| Command is not `git commit` | Pass-through |
| `--no-verify` present | Pass-through (Tier 2 bypass, logged elsewhere) |
| No staged `.css` or `.html` files | Pass-through |
| No active task in `focus.yaml` | Pass-through |
| Active task has no task file | Pass-through |
| Task has `## Visual Verification` + ≥1 image ref | Allow commit |
| Task has `## Visual Verification` but no image ref | **Block (exit 2)** |
| Task has no `## Visual Verification` section | **Block (exit 2)** |

"Image reference" = any `.png`, `.jpg`, or `.jpeg` occurrence under the section
heading (stops at the next `## ` heading).

## How to enable

This hook is **opt-in** — not enabled by default. Only projects that do CSS/HTML
UI work should enable it.

```bash
fw hook-enable --event PreToolUse --matcher Bash --name check-visual-verification
```

This registers the hook in `.claude/settings.json` using the portable
`fw hook check-visual-verification` format.

## How to satisfy the gate

Add a `## Visual Verification` section to the active task file **with at least
one screenshot path** before committing:

```markdown
## Visual Verification

Screenshots (Playwright browser_take_screenshot, element-level, READ via Read tool)
in every visual mode the change affects:

- mono mode:  screenshots/T-XXX-mono.png   — full time visible, no truncation
- sans mode:  screenshots/T-XXX-sans.png   — full time visible, no overlap
- serif mode: screenshots/T-XXX-serif.png  — full time visible, no overlap
```

The hook checks presence (section exists, image path present) — it does **not**
validate the screenshots are current or correct. That is the agent's
responsibility per `CLAUDE.md § Visual Verification for UI Changes`.

## Bypass

```bash
git commit --no-verify -m "T-XXX: ..."
```

Use only for genuine exceptions:
- Reverting a previous commit
- CSS change is build-artefact only (no rendered output)
- Trivial rename / comment-only change

The `--no-verify` bypass is Tier 2 and is independently logged by the
commit-msg hook.

## Implementation notes

- Located: `agents/context/check-visual-verification.sh`
- Uses `lib/paths.sh` for `PROJECT_ROOT` — works in both framework repo and
  consumer projects (`.agentic-framework/` vendored layout)
- `git diff --cached` runs relative to `PROJECT_ROOT` so cross-directory
  commit workflows are handled correctly
- No external deps beyond `python3` (stdlib json), `git`, `grep`, `awk`

## Origin

Adopted from 025-WokrshopDesigner (commit `2a17876`, task T-494) which
originated the pattern in response to PL-018. Framework adoption: T-2128.
