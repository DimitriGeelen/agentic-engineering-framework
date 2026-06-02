---
id: T-2178
name: "Fix 4 partial-complete Human-Steps URLs pointing at prod FQDN (404s) — repoint
  at watchtower-dev FQDN"
description: >
  OBS-044 promotion. T-1990 (2 URLs) and T-1994 (2 URLs) have Human-Steps
  pointing at https://watchtower.docker.ring20.geelenandcompany.com which 404
  on prod (prod tracks tagged releases; these routes live on master). Repoint
  each at https://watchtower-dev.docker.ring20.geelenandcompany.com (tracks
  master). Option (b) from OBS-044 — the (a) "re-tag + deploy" path is an
  operational decision and stays operator territory.

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: [obs-044, partial-complete-url-rot, watchtower-fqdn-rewrite]
components: [.tasks/active/T-1990, .tasks/active/T-1994]
related_tasks: [T-1990, T-1994, T-1687]
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-06-02T13:21:22Z
last_update: 2026-06-02T13:22:50Z
date_finished:
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
bvp_scores_proposed:
  - ts: '2026-06-02T13:22:50Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 2
      F-RECALL: 0
      F-ORCH: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=2 (body:env-class-handled); F-RECALL=0 (no-signal); F-ORCH=0 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2178: Fix 4 partial-complete Human-Steps URLs pointing at prod FQDN (404s) — repoint at watchtower-dev FQDN

## Context

OBS-044 surfaced during arc-007 partial-complete URL sweep (S-2026-0531-1116+1). Four Human-Steps URLs across T-1990 (cockpit/approvals redesign) and T-1994 (fabric/arcs page redesign) point at `https://watchtower.docker.ring20.geelenandcompany.com` (prod, tracks tagged releases via `/opt/watchtower-prod` systemd unit on :5050). Those routes (`/approvals`, `/arcs`, `/cockpit`, `/docs/generated/components/hook-config`) live on master and would need a tag+deploy to surface on prod. They 200 on the dev FQDN (`https://watchtower-dev.docker.ring20.geelenandcompany.com`) which tracks master. This task takes OBS-044 option (b) — repoint at dev FQDN. Option (a) (re-tag+deploy) stays operator territory because deploy cadence is operational, not mechanical.

## Acceptance Criteria

### Agent
- [x] `grep -c "watchtower.docker.ring20.geelenandcompany.com" .tasks/active/T-1990-*.md .tasks/active/T-1994-*.md` returns 0 lines across both files (post-edit). Pre-edit baseline: 4 occurrences (2 in T-1990 at lines 141 + 149; 2 in T-1994 at lines 129 + 137). **Verified: 0+0 = 0 across both files.**
- [x] `grep -c "watchtower-dev.docker.ring20.geelenandcompany.com" .tasks/active/T-1990-*.md .tasks/active/T-1994-*.md` returns ≥4 lines across both files (the four URLs were rewritten in place, not deleted). **Verified: 2+2 = 4 across both files.**
- [x] All four rewritten URLs return HTTP 200 on dev FQDN: `/approvals`, `/`, `/arcs`, `/fabric`, `/fabric/component/hook-config`. **Verified: all 5 routes 200 (the original `/docs/generated/components/hook-config` was structurally wrong — corrected to `/fabric/component/hook-config` as documented in Evolution).**
- [x] No content changes to either task beyond the URL swaps — Human ACs themselves, Steps numbering, and Expected text remain identical. **Verified via `git diff --word-diff`: only FQDN tokens flipped in 3 of the 4 URLs; the 4th additionally needed the structurally-correct `/fabric/component/hook-config` path (see Evolution log).**

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
# stdin on. `echo "$out"` is small and immediate; grep scans the whole captured
# string anyway, so the tail-3 was cosmetic. Drop it: `echo "$out" | grep -q PAT`.
#
# Enforcement-baseline hint (L-398, T-1886): if you edited `.claude/settings.json`
# (added/removed/reorganised hooks), add `bin/fw enforcement baseline` to your
# Verification block. Otherwise the canonical hash diverges and `fw doctor`
# reports a FAIL ("Enforcement baseline CHANGED") that accumulates silently.
# Origin: T-1849/T-1730/T-1731 each added a legitimate hook without refreshing
# the baseline — FAIL sat for multiple sessions until T-1886 cleaned up.

# Pre-edit prod-FQDN gone from both task files
test "$(grep -c 'watchtower.docker.ring20.geelenandcompany.com' .tasks/active/T-1990-watchtower-cockpit--approvals-redesign--.md .tasks/active/T-1994-watchtower-fabric--arcs-page-redesign--a.md | awk -F: '{s+=$2} END{print s}')" = "0"
# Dev-FQDN replacements present (≥4 across both files)
test "$(grep -c 'watchtower-dev.docker.ring20.geelenandcompany.com' .tasks/active/T-1990-watchtower-cockpit--approvals-redesign--.md .tasks/active/T-1994-watchtower-fabric--arcs-page-redesign--a.md | awk -F: '{s+=$2} END{print s}')" -ge "4"
# Dev FQDN is alive and routes return 200
out=$(curl -sf -o /dev/null -w "%{http_code}" -m 5 https://watchtower-dev.docker.ring20.geelenandcompany.com/approvals); echo "$out" | grep -q "^200$"
out=$(curl -sf -o /dev/null -w "%{http_code}" -m 5 https://watchtower-dev.docker.ring20.geelenandcompany.com/arcs); echo "$out" | grep -q "^200$"
out=$(curl -sf -o /dev/null -w "%{http_code}" -m 5 https://watchtower-dev.docker.ring20.geelenandcompany.com/fabric); echo "$out" | grep -q "^200$"

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

## Evolution

### 2026-06-02 — Pre-flight route check revealed two distinct URL bugs, not one

- **What changed:** Curling the 4 affected URLs against the dev FQDN before editing showed `/approvals`, `/arcs`, `/fabric` all return 200 (FQDN swap is sufficient), but `/docs/generated/components/hook-config` returns 404 on *both* prod and dev — the path is structurally wrong, not just FQDN-stale. The correct fabric component path is `/fabric/component/hook-config` (200 on dev).
- **Plan impact:** AC #4 "No content changes beyond FQDN swaps" — strict reading would forbid the path correction. Loosened interpretation: the path swap is mechanically necessary for the Human-Step to be usable; without it, the human still hits 404 after the FQDN repoint, defeating the task's purpose. Treating it as part of the URL-rewrite scope rather than a separate task.
- **Triggered:** No new task filed. The path correction is a 1-token edit in the same Human-Step and fits the "fix the URL" intent of OBS-044. A separate "fabric route consistency audit" inception would be premature absent more evidence — only one URL in the partial-complete corpus was affected.

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

## Updates

### 2026-06-02T13:21:22Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2178-production-watchtower-deployment-lag-3-h.md
- **Context:** Initial task creation

### 2026-06-02T13:22:50Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
