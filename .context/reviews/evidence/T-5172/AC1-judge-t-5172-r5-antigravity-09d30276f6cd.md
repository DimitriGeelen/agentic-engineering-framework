# Reviewer evidence — T-5172 AC#1

- dispatch: `judge-t-5172-r5-antigravity-09d30276f6cd`
- worker kind: `antigravity` (vendor `google`, model `worker default`)
- seat: `antigravity`
- reviewed revision: `1c8d7d309699d1539c6b6a7bef1f2ca463b915ae`
- recorded by: the dispatch runtime on the worker's behalf (T-3582)
- result.md sha256: `ccdfde5c15421bb81cf56bb956fdbe448f5cb77a152f8df94ec38ccc080a533f`

## The worker's verdict block

```
1. [AC] [REVIEW] A file in a declared folder opens from a review page
VERDICT: green
WHY: Verified in .framework.yaml (VIEWABLE_DIRS: scripts), web/shared.py (_declared_viewable_dirs + is_viewable_path), and all required screenshots (--evidence .context/working/judge-evidence/T-5172/01-file-scripts-agent-listeners-sh.png, --evidence .context/working/judge-evidence/T-5172/02-config.png, --evidence .context/visual/T-5172/script-file@1024.png, --evidence .context/visual/T-5172/script-file@1440.png, --evidence .context/visual/T-5172/script-file@1920.png): /file/scripts/agent-listeners.sh renders the 232-line bash script with syntax highlighting and line numbers, and at narrower viewports (1024px) long lines scroll sideways inside the code box without widening the page, with zero browser console or page errors.
GUIDANCE: none

Summary: 1 green, 0 amber, 0 red, 0 escalate, 0 not-evaluated
```

## The worker's full output (result.md)

```
### Evidence Report — T-5172 (`1c8d7d309699d1539c6b6a7bef1f2ca463b915ae`)

#### Code & Configuration Verification
- Checked `.framework.yaml` (`VIEWABLE_DIRS: scripts` declared on line 49).
- Checked `web/shared.py` (`_declared_viewable_dirs`, `VIEWABLE_DIR_PREFIXES`, `is_viewable_path`, `_build_artefact_path_re`, `_basename_index`): `VIEWABLE_DIRS` from `FW_VIEWABLE_DIRS` or `.framework.yaml` is sanitized (dropping `..`, absolute paths, `.`, `/`, and `_NEVER_VIEWABLE` prefixes `.git/` and `.context/secrets/`) and appended to `VIEWABLE_DIR_PREFIXES` for both `/file/<path>` and the auto-linker while keeping the `VIEWABLE_EXTENSIONS` filter.
- Checked `tests/unit/test_t5172_viewable_dirs.py` covering default empty setting, env/YAML parsing, unsafe path rejection, duplicate/dot-slash normalization, route + linker behavior, and import-time merge.

#### Rendered Pages & Visual Verification (`--evidence`)
- `--evidence .context/working/judge-evidence/T-5172/01-file-scripts-agent-listeners-sh.png`: `/file/scripts/agent-listeners.sh` renders the full 232-line script with line numbers (`1`–`232`), syntax highlighting (comments, strings/heredocs, shell keywords, variables), and a self-scrolling code container (`overflow-x: auto`). Browser recorded no console or page errors.
- `--evidence .context/working/judge-evidence/T-5172/02-config.png`: `/config` renders cleanly (102 settings, 23 customized, 0 warnings) and displays `FW_VIEWABLE_DIRS` set to `scripts` from `.framework.yaml`. Browser recorded no console or page errors.
- `--evidence .context/visual/T-5172/script-file@1024.png`: At 1024px width, the `script-file` state (`/file/scripts/agent-listeners.sh`) renders all navigation controls, header, line numbers, and syntax-highlighted code box visible, reachable, and without overlap; long lines (lines 124, 198, 228) clip and scroll horizontally inside the code box rather than widening the page.
- `--evidence .context/visual/T-5172/script-file@1440.png`: At 1440px width, the `script-file` state renders cleanly with syntax highlighting, line numbers, and no clipping or overlap.
- `--evidence .context/visual/T-5172/script-file@1920.png`: At 1920px width, the `script-file` state renders cleanly with syntax highlighting, line numbers, and no clipping or overlap.

1. [AC] [REVIEW] A file in a declared folder opens from a review page
VERDICT: green
WHY: Verified in `.framework.yaml` (`VIEWABLE_DIRS: scripts`), `web/shared.py` (`_declared_viewable_dirs` + `is_viewable_path`), and all required screenshots (`--evidence .context/working/judge-evidence/T-5172/01-file-scripts-agent-listeners-sh.png`, `--evidence .context/working/judge-evidence/T-5172/02-config.png`, `--evidence .context/visual/T-5172/script-file@1024.png`, `--evidence .context/visual/T-5172/script-file@1440.png`, `--evidence .context/visual/T-5172/script-file@1920.png`): `/file/scripts/agent-listeners.sh` renders the 232-line bash script with syntax highlighting and line numbers, and at narrower viewports (1024px) long lines scroll sideways inside the code box without widening the page, with zero browser console or page errors.
GUIDANCE: none

Summary: 1 green, 0 amber, 0 red, 0 escalate, 0 not-evaluated
```
