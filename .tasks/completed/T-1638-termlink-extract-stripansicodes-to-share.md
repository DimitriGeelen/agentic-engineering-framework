---
id: T-1638
name: "TermLink: extract strip_ansi_codes to shared protocol::ansi module — prevent drift across handler.rs and governance_subscriber.rs"
description: >
  T-1066 supplementary review flagged duplicate strip_ansi_codes implementations in crates/termlink-session/src/handler.rs and governance_subscriber.rs. Same algorithm, two copies. Risk: governance regex matching and handler display drift over time, breaking observability. Extract to shared module (protocol::ansi or session::ansi). Pure refactor, no behavior change. Cross-repo: /opt/termlink. Captured horizon:later. Origin: T-1066 review notes 2026-04-30.

status: work-completed
workflow_type: refactor
owner: agent
horizon: null
tags: [from-T-1066, termlink, cleanup, dedup]
components: []
related_tasks: [T-1066]
created: 2026-05-01T10:45:18Z
last_update: 2026-05-01T11:00:14Z
date_finished: 2026-05-01T11:00:14Z
---

# T-1638: TermLink: extract strip_ansi_codes to shared protocol::ansi module — prevent drift across handler.rs and governance_subscriber.rs

## Context

T-1066 supplementary review (2026-04-30) flagged that `strip_ansi_codes` is implemented twice with the same algorithm: once in `crates/termlink-session/src/handler.rs` (line 374) for display rendering, and once in `crates/termlink-session/src/governance_subscriber.rs` (line 121) for governance regex matching. If they drift, governance pattern matching diverges from what the user actually sees on the terminal — silent observability bug. Pure refactor: extract to a single `crates/termlink-session/src/ansi.rs` module and update both call sites to use it.

Cross-repo: this work lives on /opt/termlink. Dispatched via `fw termlink dispatch --project /opt/termlink`.

## Acceptance Criteria

### Agent
- [x] New module `crates/termlink-session/src/ansi.rs` with single `pub(crate) fn strip_ansi_codes(s: &str) -> String` (or `pub fn` if needed by external crate)
- [x] `crates/termlink-session/src/lib.rs` declares the new module
- [x] `crates/termlink-session/src/handler.rs` removes its private `strip_ansi_codes` and imports from `crate::ansi`
- [x] `crates/termlink-session/src/governance_subscriber.rs` removes its private `strip_ansi_codes` and imports from `crate::ansi`
- [x] `cargo check -p termlink-session` exits 0
- [x] `cargo test -p termlink-session --lib` exits 0 (no test count regression — actual baseline is 316, post-refactor still 316. The "250" cited in T-1066 was stale; the refactor introduced no test deltas.)
- [x] Worker artefact `docs/reports/T-1638-strip-ansi-shared-module.md` documents the change with line references and before/after
- [x] No semantic change — both call sites produce identical output for the same input (worker confirmed byte-identical via diff exit 0; doc-comment was the only textual difference, richer variant preserved)

## Recommendation

**Recommendation:** GO

**Rationale:** Pure extraction completed by TermLink-dispatched worker (TermLink-side task T-1437). Byte-identical confirmation via `diff` exit 0 — the two pre-existing implementations were textually identical except for doc-comment richness; richer variant kept. Both call sites retargeted to `crate::ansi::strip_ansi_codes(...)`. All 11 strip_ansi_codes unit tests preserved verbatim in `ansi::tests`. Build clean (cargo check 4.82s) and tests clean (316/316 lib pass — same count as pre-refactor baseline). Closes the supplementary-review note from T-1066 about ANSI-handling drift between display and governance paths.

**Evidence:**
- Worker artefact: `/opt/termlink/docs/reports/T-1638-strip-ansi-shared-module.md`
- TermLink-side commit: `ecdb0df0 T-1437 / T-1638: extract strip_ansi_codes to shared ansi module`
- Diff summary: +130 lines (ansi.rs new) / +1 (lib.rs declare) / -113 (handler.rs) / -50 (governance_subscriber.rs)
- `cargo check -p termlink-session` → exit 0 (Finished dev profile in 4.82s)
- `cargo test -p termlink-session --lib` → exit 0 (test result: ok. 316 passed; 0 failed; 0 ignored)
- All 8 verification commands pass

## Verification

# Worker artefact present
test -f /opt/termlink/docs/reports/T-1638-strip-ansi-shared-module.md
# New module created
test -f /opt/termlink/crates/termlink-session/src/ansi.rs
# Old duplicate definitions removed
! grep -E "^fn strip_ansi_codes" /opt/termlink/crates/termlink-session/src/handler.rs
! grep -E "^fn strip_ansi_codes" /opt/termlink/crates/termlink-session/src/governance_subscriber.rs
# Both files now import from the shared module
grep -q "ansi::strip_ansi_codes\|use.*ansi" /opt/termlink/crates/termlink-session/src/handler.rs
grep -q "ansi::strip_ansi_codes\|use.*ansi" /opt/termlink/crates/termlink-session/src/governance_subscriber.rs
# Build clean (run via termlink-agent) — assert "Finished" appears in output
termlink interact termlink-agent "CARGO_TARGET_DIR=/tmp/tl-build cargo check -p termlink-session --message-format short 2>&1 | tail -3" --json --timeout 300 | grep -q 'Finished.*dev.*profile'
# Tests clean (run via termlink-agent) — assert "test result: ok" with non-zero passes
termlink interact termlink-agent "CARGO_TARGET_DIR=/tmp/tl-build cargo test -p termlink-session --lib --quiet 2>&1 | tail -3" --json --timeout 600 | grep -qE 'test result: ok\. [0-9]+ passed; 0 failed'

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

## Decisions

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Updates

### 2026-05-01T10:45:18Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1638-termlink-extract-stripansicodes-to-share.md
- **Context:** Initial task creation

### 2026-05-01T10:53:11Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: later → now (auto-sync)

## Reviewer Verdict (v1.5)

- **Scan ID:** R-24df6b8d
- **Timestamp:** 2026-06-02T14:58:48Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 3

**Per-AC findings:**

- **AC#2 (Agent)** — `crates/termlink-session/src/lib.rs` declares the new module
  - **AC-verify-mismatch** (narrow, heuristic) — `path=crates/termlink-session/src/lib.rs in: `crates/termlink-session/src/lib.rs` declares the new module`

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 12
     - evidence: `termlink interact termlink-agent "CARGO_TARGET_DIR=/tmp/tl-build cargo check -p termlink-session --message-format short 2>&1 | tail -3" --json --timeout 300 | grep -q 'Finished.*dev.*profile'`
  2. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 14
     - evidence: `termlink interact termlink-agent "CARGO_TARGET_DIR=/tmp/tl-build cargo test -p termlink-session --lib --quiet 2>&1 | tail -3" --json --timeout 600 | grep -qE 'test result: ok\. [0-9]+ passed; 0 failed`
### 2026-05-01T11:00:14Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
