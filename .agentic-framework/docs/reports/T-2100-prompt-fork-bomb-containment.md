# T-2100: Enhance consumer-upgrade-test-fix-report prompt — fork-bomb containment

**Status:** inception (research artifact, C-001)
**Filed:** 2026-05-29
**Origin:** Fork-bomb incidents on /opt/termlink (T-2099 origin) + user ask "do we need to adjust/enhance instructions?"
**Cluster:** T-2078 (fw upgrade reliability), T-2099 (the live-fire fix)
**Sibling:** T-2097 (seed-files), T-2098 (playwright)

---

## Problem Statement

`prompts/consumer-upgrade-test-fix-report.md` is the canonical prompt the fleet receives to upgrade + test + fix + report. It is shape-aware (consumer-initialized / consumer-vendored-skewed / consumer-uninitialized / framework-repo) and routes failures via TermLink envelopes — structurally sound.

But it failed to **contain** the SEV-1 fork-bomb when it fired on /opt/termlink (2 incidents, 1 hour). The consumer agent had no panic-stop instruction, no recursion sentinel, no fork-bomb-specific forensic fields. The dispatcher agent had to assemble the forensic trail manually after the fact.

This is the same class as T-2097/T-2098 — the prompt is correct for the happy path but silent in the failure mode. Hardening adds containment without changing routing.

---

## Six Enhancement Candidates

### E1 — STEP 0 (new): panic-stop preamble

Insert at the top of STEP 1, before shape detection:

> ## STEP 0 — Panic-stop awareness
>
> If at any point during this prompt:
> - `pgrep -c "fw upgrade"` exceeds **5**, OR
> - `uptime` load avg jumps **>2× baseline** within 30 seconds, OR
> - the `Bare-from-consumer detected — auto-cloning upstream` message appears **more than once**,
>
> STOP IMMEDIATELY: `pkill -9 -f "fw upgrade"`. Then capture forensics BEFORE retry. This is T-2099-class recursion; the upstream fix may not have shipped to this host yet.

### E2 — STEP 2.5 (new): dry-run gate

Between snapshot and upgrade:

> ## STEP 2.5 — Dry-run gate (REQUIRED)
>
> Always run dry-run first:
>
> ```
> .agentic-framework/bin/fw upgrade --dry-run
> ```
>
> Inspect output for: `Bare-from-consumer detected — auto-cloning upstream` (appears once is normal; twice means recursion risk — abort). Only proceed to STEP 3 if dry-run shows expected file changes and exits cleanly.

### E3 — STEP 3 (amend): recursion sentinel

Replace the bare invocation with:

> ## STEP 3 — Upgrade framework (with recursion sentinel)
>
> ```
> timeout 120 .agentic-framework/bin/fw upgrade
> rc=$?
> if [ "$rc" = 124 ]; then
>     echo "TIMEOUT: fw upgrade did not complete in 120s — possible recursion"
>     pkill -9 -f "fw upgrade"
>     # Skip to STEP 7 with structured envelope, do not retry
> fi
> ```
>
> If you see the `Bare-from-consumer` message fire more than once in the output, abort with `pkill -9 -f "fw upgrade"` regardless of timeout.

### E4 — STEP 3 (prepend): upstream-check

Add before the upgrade invocation:

> ### Before invoking upgrade — verify upstream
>
> ```
> grep -E "^upstream" .framework.yaml
> ```
>
> If the line shows OneDev, switch to GitHub canonical:
>
> ```
> .agentic-framework/bin/fw config set UPSTREAM_URL https://github.com/DimitriGeelen/agentic-engineering-framework.git
> ```
>
> Re-verify, then proceed.

### E5 — STEP 5 (amend): playwright disambiguation

After the test-all line:

> If you see `ModuleNotFoundError: No module named 'web'` from playwright tests, that is **PL-125-class** (conftest cwd bug — `tests/playwright/conftest.py:71` spawns `python3 -m web.app` with the wrong cwd in vendored installs). File as a separate finding; do NOT attempt to fix in `.agentic-framework/` (path-isolation rule).

### E6 — Structured envelope (extend): fork-bomb fields

Add to the existing failure envelope template:

```
process_count_peak:       (from `pgrep -c "fw upgrade"` at peak)
load_avg_peak:            (from `uptime` 1-min average at peak)
clone_tempdir_count:      (from `ls -d /tmp/fw-upstream-* 2>/dev/null | wc -l`)
recursion_target_dir:     (the `target_dir` argument in nested handoffs — may
                           shift between runs per T-1699 intermittency datum)
fix_landed_check:         (from `cd .agentic-framework && git log --oneline -5
                           | grep T-2099 || echo "fix not yet pulled"`)
```

---

## Decision Criteria

A GO answer should specify:
1. Which of E1–E6 to land in v1 (recommendation: all six — they are cheap text additions with no behavioural conflict)
2. Whether to ship as a single PR or one-per-enhancement (recommendation: single — they are mutually reinforcing)
3. Whether the fanout to other prompts in the library (`consumer-upgrade-and-test.md` etc.) should mirror these additions (recommendation: yes for E1/E2/E6 — universal; E3/E4/E5 are upgrade-specific)

---

## Recommendation

**Recommendation:** GO — land all six enhancements as a single PR.

**Rationale:** Each enhancement addresses a specific gap exposed by the T-2099 fork-bomb incident. They are textual additions to a prompt file with no behavioural side-effects on the framework itself. Cost is bounded (~80 lines of prompt edits). Benefit is structural: every future consumer that receives this prompt has the containment instructions inline, even if the underlying recursion bug ever regresses.

**Evidence:**
- T-2099 fork-bomb incident: 2 hits in 1 hour on /opt/termlink, no consumer-side panic-stop available → required dispatcher intervention.
- Existing prompt (`prompts/consumer-upgrade-test-fix-report.md`) is well-structured but failure-silent — same G-019 class as T-2097/T-2098.
- The fix (T-2099, `be72baa5`) is now shipped to GitHub; but the prompt should not assume every consumer pulls before running.
- Comparable hardening in `prompts/escalation-triage.md` already documents panic-stop patterns — the pattern is established in the library.

**Suggested follow-ups (on GO):**
- T-2100-V1: apply E1–E6 to `prompts/consumer-upgrade-test-fix-report.md`.
- T-2100-V2: mirror E1/E2/E6 to other upgrade-relevant prompts in the library (`consumer-upgrade-and-test.md`, etc.).
- T-2100-V3: bats coverage for prompt-library structural guarantees (e.g. every shipping prompt has a panic-stop or non-fork-bomb-touching declaration).

**Rejected alternatives:**
- Ship enhancements piecemeal — adds review overhead with no benefit; the six are mutually reinforcing.
- Only E3/E6 (the minimal containment set) — leaves E1/E2 gaps; agent's panic-stop awareness depends on out-of-prompt knowledge.

---

## Dialogue Log

User asked: "do we need to adjust/enhance instructions ??" referring to <http://192.168.10.107:3000/prompts/consumer-upgrade-test-fix-report>, in the same turn that the SEV-1 fork-bomb dispatch landed.

Agent eval: yes — six specific gaps, all containment-class. Same G-019 silent-quality-decay pattern as T-2097/T-2098. Filed as inception per "one inception = one question" — this is a distinct question from "fix the fork-bomb" (T-2099) and "fix fw upgrade reliability" (T-2078 cluster).

User then clarified: "the prompt is part of this framework prompt library ask component fabric !!! its part of this framework !!!" — confirming the prompt source lives at `prompts/consumer-upgrade-test-fix-report.md` in this repo (verified via `fw fabric search` + grep). The edit lands here and ships out via subsequent consumer upgrades.
