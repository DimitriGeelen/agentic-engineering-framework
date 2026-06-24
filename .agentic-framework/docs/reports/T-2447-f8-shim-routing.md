# T-2447 — F8: bare `fw` routes to the global legacy shim, not the consumer-local fw

**Task:** T-2447 · **Type:** inception · **Origin:** T-2441 dogfood finding F8 · **Date:** 2026-06-21
**Question:** Should bare `fw` (run from inside a consumer project, on a host with a global install)
resolve to the **project-local** `.agentic-framework/bin/fw` instead of the global
`~/.local/bin/fw` shim — and if so, how, without re-triggering the T-2099 fork-bomb class?

> Inception artifact (C-001): written while researching. The thinking trail IS the deliverable.

---

## Problem Statement

On a host with a global install, `command -v fw` → `~/.local/bin/fw` (first on PATH), which is a
**symlink to the GLOBAL framework's `bin/fw`** (`/root/.agentic-framework/bin/fw`). So bare `fw` run
from inside a consumer executes the *global* framework's `bin/fw` — specifically its **PROJECT_ROOT /
FRAMEWORK_ROOT resolution logic** (`find_project_root`, `_project_root_is_stale`, the
`CLAUDE_PROJECT_DIR` block) — even when the consumer has its own newer vendored `bin/fw`. This is the
**T-1257 hazard live**: the prompt and much guidance use bare `fw`, which silently runs different code
than `.agentic-framework/bin/fw`.

## Evidence (live, this session + dogfood)

- `ls -la ~/.local/bin/fw` → `lrwxrwxrwx … -> /root/.agentic-framework/bin/fw` (symlink to GLOBAL,
  not a copy, not the consumer's vendored copy).
- `grep -c T-2446 ~/.local/bin/fw` → **0** — the global `bin/fw` **lacks the T-2446 fix** shipped to the
  worktree this session. **Version skew is concrete, not hypothetical.**
- **Mitigation already in place:** `resolve_framework` (bin/fw:117, T-498/T-1346-B1) prefers the
  consumer's `$PROJECT_ROOT/.agentic-framework` for FRAMEWORK_ROOT. So the framework *code* (agents,
  lib) used by bare-fw-in-consumer is still the consumer's vendored copy. **Only the entry-point
  `bin/fw` resolution logic skews** — the surface T-2389/T-2390/T-2391/T-2392/T-2446 keep fixing. A
  consumer with a stale global shim does NOT get those resolution fixes via bare `fw`.
- **SEV-1 prior art (the dominant constraint):** T-2099 — `fw upgrade` from a consumer auto-cloned
  upstream, handed off to the cloned `bin/fw`, which re-resolved back to the consumer's vendored copy
  via the T-498 preference → **infinite recursion → fork bomb**. Fixed by passing an env-scoped
  `FRAMEWORK_ROOT` sentinel (bin/fw:598-606). **Any "re-exec to project-local" fix lives in this exact
  recursion neighbourhood** and must carry an env-sentinel guard.

## Constraints / Invariants any fix MUST preserve

1. **Four invocation modes keep working** (resolve_framework contract): framework-repo-self,
   direct-vendored (`.agentic-framework/bin/fw`), global-from-consumer, global-from-non-project.
2. **No recursion** — must not re-trigger the T-2099 fork-bomb (env-sentinel guard mandatory on any
   re-exec).
3. **`PROJECT_ROOT` / env precedence intact** (T-2391/T-2446) — an explicit `PROJECT_ROOT` still wins.
4. **`upgrade_fresh_machine_simulation.bats` stays green** (consumer-facing command hygiene, T-1633).

## Candidates

### A — Re-exec inside `bin/fw` (entry-point)
Early in `bin/fw`, if cwd-ancestry has a `.agentic-framework/bin/fw` that differs from `$0` and no
re-exec sentinel is set, `exec` it (passing a `FW_REEXEC_GUARD=1` sentinel).
- **Pro:** bare `fw` always runs the consumer's own resolution logic; fixes the defect directly.
- **Con:** mutates the single most delicate, SEV-1-adjacent hot path (5 live-fire incidents +
  T-2099). Startup cost on every invocation. Highest blast radius.

### B — Docs / guidance only
No code change. Enforce the existing §Copy-Pasteable Commands + T-1257 rule (consumer steps use
`.agentic-framework/bin/fw`); fix the T-2441 install prompt to stop using bare `fw` for consumer steps.
- **Pro:** zero resolver risk; policy already exists.
- **Con:** doesn't fix bare-`fw` muscle memory (humans + agents will still type it); the skew stays
  silent.

### C — Thin re-exec shim at install (RECOMMENDED leg)
At `fw init`/`upgrade`, install the PATH shim as a **small dedicated wrapper** (not a symlink to the
308KB global `bin/fw`) that: if cwd-ancestry has `.agentic-framework/bin/fw` AND no sentinel set →
`exec FW_REEXEC_GUARD=1 <project-local fw> "$@"`; else fall through to the global `bin/fw`.
- **Pro:** fixes the defect at the entry point; risk is isolated to a ~20-line shim, NOT bin/fw's hot
  path; env-sentinel pattern is proven (T-2099). Easy to reason about + unit-test in isolation.
- **Con:** changes install/upgrade behaviour (the symlink → wrapper); must cover all 4 modes; a second
  artifact to keep in sync.

### D — WONT-FIX / accept
Document that bare `fw` runs global resolution; rely on T-498 vendored-code preference; fix only the
cosmetic siblings F2/F3.
- **Pro:** zero risk. **Con:** leaves the resolution-logic skew + T-1257 hazard live.

### E — Detection rail (cheap safety net, pairs with C)
A `fw doctor` WARN when the bare-`fw`-resolved shim's version differs from the cwd consumer's vendored
version ("bare fw is stale relative to this project — use `.agentic-framework/bin/fw` or `fw upgrade`").
- **Pro:** surfaces the *silent* skew (the real harm) with zero resolver risk; actionable.
- **Con:** detection, not a fix — users must act.

## Recommendation

**GO — Candidate C (thin re-exec shim with a T-2099-style env-sentinel guard) as the build slice,
shipped together with Candidate E (doctor skew-WARN) as the immediate safety net. Candidates A and D
are rejected; B is folded in as the prompt-text fix.**

**Rationale:**
- The defect is **real and concrete** (global shim lacks T-2446 → bare fw runs stale resolution
  logic), so D (do-nothing) under-serves the T-1257 hazard the operator flagged.
- The operator's own F8 remediation instinct was re-exec — **C delivers that** while isolating the
  recursion risk to a small, independently-testable shim **off** bin/fw's SEV-1 hot path (A puts it
  ON that path — rejected).
- The env-sentinel guard is **proven** (T-2099 already uses env-scoped FRAMEWORK_ROOT for exactly this
  recursion), so the fork-bomb class is preventable by construction.
- **E ships in the same slice** because the real harm is *silent* skew; the WARN closes the gap for
  existing installs (symlink shims already in the wild) that a new wrapper won't retroactively fix.
- **Scope fence:** F2 (legacy messaging) and F3 (`fw --version` → `vdev`) are **sibling findings**, not
  folded here (one inception = one question). They are cheap cosmetic fixes filable separately.

**Build slices the GO authorises (for the spawned build task, not this inception):**
1. Thin shim wrapper + install/upgrade wiring (Candidate C) — env-sentinel guarded.
2. `fw doctor` skew-WARN (Candidate E).
3. T-2441 install-prompt fix to use `.agentic-framework/bin/fw` for consumer steps (Candidate B).
4. `upgrade_fresh_machine_simulation.bats` coverage for all 4 invocation modes + a recursion-guard test.

## Dialogue Log

### 2026-06-21 — scoping (agent-led, pre-decision)
- **Operator:** "scope F8 into an inception."
- **Agent:** filed T-2447 (DEFER seeded), wrote this artifact, grounded the analysis on two live facts
  (symlink-to-global + global-lacks-T-2446) and the T-2099 SEV-1 prior art, converged to GO — Candidate
  C+E. Awaiting operator go/no-go at `/inception/T-2447`.
