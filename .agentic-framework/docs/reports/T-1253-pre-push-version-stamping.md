# T-1253 — Pre-push hook VERSION-stamping breaks version.json-based projects

**Task:** T-1253
**Type:** Inception (research artifact per C-001)
**Created:** 2026-04-14
**Reporter:** .109 cross-agent (ring20-management) for T-106 blocker

## Problem

The framework's `pre-push` hook contains a VERSION-stamping block introduced in T-648:

```sh
_version=$(git describe --tags --match 'v[0-9]*')   # → "v3.1.0-alpha-5-gabc123"
# parse to "3.1.5"-ish
echo "$_stamped" > "$PROJECT_ROOT/VERSION"
echo "$_stamped" > "$PROJECT_ROOT/.agentic-framework/VERSION"
```

Every `git push` overwrites both VERSION files based on `git describe`, which assumes
projects version via git tags. Consumer projects using `version.json`-based
versioning (e.g., ring20-management, Odoo-style configs) have their manually bumped
versions silently reverted.

Example from .109: `version.json` bumped to `3.2.9-alpha`, then pushed, VERSION
rewritten to `3.1.alpha` (latest matching git tag).

## T-106 context

- AC #1 (audit-script fallback to .agentic-framework/) — shipped (G-PREPUSH-T498-REGRESSION)
- AC #2 (re-install produces a working hook) — **blocked**: the broken template lives
  in the global `/root/.agentic-framework/`. The global `fw` symlink points there, so
  `fw git install-hooks` reinstalls the same template. Fixing globally crosses project
  boundary and needs Tier 2.

The deeper issue: the stamping block assumes git-tag versioning — it's simply wrong
behavior for version.json-based projects. Fixing the audit path doesn't address this.

## Spikes

### Spike A — Locate and confirm stamping block — DONE

Block is at `agents/git/lib/hooks.sh:385-403`:

```sh
# Stamp VERSION file from git describe (T-648: git-derived versioning)
_version=$(git describe --tags --match 'v[0-9]*' 2>/dev/null) || true
if [ -n "$_version" ]; then
    _version="${_version#v}"
    if [[ "$_version" == *-*-* ]]; then
        _base="${_version%%-*}"
        _rest="${_version#*-}"
        _commits="${_rest%%-*}"
        _major_minor="${_base%.*}"
        _stamped="${_major_minor}.${_commits}"
    else
        _stamped="$_version"
    fi
    echo "$_stamped" > "$PROJECT_ROOT/VERSION"
    if [ -d "$PROJECT_ROOT/.agentic-framework" ]; then
        echo "$_stamped" > "$PROJECT_ROOT/.agentic-framework/VERSION"
    fi
    echo "VERSION stamped: $_stamped"
fi
```

Unconditional — runs whenever `git describe` returns anything. No check for
alternative versioning schemes. Writes to both VERSION and .agentic-framework/VERSION.

### Spike B — Version.json detection at hook-time — DONE

Detection signals (in priority order):
1. `$PROJECT_ROOT/.framework.yaml` contains `version_stamping: off` → explicit opt-out
2. `$PROJECT_ROOT/version.json` exists → version.json-based
3. `$PROJECT_ROOT/package.json` contains top-level `"version":` → npm-based
4. `$PROJECT_ROOT/pyproject.toml` contains `version = "..."` → Python project
5. None of the above → git-derived versioning is appropriate

Real-world evidence from a local consumer:
- `/opt/050-email-archive/version.json`: `{"version": "0.17.3"}` (authoritative per project)
- `/opt/050-email-archive/VERSION`: `0.12.1055` (stamped by hook from `v0.12.0-1055-g…`)
- git describe: `v0.12.0-1067-g74d383eb` (latest matching tag is v0.12.0)
- `git tag -l 'v*'`: one tag, `v0.12.0`

Gap of 5 minor versions — VERSION stamp is 5 versions behind the real project version.

### Spike C — Fix-path evaluation — DONE

Four paths scored against the four constitutional directives:

| Path | Antifragility | Reliability | Usability | Portability |
|------|:-------------:|:-----------:|:---------:|:-----------:|
| 1 — Opt-in flag in `.framework.yaml` | = | = | − (requires config) | + |
| 2 — Auto-detect alternative schemes | + | + | ++ | ++ |
| 3 — Remove stamping entirely | − | − | + | − |
| 4 — Hybrid: auto-detect + opt-in override | + | + | + | ++ |

**Path 1 (opt-in)** — Bad default. Every consumer using version.json must know about
the flag; defaults to buggy behavior. Rejected.

**Path 2 (auto-detect)** — Skip stamping when version.json/package.json/pyproject.toml
has a version. Fallback to git-derived when none present. Works out-of-the-box for
both ecosystems. **Recommended.**

**Path 3 (remove entirely)** — Regression for T-648 users who rely on git-derived
VERSION. Breaks .agentic-framework/VERSION sync. Rejected.

**Path 4 (hybrid)** — Path 2 plus a `.framework.yaml` escape hatch. Overkill unless
an edge case emerges. Keep in reserve.

## Findings

1. The stamping block is unconditional and assumes git-tag versioning is the only scheme
2. Real consumers in the /opt tree already demonstrate the bug (050-email-archive)
3. Detection is mechanical and cheap — file existence + grep for `version` key
4. Path 2 (auto-detect) scores best across all four directives

## Recommendation

**Recommendation:** GO

**Rationale:** Path 2 (auto-detect version.json / package.json / pyproject.toml)
scores best on Usability and Portability with no regression for git-tag users.
The fix is bounded (modify the stamping block in `agents/git/lib/hooks.sh` plus
the installed copy in `.git/hooks/pre-push`), testable (add unit tests for each
detection path), and reversible (behind a possible `.framework.yaml` escape hatch
later if edge cases appear).

**Evidence:**
- Stamping block isolated to ~20 lines in one file
- Detection signals are deterministic and fast (file existence + 1-line grep)
- Example bug concretely demonstrated in /opt/050-email-archive
- No competing inception or task addresses this

**Build follow-up (after GO):**
- Create `T-1254-build: implement version-scheme detection in pre-push stamping block`
- Ship in framework template; propagate to consumers via `fw upgrade`
- Add bats test coverage for each detection branch

## Dialogue Log

### 2026-04-14 — Live reproduction of auth-rot (related concern)

While working on this inception, peer review attempts from .121 and .109 via
TermLink all failed due to stale hub secrets:
- .107 framework-agent: up, 0 sessions registered (resolved: registered tl-4zyplaci this session)
- .109 ring20-manager: 10s TCP timeout
- .121 ring20-dashboard: connection refused

Inject, file_send, and inbox primitives all require live targets. No queue-for-absent-session.
This is a clean reproduction of the auth-rot problem — and it actively prevented the
peer review of this inception. Not blocking T-1253 GO decision, but worth its own
inception (follow-up).

### 2026-04-14 — Cross-agent report from .109

`.109` reported the T-106 blocker via cross-agent TermLink channel:

> Every git push overwrites both VERSION files based on git describe — which assumes
> projects version via git tags. This project versions via version.json, so the two
> systems fight. Latest matching tag is something around v3.1.0-alpha, so VERSION
> gets rewritten to 3.1.alpha every push even after we bump version.json to 3.2.9-alpha.

Paths forward listed by .109:
1. `fw upgrade` — may pull a fixed template from upstream
2. Strip the VERSION-stamping block from `.git/hooks/pre-push` locally
3. Patch the global `/root/.agentic-framework/` with Tier 2 authorization
4. Upstream fix: make the stamping block honor version.json when present

This inception explores path (4) — the upstream fix — as the sustainable solution.
Paths (2) and (3) are tactical workarounds; path (1) only helps once (4) ships.
