---
id: T-1843
name: "T-1603 smarter hook + mirror-sync stderr capture (T-1829 build child)"
description: >
  T-1603 smarter hook + mirror-sync stderr capture (T-1829 build child)

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: [bug]
components: [agents/git/lib/hooks.sh, agents/git/lib/secret-scan.sh, 
      lib/mirror.sh, tests/unit/test_mirror_stderr_capture.bats, 
      tests/unit/test_pre_push_monotonic_ancestor.bats, 
      tests/unit/test_secret_scan.bats]
related_tasks: []
arc_id: project-shape-resilience
created: 2026-05-14T23:00:56Z
last_update: '2026-06-11T22:23:26Z'
date_finished: 2026-05-22T08:10:15Z
bvp_scores_proposed:
  - ts: '2026-05-19T18:27:45Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 3
      D3: 0
      D4: 0
    rationale: D1=2 (body:learning-ref); D2=3 (body:component-silent-failure); 
      D3=0 (no-signal); D4=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-05-28T22:54:10Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 3
      D3: 0
      D4: 0
      F1: 0
      F2: 0
    rationale: D1=2 (body:learning-ref); D2=3 (body:component-silent-failure); 
      D3=0 (no-signal); D4=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-11T22:23:26Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 3
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=2 (body:learning-ref); D2=3 (body:component-silent-failure); 
      D3=0 (no-signal); D4=0 (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
cost_estimate_proposed:
  - ts: '2026-05-19T21:45:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1843: T-1603 smarter hook + mirror-sync stderr capture (T-1829 build child)

## Context

Build child of T-1829 (Recommendation D, decided GO 2026-05-14T19:11Z). Implements:
- **C — smarter T-1603 hook:** in pre-push, if `local-VERSION < remote-VERSION` per `sort -V`, fall back to `git merge-base --is-ancestor $_remote_sha $_local_sha`. If the remote sha is an ancestor of local (or remote sha not locally known after a fast `git cat-file -e`), allow. Otherwise block.
- **B — mirror-sync stderr capture:** `lib/mirror.sh:mirror_sync_one` currently does `git push "$remote" "$branch" >/dev/null 2>&1` — stderr is swallowed. Capture stderr into the existing `.context/working/.mirror-sync.log` so the next stall is diagnosable from logs alone (no need to re-run the failing push interactively).

Code surface:
- `agents/git/lib/hooks.sh:368-420` (T-1603 monotonicity check inside the pre-push hook heredoc).
- `lib/mirror.sh:38-76` (`mirror_sync_one`).

The framework has BOTH `origin` (OneDev) and `github` configured as direct remotes — `fw mirror sync` cron pushes to `github` directly, the pre-push hook fires, the monotonicity check blocks on tag-counter reset. Confirmed: `.context/working/.mirror-sync.log` shows 28+ consecutive `github push-failed` rows since `2026-05-14T16:00`, all with `mirror=9d52cee27` (pre-tag), `origin=<advancing tip>`. The smarter hook allows ancestor-forward pushes through and the mirror unsticks itself on the next cron run.

Origin: T-1828 RCA (2nd incident of T-1602 class) → T-1829 inception (GO Candidate D, 2026-05-14T19:11Z) → this build task.

## Acceptance Criteria

### Agent
- [x] `agents/git/lib/hooks.sh` pre-push hook: when `local < remote` per `sort -V`, perform `git merge-base --is-ancestor "$_remote_sha" "$_local_sha"`; if exit 0 → allow (do NOT add to `_block_lines`). Annotate inline with `# T-1829: …`.
- [x] If `_remote_sha` is not locally known (`git cat-file -e` non-zero), fall back to current strict-block behaviour with the same error message — preserves T-1602 real-rollback protection when remote sha was never fetched.
- [x] `lib/mirror.sh:mirror_sync_one` captures `git push` stderr into `.context/working/.mirror-sync.log` on push-failed outcome — appended as a fenced block with timestamp, remote name, and first 20 stderr lines.
- [x] `tests/unit/test_pre_push_monotonic_ancestor.bats` (new) pins three cases against synthetic git repos: (1) local-ancestor-of-remote real rollback → blocked, (2) remote-ancestor-of-local tag-counter forward → allowed, (3) remote sha not locally known → blocked (preserves strict default).
- [x] `tests/unit/test_mirror_stderr_capture.bats` (new) pins that on simulated push-failed, the stderr block appears in `.mirror-sync.log` and contains the simulated error string.
- [x] `bash -n` on both modified files.
- [x] Reinstall hooks via `bin/fw git install-hooks` and confirm new `# VERSION=1.4` in the installed `.git/hooks/pre-push`.

### Human
- [ ] [REVIEW] Confirm the ancestor-check semantics are right — that allowing forward-in-time pushes when remote is ancestor of local doesn't leak any case the T-1602 strict block was catching.
  **Steps:**
  1. `cd /opt/999-Agentic-Engineering-Framework && git diff master -- agents/git/lib/hooks.sh lib/mirror.sh`
  2. Read the `# T-1829:` annotation block in the pre-push hook
  3. Run `cd /opt/999-Agentic-Engineering-Framework && bats tests/unit/test_pre_push_monotonic_ancestor.bats`
  4. Optionally: re-run the next cron tick (`bin/fw mirror sync`) and confirm github advances 9d52cee27 → current origin HEAD.

  **Expected:** Tests pass; if you trigger a mirror cron, github push succeeds (mirror unsticks). Strict-block path still fires on real divergence.
  **If not:** Open a follow-up task; the cron will keep failing until either this lands or the documented `--no-verify` bypass is approved in-conversation.

## Verification

bash -n agents/git/lib/hooks.sh
bash -n lib/mirror.sh
bats tests/unit/test_pre_push_monotonic_ancestor.bats
bats tests/unit/test_mirror_stderr_capture.bats
grep -q "T-1829" agents/git/lib/hooks.sh
grep -q "merge-base --is-ancestor" agents/git/lib/hooks.sh
grep -q "T-1829" lib/mirror.sh

## RCA

**Symptom:** OneDev → GitHub mirror lag (consumer Penelope's offset-12 report, severity HIGH). Local cron `fw mirror sync` push to github has been failing every 15min for 7+ hours and counting (28+ consecutive `push-failed` rows in `.context/working/.mirror-sync.log`). Consumers cloning from GitHub stuck at `9d52cee27` (2026-05-04, T-1725 era) while origin advances normally.

**Root cause:** Two-part — (1) The VERSION stamping algorithm (`git describe --tags --match 'v[0-9]*'` → `<M>.<m>.<commits-since-tag>`) resets the patch counter to 0 at each new annotated tag (`v1.6.2` was created after the last successful github push, dropping stamping from 1.6.260 to 1.6.<small>). (2) The T-1603 pre-push monotonicity hook (origin: T-1602 real-rollback case) uses `sort -V` only — it cannot distinguish "remote is genuinely older but VERSION sorts higher" from "remote diverged with new commits we don't have". Both produce `local < remote`; T-1603 blocks both.

**Why structurally allowed:**
1. T-1603 was designed for the T-1602 real-rollback class and uses the cheapest possible signal (`sort -V`). The signal proxies "monotonicity" but conflates two different semantics — "VERSION number" vs "commit timeline". No prior incident exercised the tag-counter-reset case before v1.6.2 was created.
2. `mirror_sync_one` swallowed `git push` stderr (`>/dev/null 2>&1`), so when the hook fired, the log only recorded "push-failed" with no diagnostic. The actual blocking message ("VERSION monotonicity violation: 1.6.X < 1.6.260") was invisible to anyone reading the log. Took human-reported pickup from a consumer (Penelope offset-12) to surface the cause — would have been visible from the first failed cron tick if stderr were captured.
3. The framework runs its own mirror cron (`fw mirror sync` via cron-registry) AND the pre-push hook on the SAME repo. The hook can block the cron's own auto-recovery push. T-1594 (mirror auto-recovery) and T-1603 (monotonicity gate) were each designed standalone — their interaction at scale ("hook blocks the recovery") wasn't probed.

**Prevention:**
1. Smarter hook (C): ancestor check distinguishes "remote is older commit" from "remote diverged". The diverged-and-rollback signal that motivated T-1603 is preserved; the legitimate-forward signal that T-1828 surfaced is allowed through. Pinned by `tests/unit/test_pre_push_monotonic_ancestor.bats` case 1 (real rollback still blocked) + case 2 (tag-counter forward allowed).
2. Mirror-sync stderr capture (B): next stall surfaces in `.mirror-sync.log` with the actual error in <15min, not after a consumer pickup. Pinned by `tests/unit/test_mirror_stderr_capture.bats`.
3. This is the SECOND incident of the gate-blocks-legitimate-forward class (T-1602 → T-1603 → T-1828 → T-1843). If a third instance surfaces, it's a signal that `sort -V` is not the right primitive at all — escalate to Candidate A/B (full algorithm change) per T-1829.

What the prevention does **not** cover:
- The OneDev → GitHub mirror path (separate from local cron) — that lives on the OneDev server-side PushRepository job, out of scope here.
- A consumer that doesn't run `fw mirror sync` cron — they'd still see github lag if their direct `git push github` hits the hook. The smarter hook helps them too.

## Evolution

### 2026-05-14 — fits project-shape-resilience arc retroactively
- **What changed:** During RCA drafting it became clear this is the same class as T-1842 (fabric exclude blindness): a gate / reader that conflates two different semantics into one cheap signal, then fires incorrectly on the project-shape it didn't anticipate. T-1842's bug was framework-blindness to `node_modules/`; T-1843's bug is framework-blindness to tag-counter resets. Both are the framework testing on its own narrow shape and missing the broader case.
- **Plan impact:** Tag `arc:project-shape-resilience` post-implementation (set via `bin/fw task update --add-tag arc:project-shape-resilience`). Triggers Evolution gate (this section).
- **Triggered:** No new tasks — RCA `Prevention` already names the escalation path (Candidate A/B) if a third incident of the class surfaces.

### 2026-05-15 — B fix paid off in <1 minute; T-1828 RCA was wrong
- **What changed:** Immediately after landing the B stderr-capture, ran `bin/fw mirror sync` to verify the C fix would unstick the cron. The push still failed — but the captured stderr surfaced the REAL cause: **GitHub server-side secret-scanning push protection (GH013)** rejecting a previously-committed Azure DevOps PAT at `.context/spikes/T-1736-prompts.jsonl:145-146` in commit `79e3361d`. The T-1828 RCA's attribution to the T-1603 monotonicity hook was incorrect — the hook may also be a problem for some commits, but the IMMEDIATE blocker is server-side at GitHub, not local. `git push --no-verify` would not have helped here (it skips local hooks; GitHub still rejects).
- **Plan impact:** The C fix remains valid prevention for the class T-1829 named (tag-counter reset will hit again at v1.7.x), but does NOT unstick the current mirror. The real unstick path is either (a) GitHub secret-scanning allow-list, (b) history rewrite via filter-repo (T-1834, Tier 0 blocked), or (c) secret rotation + allow-list. None of these are delegated by autonomous-burst directive.
- **Triggered:**
  - T-1828's Recommendation needs human re-review — the proposed `--no-verify` bypass does not address the actual rejection.
  - L-379 captured: framework agents' RCA-on-symptoms-without-stderr is unreliable. Stderr capture in any retry-loop infrastructure (mirror, cron, dispatch) should be considered baseline, not optional. The "5 hours of silent failure" measured in T-1828 RCA was actually "5 hours of failure with the cause already in the failing output, which we discarded".
  - L-378 (never quote secret values in chat) applied — the GitHub error gave the location, not the value; this entry refers to the location only.
- **Evidence:** `.context/working/.mirror-sync.log` now contains the captured GitHub server-side rejection block from `2026-05-14T23:07:36Z` — first time the actual cause has been visible to the framework agent.

## Recommendation

**Recommendation:** GO — ship the C+B fix.

**Rationale:** The structural prevention is sound — C closes the tag-counter-reset class T-1829 documented, B closes the observability gap (proved its value in <1min by surfacing the real cause of the current mirror stall). The C fix is independently valuable even though it does NOT unstick the current mirror — the current mirror is blocked at GitHub server-side, not at the local hook. Without C, the next v1.7.X tag would have hit the T-1828 class again; with C in place, that class is closed structurally.

The current mirror unstick is a SEPARATE problem (server-side secret push protection) — needs T-1834 (filter-repo) or secret allow-list, both Tier-0 / human-authority. T-1828's Recommendation block should be re-reviewed by the human now that the actual cause is known (B's stderr capture is the evidence — see `.context/working/.mirror-sync.log` block dated `2026-05-14T23:07:36Z`).

**Evidence:**
- All 17 affected bats tests pass: `tests/unit/test_pre_push_monotonic_ancestor.bats` (7/7), `tests/unit/test_mirror_stderr_capture.bats` (4/4), `tests/unit/pre_push_version_monotonicity.bats` (6/6 — 2 converted to "now allowed", 4 unchanged).
- Hook reinstalled locally at `.git/hooks/pre-push` v1.4 with T-1829 ancestor check.
- B fix paid off in <1 minute: first cron simulation after landing surfaced GitHub GH013 secret-protection error block in mirror-sync.log (previously invisible — would have been "push-failed" with no diagnostic).
- T-1602 protection preserved: `test_pre_push_monotonic_ancestor.bats:case 2` pins the actual cc38e98f5 incident shape (HEAD reset → local-is-ancestor-of-remote) as still blocked.
- DRY note: existing `pre_push_version_monotonicity.bats` updated with annotation pointing at the new test file as the source of truth for the HEAD-reset case.

**Origin:** T-1829 inception GO Candidate D (2026-05-14T19:11Z) → this build task. Surfaced indirectly via Penelope (010-termlink) offset-12 pickup → T-1828 RCA → T-1829 inception.

## Decisions

### 2026-05-14 — update existing tests vs add new ones
- **Chose:** Update `pre_push_version_monotonicity.bats` to convert 2 "forward-downgrade blocked" tests to "forward-downgrade allowed (T-1829)", keep the others. Add new `test_pre_push_monotonic_ancestor.bats` covering all the new C-semantics cases including the actual cc38e98f5 HEAD-reset shape.
- **Why:** The old tests pinned the OLD strict-sort-V behaviour. Under T-1829 C, that behaviour deliberately changed — leaving the tests as-is would be testing for a behaviour the GO decision retired. Adding inline annotations + cross-link makes the regime change discoverable.
- **Rejected:** (a) deleting the 2 obsolete tests — loses the audit trail of what semantics changed; (b) leaving them failing — would mask real regressions; (c) marking with `skip` — equivalent to deletion without the rationale.

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-05-14T23:00:56Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1843-t-1603-smarter-hook--mirror-sync-stderr-.md
- **Context:** Initial task creation

### 2026-05-14T23:02:45Z — status-update [task-update-agent]
- **Change:** tags: +bug

### 2026-05-14T23:09:13Z — status-update [task-update-agent]
- **Change:** tags: +arc:project-shape-resilience

## Reviewer Verdict (v1.5)

- **Scan ID:** R-e639ea27
- **Timestamp:** 2026-06-11T12:12:58Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-05-22T08:10:15Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
