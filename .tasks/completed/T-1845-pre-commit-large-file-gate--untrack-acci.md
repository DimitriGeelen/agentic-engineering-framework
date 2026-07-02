---
id: T-1845
name: "pre-commit large-file gate + untrack accidentally-tracked binaries (os 36MB,
  fw-vec-index.db 78MB) — sibling prevention to T-1844 secret-scan"
description: "T-1834 force-push surfaced two tracked binaries (os 36MB PostScript,
  fw-vec-index.db 78MB vector index) that GitHub flagged as oversized during the rewritten-history
  push. They are accidentally-committed runtime/output state, not source. Sibling
  prevention class to T-1844 (secret-scan) — a structural pre-commit gate that would
  have caught both files at the moment they were first staged. Deliverables: (1) agents/git/lib/large-file-scan.sh
  scan-staged+scan-tree+allowlist, (2) pre-commit hook wires it after secret-scan,
  (3) untrack os + .gitignore /os, (4) untrack fw-vec-index.db + gitignore, (5) seed
  allowlist with vendored node_modules paths, (6) fw doctor surfaces tracked-large-file
  warn. Origin: T-1844 allowlist comment about the untracked 36MB file — captured
  at the time but no follow-up task."
status: work-completed
workflow_type: build
owner: agent
horizon: null
components: ["agents/git/lib/secret-scan.sh", "agents/git/lib/hooks.sh"]
related_tasks: ["T-1844", "T-1828", "T-1834", "T-1716"]
arc_id: project-shape-resilience
created: 2026-05-15T11:20:04Z
last_update: '2026-06-11T22:24:00Z'
date_finished: 2026-05-15T13:44:00+02:00
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:00Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 2
      D3: 0
      D4: 0
      F-RECALL: 1
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=2 
      (body:telemetry-or-audit-entry); D3=0 (no-signal); D4=0 (no-signal); 
      F-RECALL=1 (body:episodic-only); F-ORCH=0 (no-signal); F3=0 (no-signal); 
      F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1845: pre-commit large-file gate + untrack accidentally-tracked binaries (os 36MB, fw-vec-index.db 78MB) — sibling prevention to T-1844 secret-scan

## Context

T-1834's filter-repo + force-push to GitHub surfaced large-object warnings ("File 74MB / 53MB exceeds GitHub's recommended max"). Investigation revealed two accidentally-tracked binaries: `os` (36MB ImageMagick-generated PostScript at repo root, single commit T-1716, no gitignore entry) and `.context/working/fw-vec-index.db` (78MB sqlite-vec index, runtime state, re-committed every session). The 45MB tracked under `.agentic-framework/lib/ts/node_modules/` is deliberate self-bootstrap (T-012) and stays — it gets an allowlist entry.

Same structural class as T-1828/T-1834 (no pre-commit gate against accidentally-staged content). T-1844 fixed the secret-scan instance of this class; T-1845 fixes the large-file instance.

## Acceptance Criteria

### Agent
- [x] `agents/git/lib/large-file-scan.sh` exists with `scan-staged`, `scan-tree`, `scan-file` subcommands and `--help`
- [x] `agents/git/lib/large-file-scan.sh scan-tree` reports zero `[BLOCK]` hits in the working tree after cleanup
- [x] `.large-file-allowlist` exists at project root with the `.agentic-framework/lib/ts/node_modules/` exemption
- [x] Pre-commit hook at `.git/hooks/pre-commit` invokes the large-file scanner after the secret-scanner; staging a >10MiB file blocks the commit
- [x] `os` is no longer tracked (`git ls-files os` returns empty) and `/os` is in `.gitignore`
- [x] `.context/working/fw-vec-index.db` is no longer tracked and `.context/working/fw-vec-index.db` (or `*.db` pattern) is in `.gitignore`
- [x] Unit-test harness at `tests/unit/test_large_file_scan.bats` covers: scan-staged blocks an oversized stage, scan-staged passes a normal stage, allowlist suppresses a match, threshold env var honoured
- [x] `fw doctor` adds a `[WARN]` line when `scan-tree` finds tracked files in the WARN range (between 1MiB and 10MiB) that aren't in the allowlist — or `[PASS]` line when clean

### Human
<!-- Criteria requiring human verification (UI/UX, subjective quality). Not blocking.
     Remove this section if all criteria are agent-verifiable.
     Each criterion MUST include Steps/Expected/If-not so the human can act without guessing.
     Optionally prefix with [RUBBER-STAMP] or [REVIEW] for prioritization.
     Example:
       - [ ] [REVIEW] Dashboard renders correctly
         **Steps:**
         1. Open https://example.com/dashboard in browser
         2. Verify all panels load within 2 seconds
         3. Check browser console for errors
         **Expected:** All panels visible, no console errors
         **If not:** Screenshot the broken panel and note the console error
-->

## Verification

test -x agents/git/lib/large-file-scan.sh
test -f .large-file-allowlist
grep -q "^/os$" .gitignore
grep -qE "fw-vec-index\.db|\.context/working/.*\.db" .gitignore
test -z "$(git ls-files os 2>/dev/null)"
test -z "$(git ls-files .context/working/fw-vec-index.db 2>/dev/null)"
PROJECT_ROOT="$PWD" bash agents/git/lib/large-file-scan.sh scan-tree
grep -q "agents/git/lib/large-file-scan.sh\|large-file" .git/hooks/pre-commit
bats tests/unit/test_large_file_scan.bats

## RCA

**Symptom:** GitHub push protection emitted `File X exceeds GitHub's recommended maximum` warnings during the T-1834 history-rewrite force-push. Two binaries — `os` (36MB ImageMagick PostScript) and `.context/working/fw-vec-index.db` (78MB sqlite-vec index) — had been tracked in master for weeks without anyone noticing during normal pushes (warnings are non-blocking; only the leak's GH013 gate revealed them).

**Root cause:** No structural gate against accidentally-staged large files. `git add` accepts anything; `pre-commit` had a secret-scan layer (T-1844) but no size layer. Two distinct accidents:
1. `os` — ImageMagick output written to repo root with the literal filename `os` (likely `convert <something> os` from a shell where `cd` ended on the framework). One commit (T-1716) added it; nobody noticed at the time.
2. `fw-vec-index.db` — runtime sqlite-vec index. Lives in `.context/working/`, which is intentionally partially-tracked for handover continuity. The index file slipped through because `.gitignore` only excludes specific patterns inside `.context/working/`, not the `*.db` runtime state.

**Why structurally allowed:** T-1844 catches secrets at stage time; nothing catches size. The cost is delayed: a 36MB file in history isn't blocked by GitHub's `recommended` warning, only by the absolute 100MB ceiling. By the time GH013 (secret scanning) forced a filter-repo, the files had been bouncing through history for 10+ days. Without T-1845, the next large binary (screenshot, dump, profiler output) would land in master with no friction.

**Prevention:** `agents/git/lib/large-file-scan.sh` — pre-commit gate blocks at 10MiB, warns at 1MiB, allowlist exempts deliberate vendored cases (`.agentic-framework/lib/ts/node_modules/`). Mirrors T-1844's secret-scan shape so the two layers compose cleanly in `.git/hooks/pre-commit`. `fw doctor` surfaces tracked-large-file count for audit-time visibility (the T-1834-class blindness was a doctor-couldn't-see-it problem; this layer makes it see).

## Evolution

### 2026-05-15 — `.agentic-framework/lib/ts/node_modules/` allowlist scope
- **What changed:** initial filing planned to untrack three classes (os, fw-vec-index.db, vendored node_modules). On investigation, `.agentic-framework/lib/ts/node_modules/` is deliberate self-bootstrap committed by T-012 to support consumer-style framework install from a clean checkout. Removing would break self-vendor.
- **Plan impact:** dropped one of three cleanup targets; instead added to `.large-file-allowlist` as a documented legitimate exemption. Cleanup scope shrunk from 3 → 2 files, allowlist scope grew by one rule.
- **Triggered:** no new sub-task. The allowlist comment in `.large-file-allowlist` carries the decision history for future agents.

### 2026-05-15 — `liveness.jsonl` left as INFO not WARN
- **What changed:** scan-tree post-cleanup found `.context/monitors/liveness.jsonl` at 2.1 MiB (warn range). Not block-class, runtime-monitor state.
- **Plan impact:** chose INFO output in `fw doctor` for warn-range findings instead of WARN. Block-class is the actionable signal; warn-class is visibility.
- **Triggered:** none — file rotation could be a follow-up if liveness.jsonl keeps growing.

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

### 2026-05-15T11:20:04Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1845-pre-commit-large-file-gate--untrack-acci.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-a9c03e97
- **Timestamp:** 2026-06-02T14:59:58Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
