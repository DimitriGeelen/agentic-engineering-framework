---
id: T-2896
name: "Watchtower secret key is gitignored in the framework but not in the consumer gitignores the framework writes"
description: >
  Watchtower secret key is gitignored in the framework but not in the consumer gitignores the framework writes

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: []
components: []
related_tasks: []
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
# demo_target: true               # T-2286: optional — marks task as reserved for an orchestrated demo
#                                 # worker (e.g. arc-010 HM-A dispatches via mcp__fw__work_on). When set,
#                                 # `fw work-on T-XXX` refuses unless --i-am-demo-orchestrator (CLI) or
#                                 # FW_I_AM_DEMO_ORCHESTRATOR=1 (env) is passed. Prevents the parent
#                                 # session from consuming the captured→started-work transition the demo
#                                 # worker expects to drive. Origin OBS-057.
created: 2026-08-09T11:40:00Z
last_update: 2026-08-09T11:40:00Z
date_finished: null
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
# ── BVP scoring fields (T-1918, arc-006). See docs/reports/T-1915-bvp-inception.md for semantics. ──
# bvp_scores:                     # confirmed per-driver scores 0-5, set by `fw bvp confirm` (T-1924).
#                                 # Sovereignty boundary — only set after human or agent confirmation.
#                                 # Shape: {D1: <int 0-5>, D2: <int 0-5>, D3: <int 0-5>, D4: <int 0-5>, [<free-driver-id>: <int>]...}
# bvp_scores_proposed:            # estimator-proposed scores (T-1922 worker). Persists when ≥2 delta
#                                 # from bvp_scores: on any driver (M3 v2-delta). Shape: list of timestamped entries.
# cost_estimate:                  # F8 composite: 0.6×blast_radius + 0.3×tier + 0.1×effort.
#                                 # Q2 fallback: T-shirt S/M/L/XL mapped to 2/4/6/8 when blast_radius is not yet computable.
---

# T-2896: Watchtower secret key is gitignored in the framework but not in the consumer gitignores the framework writes

## Context

`web/app.py:_resolve_secret_key` generates `PROJECT_ROOT/.context/working/.fw-secret-key`
(`secrets.token_hex(32)`, chmod 0600) on first Watchtower start when `FW_SECRET_KEY` is
unset. That key signs the `fw_session_<port>` cookie and the CSRF token inside it — the
gate in front of the T-2277 sovereignty surface (`/tasks/<id>/update` AC ticks,
`/inception/<id>/decide`, `/gaps/<id>/close`, `/approvals/<id>/<action>`).

**This repo is not exposed** — `.gitignore:48` carries the path and `git log --all` over
the pathspec is empty, so it was never tracked here. The defect is that the framework
protected itself and never propagated the protection to the projects it generates:

| gitignore the framework WRITES | written by | covers the key? |
|---|---|---|
| `<consumer>/.context/working/.gitignore` | `lib/init.sh:266` (`fw init`) | **no** |
| `<consumer>/.agentic-framework/.gitignore` | `bin/fw:534` (`fw vendor`) | **no** |
| `<this repo>/.gitignore:48` | by hand | yes |

chmod 0600 is a filesystem control and says nothing to git. So every project created by
`fw init` publishes its Watchtower signing key the moment it commits `.context/working/`
— which is not an exotic configuration, it is what the working-memory design encourages.

Reported by 832 at rail 498 from their own tree: tracked for two months from 2026-06-04,
pushed to origin and to their GitHub mirror, key on disk byte-identical to the committed
blob, live cookie issued from it, and `[PASS] Secret scan: tracked tree clean` in every
audit across the window. L-518 sweep: our repo is clean, our *generators* are not.

Scope fence: this task fixes the two generators and pins them. Remediating already-exposed
consumer projects is **not** in scope and not reachable from here — the T-559 boundary gate
refused the cross-project sweep (correct). That is the Human AC below.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] `lib/init.sh` writes a `.context/working/.gitignore` that ignores `.fw-secret-key`
- [x] `bin/fw` writes a vendored `.gitignore` that ignores `.fw-secret-key`
- [x] Both patterns are **unanchored** (no leading slash, no embedded `/`), so they cover a
      key at any depth — including the second copy under `.agentic-framework/.context/working/`
      that a path-anchored rule would miss (832 held exactly two, one per depth)
- [x] Tests pin the ignore **behaviourally** via `git check-ignore` against a real temp repo
      at both depths — not by grepping the emitted text, which passes on a pattern that
      does not actually match
- [x] Test asserts a *positive control*: the same probe reports NOT-ignored before the
      rule is present, so a green result cannot come from a broken probe
- [x] `git ls-files | grep fw-secret-key` stays empty in this repo

### Human
<!-- Criteria requiring human verification (UI/UX, subjective quality). Not blocking.
     Remove this section if all criteria are agent-verifiable.
     Each criterion MUST include Steps/Expected/If-not so the human can act without guessing.

     ── Prefix routing (T-1811, T-1878): default to [REVIEWER] if Expected is grep-able ──
     If your Expected clause is grep-able / file-exists / structural (a deterministic
     shell check), prefer [REVIEWER] — that AC should be an Agent AC with the reviewer
     command in `## Verification` instead of a Human AC here. Only keep [REVIEW] if
     verification genuinely needs human taste (tone, feel, layout rhythm).
     See CLAUDE.md §AC Classification Guidance for the conversion rule.

     [REVIEW] example (genuine human judgment):
       - [ ] [REVIEW] Dashboard renders correctly
         **Steps:**
         1. Open https://example.com/dashboard in browser
         2. Verify all panels load within 2 seconds
         3. Check browser console for errors
         **Expected:** All panels visible, no console errors
         **If not:** Screenshot the broken panel and note the console error

     [REVIEWER] example (static-scan-verifiable — convert to Agent AC + Verification):
       - [ ] [REVIEWER] Block message names both bypass mechanisms
         **Steps:**
         1. Run `bin/fw reviewer T-XXX`
         **Expected:** Verdict: PASS; no findings on `block-message-completeness`
         **If not:** Inspect hook block-message string and add missing mechanism
       Conversion: this AC should be moved to ### Agent and
       `bin/fw reviewer T-XXX 2>&1 | grep -q "Overall:.*PASS"` added to ## Verification.
-->

- [ ] [REVIEW] Decide whether already-created consumer projects need their signing key rotated

  This fix stops the *next* project from leaking. It does nothing for projects already
  created — their `.gitignore` was written before the fix and will not change on upgrade.
  832 counted nine Watchtowers on this host at T-2277; each is a separate PROJECT_ROOT with
  its own key. The agent cannot check them: the T-559 boundary gate refuses the sweep, and
  it is right to — cross-project remediation is yours.

  **Steps:**
  1. For each project you run a Watchtower in, check whether the key is published:
     `cd /path/to/project && git ls-files | grep fw-secret-key`
  2. For any project where that prints a path, **rotate first, untrack second** — in that order:
     `cd /path/to/project && rm -f .context/working/.fw-secret-key && .agentic-framework/bin/fw watchtower restart && git rm --cached .context/working/.fw-secret-key`
  3. Add the ignore rule to that project's own `.gitignore` (the framework will not retrofit it):
     `cd /path/to/project && echo '.fw-secret-key' >> .gitignore && git add .gitignore && git commit -m "T-2896: ignore + rotate published Watchtower signing key"`

  **Expected:** step 1 prints nothing for every project. Where it printed a path, after
  step 2 the on-disk key differs from the published blob, so the published one signs nothing.

  **If not:** `git rm --cached` alone is **not** a fix — it produces a repo that looks clean
  while the old key stays readable in history and in every existing clone, and still signs
  live cookies until rotation. If a key reached a public mirror, history rewrite is
  defence-in-depth *after* rotation, never instead of it — and it is Tier 0, so it comes
  back to you as a separate decision.

## Verification

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# The completion gate runs each command — if any exits non-zero, completion is blocked.
#
# Toolchain hint (L-291): if you edited *.vbproj/*.csproj/*.xaml add `dotnet build`;
# *.go → `go build ./...`; Cargo.toml → `cargo check`; tsconfig.json → `tsc --noEmit`;
# pom.xml → `mvn -q compile`. P-011 runs only what you write — broken builds slip
# past otherwise (origin: 003-NTB-ATC-Plugin T-077, broken WPF DLL on master 5 days).
#
# Pipefail/SIGPIPE hint (L-387): P-011 runs each command under `set -eo pipefail`.
# `cmd | grep -q PATTERN` exits 141 (SIGPIPE) when grep matches and closes stdin
# while the upstream is still writing — verification then "fails" even though
# the pattern was present. Safe pattern: capture first, grep the capture:
#     out=$(cmd 2>&1); echo "$out" | grep -q "PATTERN"
# Or:
#     cmd > /tmp/.out 2>&1 && grep -q "PATTERN" /tmp/.out
# Origin: L-387, captured 4× (T-1716, T-1838, T-1862, T-1863) before this hint.
#
# Single pipe only — no intermediate tail/awk/sed stages between capture and grep
# (T-2090): `echo "$out" | tail -3 | grep -q PAT` re-introduces the SIGPIPE risk
# the capture step closed off — the middle stage is what `grep -q` slams its
# stdin on. grep scans the whole captured string anyway, so the tail-3 was
# cosmetic. Drop it: `echo "$out" | grep -q PAT`.
#
# AND ONLY WHILE THE CAPTURE IS SMALL (T-2743). The two hints above are correct
# for the captures they were written about, and both invert above the pipe
# buffer. `echo "$out" | grep -q PAT` is NOT SIGPIPE-free — it is SIGPIPE-free
# only while "$out" fits in the 65536-byte pipe buffer. Above that, with an
# early match: echo blocks on the full pipe, grep -q exits, echo takes SIGPIPE,
# pipeline exits 141 under pipefail — the exact failure L-387 exists to prevent.
# Measured: a Watchtower page is 146,366 bytes, rc=141 on 3/3 runs, deterministic
# not racy. Any line that curls a rendered page is exposed (routes run 50-200KB).
# For anything that might be large, redirect to a file:
#     cmd -o /tmp/.out && grep -q "PATTERN" /tmp/.out
#     curl -sf "$(bin/fw watchtower url)/page" -o /tmp/.out && grep -q "PAT" /tmp/.out
# This is the better default even when size is not a concern: `&&` keeps the
# PRODUCING command's exit code in the verdict, where `out=$(cmd)` discards it —
# the T-2738 problem one layer down. A 404 from curl fails the line instead of
# silently producing an empty capture for grep to not-match.
#
# REHEARSING A LINE BY HAND DOES NOT REHEARSE THE GATE (T-2743). Your interactive
# shell has no `set -eo pipefail`. The line above returned 0 when run by hand and
# 141 under P-011, from the same directory, the same second. To rehearse for real:
#     bash -c 'set -eo pipefail; <your verification line>'
#
# BUT NOT for a test runner (T-2738): the capture above discards the command's
# exit code, and `set -e` is suppressed inside the `if` condition the gate runs
# each line in — so in `cmd1; cmd2` only cmd2 is the verdict. For pytest/bats
# that exit code WAS the verdict, and the pass marker you grep instead survives
# a partial failure: a suite printing "3 failed, 9 passed" satisfies
# `grep -q "9 passed"`. Generalising to `grep -qE "[0-9]+ passed"` matches the
# same output. Either keep the exit code:
#     python3 -m pytest <file> -q > /tmp/.out 2>&1 && grep -q passed /tmp/.out
# or add the guard the exit code used to supply:
#     out=$(python3 -m pytest <file> -q 2>&1); echo "$out" | grep -q passed && ! echo "$out" | grep -q failed
#     out=$(bats <file> 2>&1); echo "$out" | grep -q '^ok 1 ' && ! echo "$out" | grep -q '^not ok'
# The close gate refuses the unguarded form. Bypass: FW_ALLOW_UNJUDGED_TEST_RUN=1.
#
# Enforcement-baseline hint (L-398, T-1886): if you edited `.claude/settings.json`
# (added/removed/reorganised hooks), add `bin/fw enforcement baseline` to your
# Verification block. Otherwise the canonical hash diverges and `fw doctor`
# reports a FAIL ("Enforcement baseline CHANGED") that accumulates silently.
# Origin: T-1849/T-1730/T-1731 each added a legitimate hook without refreshing
# the baseline — FAIL sat for multiple sessions until T-1886 cleaned up.

out=$(bats tests/unit/secret_key_gitignore.bats 2>&1); echo "$out" | grep -q '^ok 1 ' && ! echo "$out" | grep -q '^not ok'
test -z "$(git ls-files | grep 'fw-secret-key' || true)"

## RCA

<!-- REQUIRED for bug-class tasks (workflow_type=build with bug-tag, OR title matches
     fix/bug/rca/broken/crash/error/regression/fail/hotfix).
     Non-bug-class tasks may leave this section empty or remove it.

     For bug-class, fill in:
       **Symptom:** what was observed (the user-facing manifestation).
       **Root cause:** the specific structural/logical gap — not "the code was wrong".
       **Why structurally allowed:** what in the framework/code/tooling let this go undetected.
       **Prevention:** what catches the next instance (test/lint/gate/doc/learning) — distinct from the fix itself.

     The completion gate (T-1550, G-019) blocks --status work-completed when
     bug-class AND this section is empty/template-only. Use --skip-rca to bypass (logged).
-->

**Symptom:** a framework-generated secret — the key signing `fw_session_<port>` and the
CSRF token in front of the sovereignty surface — tracked in git, pushed to origin and to a
public GitHub mirror, for two months. Observed in 832's tree (rail 498), not ours; ours was
never tracked, but ours is where the generator lives.

**Root cause:** the protection was applied at the site of *discovery* and never at the site
of *generation*. This repo's `.gitignore:48` covers the key. The two `.gitignore` files the
framework itself writes into consumer projects — `lib/init.sh:266` for the consumer's
`.context/working/`, `bin/fw:534` for the vendored copy — did not. `_resolve_secret_key`
chmods the file 0600, which is a filesystem control and says nothing to git, so the only
thing standing between the key and the index was a rule that shipped to exactly one repo:
the framework's own.

**Why structurally allowed:** `agents/git/lib/secret-scan.sh` matches file *content*
against vendor-prefixed credentials — `AKIA…`, `ghp_…`, `sk-ant-…`, `-----BEGIN`. Its header
states that choice deliberately and the choice is defensible. But `secrets.token_hex(32)` is
64 bare hex characters: no prefix, no vendor, no assignment to anchor on. **The one class of
secret the framework is guaranteed to produce is the class its scanner is structurally
guaranteed to miss** — "carries no third-party fingerprint" is what self-generated *means*.
Adding another pattern does not close it; the axis does. Nothing was reading filenames, and
`.fw-secret-key` announced exactly what it was, in its name, the whole time. Every audit
across 832's two-month window printed `[PASS] Secret scan: tracked tree clean` — the failure
mode was a false green, which is why it ran to two months instead of two days.

L-015 (T-1323) had already recorded the general class — *"vendored framework copies need
their own .gitignore; excluding a file from the COPY step doesn't stop the consumer's git
from adding it"* — and the fix that came with it covered exactly the one instance in hand
(`__pycache__`). The learning generalised; the remedy didn't.

**Prevention:** `tests/unit/secret_key_gitignore.bats` (7 tests) checks the *behaviour* —
`git check-ignore` in a real temp repo at both depths — and derives the expectation by
extracting the heredocs from `lib/init.sh` and `bin/fw` at test time, so the test cannot
drift from the emitters the way the emitters drifted from `.gitignore:48`. Verified to have
teeth: the same extractor run against `HEAD:lib/init.sh` reports NOT-ignored, so the test
fails on the pre-fix source rather than passing vacuously. Two positive controls (no-rule
case, and ordinary state files at the same depth) mean a green run cannot come from a probe
that answers "ignored" to everything.

**Not prevented by this task, filed separately as T-2897:** the name-axis blindness above.
That is a scanner, not a gitignore rule, and it is the part that generalises to the next
self-generated secret the framework invents.

## Evolution

<!-- REQUIRED for arc-tagged build tasks (tags include arc:*). Captures how
     understanding evolved during build — what was learned that wasn't known at
     filing, what in the original plan no longer fits, what triggered pivots
     or new sub-tasks. Mandatory at slice boundaries (when applicable) and
     before --status work-completed.

     Origin: T-1717 grill Q4 — "the understanding of what we need and want
     evolves with the process of materialisation." Structural counter to §ACD:
     spec-vs-build divergence is logged as soon as it happens, not lost as
     folklore.

     Format (one entry per slice boundary or significant insight):
       ### YYYY-MM-DD — [topic]
       - **What changed:** [what we learned that we didn't know at filing]
       - **Plan impact:** [what in the plan no longer fits]
       - **Triggered:** [new sub-task / pivot / scope cut, with task ID if filed]

     The completion gate (T-1718) blocks --status work-completed when this
     section exists but is empty/template-only. Use --skip-evolution to bypass
     (logged Tier-2). Non-arc tasks may leave this empty.
-->

## Decisions

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Recommendation

**Recommendation:** GO on the code fix (shipped); the Human AC is a separate call and is
the one that carries the actual risk.

**Rationale:** the generator fix is small, tested, and has no downside — it changes two
`.gitignore` heredocs and cannot break an existing project. What it does *not* do is help
any project that already exists, because `fw upgrade` does not rewrite a consumer's
`.context/working/.gitignore` once written. So the exposure this task documents is closed
going forward and untouched going backward, and only you can see the backward half: the
T-559 boundary gate refused the cross-project sweep, correctly. I am not able to tell you
whether any of your projects is currently publishing a live signing key.

**Evidence:**
- `web/app.py:39-61` — `_resolve_secret_key`, `secrets.token_hex(32)`, chmod 0600, written
  to `PROJECT_ROOT/.context/working/.fw-secret-key` whenever `FW_SECRET_KEY` is unset
- `lib/init.sh:266` and `bin/fw:534` — the two emitters, both fixed here
- `.gitignore:48` — this repo's rule, present all along; `git log --all` over the pathspec
  is empty, so AEF itself was never exposed
- `tests/unit/secret_key_gitignore.bats` — 7/7, teeth verified against `HEAD:lib/init.sh`
- 832 rail 498 — their tree, tracked 2026-06-04 → 2026-08-09, on-disk key sha256-identical
  to the committed blob, live cookie issued from it, `[PASS] Secret scan` every audit
- boundary gate output, this session — the refusal that scopes the Human AC to you

## Updates

### 2026-08-09T11:40:00Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2896-watchtower-secret-key-is-gitignored-in-t.md
- **Context:** Initial task creation
