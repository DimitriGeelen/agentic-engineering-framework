# T-1346 — Global `/root/.agentic-framework` install: isolation leak risk & deprecation path

**Type:** inception
**Origin:** User observation 2026-04-20 during fresh install on a system. Install.sh output:
- `[!] Local modifications in /root/.agentic-framework will be overwritten`
- `[+] Updated c5c9b015 → b6ec1ba3`
- `[+] Linked fw → /root/.local/bin/fw (legacy — upgrade for project-local routing)`

User asked: *"what does this mean, what is the full path, are we losing path isolation here?"*

## Problem statement

The framework supports two install modes:
1. **Project-isolated:** `<project>/.agentic-framework/` created by `fw init`. Each consumer project has its own vendored copy; shims route via the project's `bin/fw`.
2. **Global/legacy:** `/root/.agentic-framework/` (or `$HOME/.agentic-framework/`) as a user-scope install. Shim at `~/.local/bin/fw` routes to it.

The installer on this system wrote to the legacy path and emitted a "legacy" warning. This raises two questions:

1. **Isolation correctness:** if a consumer project's shim resolution fails (missing `.agentic-framework/bin/fw`, broken `.framework.yaml`), does `fw` silently fall through to the global install and write to *its* `.context/` / `.tasks/` instead of the consumer's?
2. **Deprecation path:** the installer itself flags the legacy mode, but still installs it. What's the migration story for existing users on legacy paths?

## Evidence from the install output

- `c5c9b015 → b6ec1ba3`: installer updated the global path via git sync. If the admin had hand-edited anything there, those edits are gone. This is the expected install.sh behaviour, but the "will be overwritten" wording is reactive — there's no warning at *install-time* before the edit is lost, just a past-tense note after.
- "Linked fw → /root/.local/bin/fw (legacy)": the symlink is created unconditionally. There's no `--project-local-only` flag to opt out.

## Options (to be evaluated in dialogue)

### Option A — Remove global install entirely
- `install.sh` only supports `fw init <project>` at a target path.
- Existing `/root/.agentic-framework/` gets flagged stale by `fw doctor`.
- **Risk:** breaks cron jobs / systemd units relying on `fw` being on PATH globally.

### Option B — Keep global, harden isolation boundary
- `fw` never falls through from a project to the global install silently. If a project has `.framework.yaml` but the pinned path is broken, *fail*, don't silently use global.
- Add `fw doctor` check: warn if CWD is a git repo without `.agentic-framework/` AND global is being used.
- **Cost:** modest — one resolver change.

### Option C — Keep global as explicit "framework dev" mode
- Global is only for working on the framework itself, not for consumer projects.
- Consumer installs always project-local.
- Document clearly; `install.sh` refuses to install global unless `--framework-dev`.

## Assumptions to validate

- **A1: CONFIRMED ISOLATION LEAK.** `bin/fw` line 57 resolves `$0` via `readlink -f`, which follows symlinks. When a user invokes bare `fw` in a consumer project:
  - Shell resolves `fw` → `~/.local/bin/fw` (PATH hit) → `/root/.agentic-framework/bin/fw` (readlink -f)
  - `FW_BIN_DIR=/root/.agentic-framework/bin`
  - `resolve_framework` rule 1 (fw-inside-framework-repo): `candidate=/root/.agentic-framework` → has `FRAMEWORK.md` → **returns global**
  - Rule 2 (project-vendored `.agentic-framework/`) never evaluated
  - Effect: vendored framework in the consumer project is bypassed. Global framework code runs against `PROJECT_ROOT=<consumer>`. Version drift between vendored pin and global is invisible.
- A2: How many consumer projects on this machine have vendored frameworks that silently aren't being used? (`find /opt -maxdepth 3 -name '.agentic-framework' -type d` → compare counts of vendored installs vs. projects where bare `fw` resolves to global)
- A3: Does the Homebrew-installed `fw` (for developers on macOS) exhibit the same leak, or does brew's bin layout accidentally protect it? (Cellar-path special-case at bin/fw:82-90 suggests yes-same-class-of-issue)

## Recommendation

**Draft GO — Option B++ (harden resolution order + explicit opt-in for global).** Reasons:

1. **The leak is silent and the user cannot detect it.** There's no indicator that `fw version` in a project is the vendored or global binary. Developers believe they have isolation when they don't.
2. **Rule-order flip is the minimum fix.** Move "project-vendored" above "fw-inside-framework-repo" in `resolve_framework`. Effect: in a consumer project with a vendored framework, vendored wins even when invoked via global symlink.
3. **Add a loud mode signal.** `fw doctor` should emit one line: `Framework: vendored (v1.5.30)` or `Framework: global → /root/.agentic-framework (LEAK — vendored at <project>/.agentic-framework/ was bypassed)`.
4. **Preserve both modes.** Global is legitimate for framework self-development and for one-off `fw init` bootstrapping. Removing it is Option A — more disruptive, same correctness gain as Option B once the leak is fixed.
5. **Detection over mitigation (G-019).** Flipping rule order is mitigation; the detection piece is `fw doctor` warning when the active mode does not match the declared mode (project has vendored but global is in use).

**Decomposition for build:**
- **B1:** Flip rule order in `bin/fw:resolve_framework` — vendored before fw-inside-framework-repo when `$PROJECT_ROOT/.agentic-framework/FRAMEWORK.md` exists. Add test fixture that asserts a vendored project resolves to its own vendored framework when invoked via global symlink.
- **B2:** Add mode signal to `fw doctor` and `fw version` — show which framework copy is active and where it came from.
- **B3:** `install.sh` pre-install warning: list any projects on the machine that have vendored frameworks; confirm before linking the legacy global shim.

B1 should land first (correctness); B2/B3 are usability.

## Dialogue log

### 2026-04-20 — Initial observation
**User:** Fresh install on a system showed "Local modifications will be overwritten" and "legacy" linking. Asked what this means, what the path is, and whether path isolation is compromised.

**Agent:** Explained the global vs. project-isolated distinction; clarified that the warning is legitimate (installer does a destructive sync) and that path isolation is not compromised *in the normal case* (projects with their own `.agentic-framework/` take precedence). Flagged one residual risk: if a project's shim resolution breaks, `fw` may silently fall through to global — that needs inspection (A1 above).

### 2026-04-20 — A1 confirmation (code inspection)
**Finding:** A1 is worse than a fallback — it's the *default path*. `bin/fw:57` uses `readlink -f "$0"` to resolve the symlink. `resolve_framework` rule 1 then matches the global install before rule 2 has a chance to detect the vendored install. Every bare `fw` invocation in a consumer project uses global code against consumer state. The user's question "are we losing path isolation here" has the answer: **yes, for code; no, for state.** State isolation holds (PROJECT_ROOT is resolved from CWD correctly); code isolation does not (FRAMEWORK_ROOT always wins via symlink).

## Dialogue log

### 2026-04-20 — Initial observation
**User:** Fresh install on a system showed "Local modifications will be overwritten" and "legacy" linking. Asked what this means, what the path is, and whether path isolation is compromised.

**Agent:** Explained the global vs. project-isolated distinction; clarified that the warning is legitimate (installer does a destructive sync) and that path isolation is not compromised *in the normal case* (projects with their own `.agentic-framework/` take precedence). Flagged one residual risk: if a project's shim resolution breaks, `fw` may silently fall through to global — that needs inspection (A1 above).
