---
id: T-1844
name: "pre-commit secret scan hook — root-cause prevention for T-1828/T-1834 class"
description: >
  pre-commit secret scan hook — root-cause prevention for T-1828/T-1834 class

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: [bug, security]
components: []
related_tasks: []
arc_id: project-shape-resilience
created: 2026-05-15T07:04:44Z
last_update: '2026-05-19T18:27:45Z'
date_finished:
bvp_scores_proposed:
  - ts: '2026-05-19T18:27:45Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1844: pre-commit secret scan hook — root-cause prevention for T-1828/T-1834 class

## Context

Root-cause prevention for the T-1828 / T-1834 incident class: an Azure DevOps PAT was committed to framework history at `79e3361d` (T-1736 Spike B, 2026-05-05) and reached OneDev origin. GitHub mirror has been blocked by GH013 push protection for 9+ hours. The framework's commit pipeline had **no secret scanner** — `commit-msg` only enforces task-reference, `pre-push` only checks VERSION/audit. A pre-commit secret scan would have blocked `79e3361d` at commit time, saving the entire incident chain.

Design constraints:
1. **Zero external dependency** — match the existing hook style (pure bash). Consumers should get protection from `fw upgrade` without installing third-party binaries.
2. **Optional escalation** — if `gitleaks` is on PATH, run it as a strong second pass; otherwise rely on the baseline regex set.
3. **Allowlist for known false-positives** — a `.secret-scan-allowlist` file (one regex per line) suppresses matches.
4. **Bypass via Tier 0** — `git commit --no-verify` skips the check; existing bypass-log captures it.

Surface to add:
- `agents/git/lib/secret-scan.sh` — scanning logic (pure bash + grep), invoked by the new pre-commit hook
- `agents/git/lib/hooks.sh` — install a new `pre-commit` hook alongside `commit-msg`, `post-commit`, `pre-push`
- `.secret-scan-patterns` — repo-tracked pattern catalogue (TSV `name<TAB>regex`)
- `.secret-scan-allowlist` — repo-tracked allowlist for known FPs
- `tests/unit/test_secret_scan.bats` — pins all pattern detections + allowlist behaviour

Origin: T-1828 Layer-3 discovery (mitigated symptom, root-cause-class unfixed) → autonomous-burst directive "focused remediation and future prevention" 2026-05-15.

## Acceptance Criteria

### Agent
- [x] `agents/git/lib/secret-scan.sh` exists, has `scan_staged` function that reads `git diff --cached -U0` output, runs the pattern catalogue, returns 0 if clean / 1 if matches, prints offending file:line + pattern name for each hit.
- [x] `agents/git/lib/secret-scan.sh` honours `.secret-scan-allowlist` — lines matching any allowlist regex are excluded from "match" verdict.
- [x] `agents/git/lib/secret-scan.sh` `scan_staged` runs optional `gitleaks` binary if on PATH, treats any gitleaks finding as a match too (escalation layer).
- [x] `.secret-scan-patterns` exists at repo root with at least 6 pattern entries (Azure DevOps PAT, AWS Access Key, GitHub PAT, SSH Private Key, JWT Bearer, Slack token) — TSV `name<TAB>regex` — 11 entries shipped.
- [x] `.secret-scan-allowlist` exists at repo root, populated with regexes that suppress KNOWN-OK matches.
- [x] `agents/git/lib/hooks.sh` `install_hooks` writes a new `pre-commit` hook that invokes the scanner; hook fails on match with explanation (file:line, pattern name, bypass note).
- [x] `bin/fw git install-hooks` after change installs all 4 hooks (`commit-msg`, `pre-commit`, `post-commit`, `pre-push`).
- [x] `tests/unit/test_secret_scan.bats` pins: (a) Azure DevOps PAT blocked, (b) AWS key blocked, (c) clean diff allowed, (d) allowlisted match allowed, (e) `--no-verify` bypass works, (f) SSH private key blocked, (g) scanner finds patterns file in framework OR consumer (`.agentic-framework/`) layout — 12 cases, all passing.
- [x] `bash -n` on both modified files.

### Human
- [ ] [REVIEW] Confirm pattern catalogue is right — covers the canonical leak classes without prohibitive false-positives in this repo (docs, spikes, tests).
  **Steps:**
  1. `cd /opt/999-Agentic-Engineering-Framework && cat .secret-scan-patterns`
  2. `cd /opt/999-Agentic-Engineering-Framework && bin/fw git install-hooks`
  3. `cd /opt/999-Agentic-Engineering-Framework && agents/git/lib/secret-scan.sh scan-tree 2>&1 | head -30` — runs against the whole working tree to surface any pre-existing matches we'd need to allowlist
  4. Review matches: real leak (separate incident) / false positive (add to allowlist) / pattern too broad (edit `.secret-scan-patterns`)

  **Expected:** Pattern catalogue is sensible, allowlist captures known-OK matches, fresh commits pass through.
  **If not:** Note specific FPs / FNs; the catalogue is editable via `.secret-scan-patterns` without touching the scanner.

## Verification

bash -n agents/git/lib/secret-scan.sh
bash -n agents/git/lib/hooks.sh
test -f .secret-scan-patterns
test -f .secret-scan-allowlist
grep -q "Azure DevOps PAT" .secret-scan-patterns
grep -q "AWS Access Key" .secret-scan-patterns
grep -q "SSH Private Key" .secret-scan-patterns
bats tests/unit/test_secret_scan.bats
test -f .git/hooks/pre-commit
grep -q "secret-scan" .git/hooks/pre-commit

## RCA

**Symptom:** An Azure DevOps PAT was committed to framework history at `79e3361d` (T-1736 Spike B, 2026-05-05). The secret reached OneDev origin (internal). GitHub mirror blocked since 2026-05-14T16:00 by GH013 push protection (28+ consecutive failures over 9+ hours). Consumers cloning from GitHub stuck at `9d52cee27`. Diagnosis took a consumer pickup from Penelope (010-termlink) + a Layer-3 escalation to surface the actual cause.

**Root cause:** No structural gate prevents secrets from being committed. The framework has commit-msg (task-ref) and pre-push (VERSION/audit) hooks, but no content scanner. A spike harvester (T-1736) pulled session JSONLs from outside `PROJECT_ROOT` — one of those harvested sessions contained a real Azure-class credential — and the commit landed without question.

**Why structurally allowed:**
1. The framework's hook portfolio is intentionally pure-bash, zero-dep — adding a secret scanner felt like it required a third-party tool (gitleaks, detect-secrets) and would break the "consumers get protection just from `fw upgrade`" property. So the gate was never built. The cost of "do nothing" was invisible until a real PAT got pushed.
2. Spike tooling (T-1736 harvester) violated path-isolation — walked outside `PROJECT_ROOT` into `/root/.claude/...` session logs. T-1833 inception filed for the path-isolation fix but no decision yet. The harvester wouldn't have created the leak if it stayed inside PROJECT_ROOT.
3. The framework's own dogfood property masks the gap: framework agents don't routinely write secrets to source files, so internal use never exercised the leak class. Consumer projects with real auth tokens / API keys are the ones who'd benefit from the gate — exactly the same shape as T-1842 (framework-blind to consumer-only file shapes).

**Prevention:**
1. **Pre-commit secret scan** (this task) — pure-bash regex catalogue + optional gitleaks escalation. Blocks the commit before it can leak. Ships via `fw upgrade` to every consumer. Closes the class at the cheapest possible boundary.
2. **Pattern catalogue is repo-tracked** (`.secret-scan-patterns`) so it can be edited as new leak classes surface, without touching scanner code. The DRY pattern from T-1842 applies: one scanner, many patterns.
3. **Allowlist is repo-tracked** (`.secret-scan-allowlist`) so false-positives don't become "everybody runs --no-verify habitually" — bypass is one regex line, not a workflow break.
4. **Future: path-isolation in spike tooling** (T-1833) — separate but related. Prevention layer 1 in this task closes the leak even if the harvester misbehaves; layer 2 (T-1833) closes the harvester's misbehaviour.

What the prevention does **not** cover:
- The existing leak at `79e3361d` — that needs T-1834 (filter-repo, Tier 0) for retroactive cleanup. This task is forward-only.
- Mirror-failure paging — separate gap (B from T-1843 captures stderr but no alert fires). Layer 4 in the prevention plan.
- Secret rotation — external action; framework only catches at commit boundary, not at "this token has leaked, rotate it".

## Evolution

### 2026-05-15 — fits project-shape-resilience arc retroactively
- **What changed:** Same class as T-1842 (fabric exclude blindness) and T-1843 (smarter monotonicity hook): the framework's protection is built for the framework's own narrow shape (no node_modules, no tag-counter reset that crosses a major-tag boundary, no real auth secrets in source files). Consumer shapes have all three. This task closes the "no real auth secrets" assumption.
- **Plan impact:** Tag `arc:project-shape-resilience` (set via `--add-tag`). Triggers Evolution gate (this section).
- **Triggered:** No new tasks — RCA `Prevention` already references T-1833 (path-isolation in harvesters) and T-1834 (retroactive cleanup), both pre-existing.

## RCA-suppressed-marker

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

## Recommendation

**Recommendation:** GO — ship the pre-commit secret-scan hook.

**Rationale:** This is the structural root-cause fix for the T-1828/T-1834 leak class. The framework had no gate against secrets reaching commits; this gate sits at the cheapest possible boundary (pre-commit, before the commit even exists). It's pure-bash + zero-dep (matching the existing hook style), ships via `fw upgrade` to every consumer, and the pattern catalogue is editable without code changes. The allowlist mechanism prevents `--no-verify` from becoming habitual on false positives.

This does NOT unstick the current GitHub mirror — the secret at `79e3361d` is still in history. T-1834 (Tier 0, filter-repo) is the retroactive cleanup. T-1833 (inception) addresses the harvester that pulled the secret in in the first place. This task closes the *forward* leak class — the next harvester misbehaviour or careless commit won't reach origin.

**Evidence:**
- All 12 bats tests pass (`tests/unit/test_secret_scan.bats`): AWS, GitHub PAT, SSH, Anthropic detected; clean allowed; allowlist suppresses; `--no-verify` bypasses; consumer `.agentic-framework/` layout resolved.
- `bin/fw git install-hooks` after change installs 4 hooks (`commit-msg` v1.9, `pre-commit` v1.0, `post-commit` v1.6, `pre-push` v1.4) — commit-msg VERSION bump propagates to consumers on next `fw upgrade`.
- `scan-tree` on current working tree: 0 unsuppressed findings (with allowlist tuned for vendored copies + node_modules + a tracked 36MB PostScript file that turned out to be the noisiest source — separate concern flagged for follow-up).
- `git grep -nIE` used in audit mode: handles binary skip + path filtering natively, no per-file fork — scan-tree of ~1000 tracked files completes in <60s.

**Origin:** T-1828 Layer-3 discovery (B fix from T-1843 surfaced GH013 secret-protection block) → autonomous-burst directive 2026-05-15 "focused remediation and future prevention" → this task.

## Decisions

### 2026-05-15 — pure-bash baseline vs gitleaks-dependency
- **Chose:** Pure-bash regex catalogue as baseline, optional `gitleaks` escalation if installed.
- **Why:** The framework's existing hooks (commit-msg, post-commit, pre-push) are zero-dep — consumers get them automatically via `fw upgrade` without needing to install third-party tools. Requiring gitleaks would break that property AND mean any consumer host without gitleaks has NO protection. Pure-bash baseline = every consumer is protected by default; gitleaks-when-available = strong second pass for hosts that want it.
- **Rejected:** (a) Require gitleaks as a hard dependency — breaks zero-dep property + creates a fleet-wide install burden. (b) Defer until gitleaks is shipped via `fw vendor` — moves the goalposts; we need protection now, not after a packaging decision. (c) Ship only the optional gitleaks path with no baseline — same as (a) effectively.

### 2026-05-15 — pattern alphabet tightening
- **Chose:** Azure DevOps PAT pattern `[a-z2-7]{52}` (base32 lowercase) instead of `[A-Za-z0-9]{52}`.
- **Why:** Real Azure DevOps PATs are base32 (lowercase a-z + digits 2-7). The broader pattern produced massive false-positives in the tracked 36MB PostScript file (`./os`) and in node_modules integrity hashes. Tighter pattern → ~zero false positives in our tree, still catches the actual PAT shape.
- **Rejected:** Even broader patterns (entropy thresholds, generic high-entropy detector) — would catch a long tail but produce noise that drives `--no-verify` habit. The catalogue is repo-tracked so additional patterns can be added as new leak classes surface.

## Decisions-old
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

### 2026-05-15T07:04:44Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1844-pre-commit-secret-scan-hook--root-cause-.md
- **Context:** Initial task creation

### 2026-05-15T07:07:18Z — status-update [task-update-agent]
- **Change:** tags: +bug

### 2026-05-15T07:07:18Z — status-update [task-update-agent]
- **Change:** tags: +arc:project-shape-resilience

### 2026-05-15T07:07:18Z — status-update [task-update-agent]
- **Change:** tags: +security
