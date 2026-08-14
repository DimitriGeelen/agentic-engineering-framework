# T-1506 — RCA — Tier 0 approval self-defeats under duplicate hook registration (.claude/settings.json

> **Inception research artifact** (backfilled by T-2515 from the `T-1506` task body — the research was captured in-task at decision time; this extracts it verbatim to the canonical `docs/reports/` home per C-001). Source: `.tasks/completed/T-1506-rca--tier-0-approval-self-defeats-under-.md`. **Decision recorded: GO.**

## Problem Statement

**Tier 0 — the framework's strongest enforcement gate — self-defeats under a 2-line settings misconfiguration.**

Live evidence (this session, 2026-04-26 ~11:17–11:23):
- `check-tier0` is registered TWICE: in `.claude/settings.json` (project-level) AND in `/root/.claude/settings.json` (user-level).
- A single Bash invocation fires the hook twice. Hook 1 reads `.tier0-approval`, matches hash, **`rm -f`s the file** (single-use consume), exits 0 → allow. Hook 2 fires immediately after, finds NO approval file (just consumed), and **writes a fresh `.pending` file + blocks**.
- Bypass log proves it: 11:17:19 AND 11:19:35 both show "approved" for the SAME command hash `29eb949...`. The user-side path consumed the approval; the agent-side observation is "still blocked".
- Net effect: every approve+retry loop ends in BLOCK regardless of how many times the human approves. Tier 0 cannot be unblocked from inside the agent session.

The deeper class of problem (G-019 territory): **any hook that mutates single-use shared state is silently broken under duplicate registration.** Tier 0 is the most visible offender; budget-gate, check-active-task, episodic-finalize and others may share the property.

## Assumptions

- **A1:** `check-tier0` is the only Tier 0 enforcement path; if its file mutation is non-idempotent, no approval can succeed.
- **A2:** Duplicate registration arose from `fw upgrade` (or a manual user-level config edit) writing `.agentic-framework/bin/fw hook check-tier0` to `~/.claude/settings.json` while the project repo's own `.claude/settings.json` already registers the absolute-path version.
- **A3:** Other hooks with `rm`-then-act semantics on shared state are equally vulnerable. Suspects: `agents/context/check-active-task.sh`, `agents/context/budget-gate.sh`, `agents/context/checkpoint.sh`.
- **A4:** Detection is cheap — `fw doctor` already inventories hooks; it does not currently dedupe.

## Exploration Plan

1. **Confirm A1** (5 min) — grep both settings files, count registrations of every PreToolUse hook name. Output: hook→count table.
2. **Confirm A3** (15 min) — for each hook script under `agents/context/`, identify mutating operations on `.context/working/*` that assume single invocation. Output: vulnerable-hook list.
3. **Spike fix variants** (30 min, no implementation):
   - **(a) Install-time dedup:** `fw upgrade` strips duplicate hook entries when project + user settings both register identical commands.
   - **(b) Runtime idempotency via flock:** hook acquires `flock` on the approval file; first invocation consumes + sets a short-lived "just-consumed" sentinel; second invocation sees the sentinel and short-circuits to allow.
   - **(c) Approval-ticket model:** approval lives for N seconds AND ≤M invocations within that window (default M=3 to absorb duplicate-registration cases) instead of strict single-use.
   - **(d) Doctor-only:** `fw doctor` warns on duplicate hook registration; humans clean up manually. No runtime change.
4. **Cost/benefit table** for each variant.

## Technical Constraints

- Cannot modify `~/.claude/settings.json` from agent context without crossing the consumer/user boundary (CLAUDE.md path-isolation rule). Variant (a) must run from `fw upgrade` invoked by the user.
- `flock` is universally available on Linux; macOS has it via Homebrew but not by default. Variant (b) needs a portability check.
- Approval file is currently in `.context/working/` (project-scoped). Variant (c) preserves that — no path change.

## Scope Fence

**IN scope:**
- RCA of the duplicate-hook tier0 self-defeat (confirm, characterize, generalize).
- Recommend ONE structural fix path with a bounded build estimate.

**OUT of scope:**
- Implementing the fix (separate build task after GO).
- Auditing every hook in the repo for state-mutation patterns (would expand scope; do as follow-up if A3 proves true).
- Migrating Tier 0 to a Watchtower-mediated approval flow (orthogonal redesign).

## Go/No-Go Criteria

**GO if:**
- Root cause identified with bounded fix path
- Fix is scoped, testable, and reversible

**NO-GO if:**
- Problem requires fundamental redesign or unbounded scope
- Fix cost exceeds benefit given current evidence

## Findings (from exploration)

**A1 confirmed (worse than predicted):** ALL TEN hooks are duplicated, not just `check-tier0`. Every Pre/PostToolUse hook fires twice per Bash call:

| Hook | Project (`/opt/.../bin/fw`) | User (`.agentic-framework/bin/fw`) |
|------|---|---|
| block-plan-mode | ✓ | ✓ |
| check-active-task | ✓ | ✓ |
| **check-tier0** | ✓ | ✓ |
| check-agent-dispatch | ✓ | ✓ |
| check-project-boundary | ✓ | ✓ |
| budget-gate | ✓ | ✓ |
| block-task-tools | ✓ | ✓ |
| checkpoint (post) | ✓ | ✓ |
| check-dispatch (post) | ✓ | ✓ |
| check-fabric-new-file (post) | ✓ | ✓ |

**A3 confirmed (partially):** state-mutation audit:
- `check-tier0.sh`: 2 rm + 1 write → **vulnerable** (the one we hit)
- `checkpoint.sh`: 6 rm calls → **likely vulnerable** (separate investigation)
- `check-agent-dispatch.sh`: 1 rm → possibly vulnerable
- `check-active-task.sh`, `budget-gate.sh`, `block-task-tools.sh`: rm=0 → idempotent (safe under duplication)

**A2 status:** likely true but unconfirmed without git-blame on `~/.claude/settings.json`. The user-side hooks use `.agentic-framework/bin/fw` (the consumer-style path), suggesting a `fw upgrade` writing user-level hooks even when run inside the framework repo.

**A4 confirmed:** `fw doctor` exists but does not currently dedupe hooks across settings layers.

## Recommendation

**Recommendation:** GO — apply layered fix (a)+(b)

**Why layered:** (a) alone removes the trigger but doesn't make the gate robust — a future config drift will reintroduce the failure. (b) alone makes the gate robust but leaves 9 other duplicate hooks doubling tool-call latency invisibly. Together they give defense-in-depth: visibility + robustness.

**Layer (a) — Install-time + doctor dedup (≈40 lines):**
1. Add `lib/hooks_dedup.sh` with `dedupe_hook_registrations()` that scans both project + user settings, identifies hooks with identical `name` (last path segment after `hook `), and removes the duplicate from user settings (project wins — closer to the codebase, more specific).
2. Wire into `fw upgrade` (post-install step) and `fw doctor` (warn if duplicates present, suggest `fw upgrade --dedupe-hooks`).
3. Add bats test: synth two settings files with identical hook entries; run dedup; assert only project entry remains.

**Layer (b) — Tier 0 idempotency via "just-consumed" sentinel (≈15 lines in `check-tier0.sh`):**
1. On approval consumption, write `${APPROVAL_FILE}.consumed` with the consumed hash + timestamp.
2. Before blocking on missing approval, check `.consumed` file: if same hash + age < 5s, allow (sentinel TTL = 5s catches duplicate hook firings within the same Bash invocation but expires before the next legitimate invocation).
3. Bats test: simulate two-call sequence (consume → check-consumed-shortcircuit) and assert second call exits 0 without writing a new `.pending`.

**Build estimate:** 1 session (~2 hours). Two files, two bats tests, one fw doctor wiring.

**Rationale:**
1. **Antifragility:** failure was invisible (Tier 0 is supposed to be the strongest gate; nobody knew it could self-defeat). Both layers make duplication visible AND harmless.
2. **Bounded scope:** ~55 lines + 2 bats tests. No architecture change; no new dependencies.
3. **Generalizes:** the sentinel pattern in (b) is a template for fixing `checkpoint.sh` and `check-agent-dispatch.sh` later. Document as L-XXX (idempotent-hook pattern).
4. **Evidence-based:** confirmed live in this session — bypass log shows the same approved hash consumed twice (11:17:19 + 11:19:35) while the agent observed only blocks. Two human approvals, zero successful pushes.

**Alternative considered (DEFER):** open a broader inception covering all 3 vulnerable hooks + a hook-design-policy doc. Rejected: tier0 is acutely broken now (blocks legitimate work in this session); the other two are slower-burning. Fix tier0 first, then survey.

**Alternative considered (NO-GO — variant (d) doctor-only):** rely on humans to clean up via `fw doctor` warnings. Rejected: violates antifragility — the gate is still latently broken between detection and cleanup; a duplicate arising mid-session blocks all destructive work until someone runs doctor and edits two files.

**Alternative considered (variant (c) — N-use TTL):** changes Tier 0 semantics from "single-use" to "≤M-use within window." Rejected: weakens the security model. The sentinel approach in (b) preserves single-use semantics (once consumed, only same-hash same-invocation duplicates short-circuit; new commands still need fresh approval).

**Evidence:**
- `.context/bypass-log.yaml` — two consecutive entries for hash `29eb949...`
- `.claude/settings.json` + `/root/.claude/settings.json` — duplicate hook registrations (10/10 hooks)
- `agents/context/check-tier0.sh:189,227` — `rm -f` calls that defeat the second invocation
- This session's transcript — three approve-retry cycles, all ending in BLOCK

## Decision

**Decision**: GO

**Rationale**: 1. Antifragility: failure was invisible (Tier 0 is supposed to be the strongest gate; nobody knew it could self-defeat). Both layers make duplication visible AND harmless.
2. Bounded scope: ~55 lines + 2 bats tests. No architecture change; no new dependencies.
3. Generalizes: the sentinel pattern in (b) is a template for fixing `checkpoint.sh` and `check-agent-dispatch.sh` later. Document as L-XXX (idempotent-hook pattern).
4. Evidence-based: confirmed live in this session — bypass log shows the same approved hash consumed twice (11:17:19 + 11:19:35) while the agent observed only blocks. Two human approvals, zero successful pushes.

Alternative considered (DEFER): open a broader inception covering all 3 vulnerable hooks + a hook-design-policy doc. Rejected: tier0 is acutely broken now (blocks legitimate work in this session); the other two are slower-burning. Fix tier0 first, then survey.

Alternative considered (NO-GO — variant (d) doctor-only): rely on humans to clean up via `fw doctor` warnings. Rejected: violates antifragility — the gate is still latently broken between detection and cleanup; a duplicate arising mid-session blocks all destructive work until someone runs doctor and edits two files.

Alternative considered (variant (c) — N-use TTL): changes Tier 0 semantics from "single-use" to "≤M-use within window." Rejected: weakens the security model. The sentinel approach in (b) preserves single-use semantics (once consumed, only same-hash same-invocation duplicates short-circuit; new commands still need fresh approval).

**Date**: 2026-04-26T11:32:42Z

## Reviewer Verdict (v1.5)

- **Scan ID:** R-2188c4ab
- **Timestamp:** 2026-06-02T14:57:57Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-04-26T11:32:42Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO
