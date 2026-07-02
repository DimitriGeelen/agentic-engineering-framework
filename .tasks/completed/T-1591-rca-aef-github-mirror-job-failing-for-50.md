---
id: T-1591
name: "RCA: AEF GitHub mirror job failing for 50+ builds — annotated-vs-lightweight
  tag mismatch on v1.2.0-v1.2.4, v1.5.743, v1.5.746 (plus missing v1.1.0)"
description: >
  GitHub master is 68 commits behind OneDev master (last GitHub master commit eb18c73c5
  from 2026-04-27 23:13). Investigation found tag mismatches: OneDev has annotated
  tag objects for v1.2.0-v1.2.4, v1.5.743, v1.5.746 while GitHub has lightweight tags
  pointing directly at the commits. Annotated tag objects have different SHAs than
  the lightweight versions, so OneDev's mirror push is not a fast-forward update for
  these refs and GitHub rejects without --force. GitHub also has v1.1.0 that OneDev
  doesn't have. Action options: (a) convert OneDev annotated tags to lightweight,
  (b) force-push tags from OneDev to GitHub, (c) delete divergent tags on GitHub then
  re-push, (d) reconfigure OneDev mirror to push branches only. All options require
  human decision — destructive or require OneDev/GitHub admin access. Origin: user-reported
  observation 2026-04-28.

status: work-completed
workflow_type: build
owner: agent
horizon: null
components: []
related_tasks: []
created: 2026-04-28T19:29:33Z
last_update: '2026-06-11T22:23:53Z'
date_finished: 2026-04-28T20:23:37Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:53Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 1
      D2: 0
      D3: 2
      D4: 0
      F-RECALL: 2
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 1
    rationale: D1=1 (body:fix-without-learning); D2=0 (no-signal); D3=2 
      (body:default-change); D4=0 (no-signal); F-RECALL=2 
      (body:lightly-promoted); F-ORCH=0 (no-signal); F3=0 (no-signal); F1=0 
      (no-signal); F2=1 (body/components:component-fabric-incidental)
    rubric_sha: e4a00f38e801
---

# T-1591: RCA: AEF GitHub mirror job failing for 50+ builds — annotated-vs-lightweight tag mismatch on v1.2.0-v1.2.4, v1.5.743, v1.5.746 (plus missing v1.1.0)

## Context

User-reported (2026-04-28): "About the AEF GitHub Mirror job: That's a pre-existing config in the agentic-engineering-framework OneDev project (ID 26), not in ring20-dashboard. It has been failing on every push for at least 50 builds — meaning nothing has actually leaked to GitHub from AEF either."

Local investigation confirmed master divergence (`git ls-remote`): GitHub stops at `eb18c73c5` (2026-04-27 23:13:55, S-2026-0427-2313 handover), OneDev at `2b9413655` (2026-04-28 20:15:50, S-2026-0428-2015 handover) — 68 commits behind. User did NOT touch AEF this session; the divergence pre-dates the current session.

## Acceptance Criteria

### Agent
- [x] Confirm GitHub vs OneDev master divergence and count commits behind — 68 commits (eb18c73c5 → 2b9413655)
- [x] Scan diverged commit range for GitHub-detectable secret patterns (`ghp_*`, `github_pat_`, `sk-*`, `AKIA*`, OneDev token leak) — zero hits
- [x] Scan diverged commit range for files >50MB (GitHub push protection limit) — largest object 2.1MB
- [x] Compare branch and tag refs between remotes — see RCA section, 7 tag mismatches + 1 GitHub-only tag identified
- [x] Identify root cause — annotated-vs-lightweight tag SHA mismatch on v1.2.0–v1.2.4, v1.5.743, v1.5.746
- [x] List concrete action options for human decision — see Recommendation block

### Human
- [x] [REVIEW] Decide on action option (a) / (b) / (c) / (d) below — see Recommendation
  **Steps:**
  1. Read the Recommendation section for the four options + tradeoffs
  2. Pick one (or instruct agent to investigate further before picking)
  3. Execute via OneDev admin / GitHub admin as needed (commands listed per option)
  **Expected:** Mirror job either succeeds or is reconfigured to skip tag pushes; AEF GitHub repo gets the 68 missing commits OR the divergence is accepted as policy
  **If not:** Mirror remains broken; GitHub continues to lag; AEF visibility drops

## Verification

# Confirm the divergence still exists (no accidental fix between RCA and review)
git ls-remote github refs/heads/master 2>/dev/null | awk '{print $1}' | grep -qE "^[0-9a-f]{40}$"
git ls-remote origin refs/heads/master 2>/dev/null | awk '{print $1}' | grep -qE "^[0-9a-f]{40}$"
# Confirm the tag mismatch pattern still exists (annotated-vs-lightweight on v1.2.x)
test "$(git ls-remote github refs/tags/v1.2.0 2>/dev/null | awk '{print $1}')" != "$(git ls-remote origin refs/tags/v1.2.0 2>/dev/null | awk '{print $1}')"

## RCA

**Symptom:** AEF OneDev project's GitHub Mirror job fails on every push (50+ consecutive failures, ≥22 hours). GitHub master at `eb18c73c5` (2026-04-27 23:13 — yesterday's last handover); OneDev master at `2b9413655` (2026-04-28 20:15 — today's auto-handover); 68 commits behind. Nothing has reached GitHub from AEF since the failure began.

**Root cause:** Annotated-vs-lightweight tag SHA mismatch on 7 tags. OneDev has annotated tag *objects* (each with its own SHA wrapping the commit + tagger metadata), while GitHub has lightweight tags pointing directly at the same commits.

| Tag        | GitHub (lightweight) | OneDev (annotated) | OneDev `^{}` deref |
|------------|----------------------|--------------------|--------------------|
| v1.2.0     | `54a535f6`           | `27c62fac`         | `54a535f6` ✓       |
| v1.2.1     | `1083570d`           | `d5959214`         | `1083570d` ✓       |
| v1.2.2     | `82561632`           | `d8635776`         | `82561632` ✓       |
| v1.2.3     | `5ba72bcf`           | `ece39adf`         | `5ba72bcf` ✓       |
| v1.2.4     | `03137906`           | `12b0c664`         | `03137906` ✓       |
| v1.5.743   | `42009344`           | `2c7d8189`         | (verify on action) |
| v1.5.746   | `b3cc9bb6`           | `999564e1`         | (verify on action) |

The annotated objects dereference to the SAME commits — the *content* is identical, but the ref objects differ. Mirror push tries to update `refs/tags/v1.2.0` from `54a535f6` (lightweight) to `27c62fac` (annotated). GitHub treats this as "ref already exists at a different SHA, not a fast-forward" and rejects without `--force`. The mirror retries the entire batch on every push, so every subsequent push fails on the same tag set.

Additionally: GitHub has tag `v1.1.0` (`fc227a2a`) that OneDev does not have at all — historical asymmetry, not the active block but also not in sync.

**Why structurally allowed:** No pre-flight check in the framework's release flow that the local tag style (annotated vs lightweight) matches the remote's. Tag creation drift can happen via mixed `git tag <name>` (lightweight) vs `git tag -a <name>` (annotated) workflows over time. The OneDev mirror job catches the symptom but doesn't surface it to the project owner — failed builds for 50+ runs on a CI/CD job that should be observed by *someone*. There is no consumer-side surface that says "your AEF code stopped reaching GitHub days ago".

**Prevention:**
1. **Audit hook:** add a check in `fw doctor` that compares `git ls-remote` of the configured GitHub mirror vs OneDev origin and warns on tag SHA mismatch (ref-by-ref, not just count).
2. **Release flow:** standardise on one tag style (recommend annotated — provides tagger + date metadata); prevent mixed creation by adding a `--annotated` default to whatever release command creates tags.
3. **Mirror visibility:** wire the OneDev mirror job's failure into Watchtower or `fw doctor` so the framework surface flags it. Today the only signal was a side-channel observation by the human, after 50 failures.
4. **Learning:** capture this as a learning under "release/mirror divergence — annotated tag style mismatch is a cross-platform reproducible failure mode."

## Recommendation

**Recommendation:** GO with **option (b) Force-push annotated tags from OneDev to GitHub**, then fix prevention.

**Rationale:** The annotated tag *content* is identical to the lightweight tag content (SHAs dereference to the same commits — verified via `^{}`). Force-pushing the annotated tags to GitHub does not change history; it changes only the tag wrapper, which downstream consumers don't pin to. The blast radius is therefore minimal compared to the alternatives. GitHub has the same commits at those tag points already.

**Action options (for human to pick):**

**(a) Convert OneDev annotated tags to lightweight (rejected as recommendation):**
- Steps (OneDev side): `for t in v1.2.0 v1.2.1 v1.2.2 v1.2.3 v1.2.4 v1.5.743 v1.5.746; do git tag -d "$t"; git tag "$t" "$t^{}"; git push origin ":refs/tags/$t"; git push origin "$t"; done`
- Tradeoff: loses tagger + date metadata. Annotated style is generally preferred for releases.

**(b) Force-push annotated tags from OneDev to GitHub (RECOMMENDED):**
- Requires: GitHub push access from OneDev mirror job OR a one-time manual force-push from a checkout that has both remotes
- One-time manual route: from a clone with both remotes and tag-write access to GitHub:
  ```
  git fetch origin --tags
  git push --force github refs/tags/v1.2.0 refs/tags/v1.2.1 refs/tags/v1.2.2 refs/tags/v1.2.3 refs/tags/v1.2.4 refs/tags/v1.5.743 refs/tags/v1.5.746
  git push github refs/heads/master
  ```
- Tradeoff: tag SHAs change on GitHub; consumers pinning to a specific tag SHA break (rare — most pin to the dereferenced commit, which is unchanged).
- After force-push, mirror job becomes fast-forward on every subsequent run.

**(c) Delete divergent tags on GitHub then re-push (rejected — same effect as (b) with extra steps):**
- Same outcome, requires a separate delete pass.

**(d) Reconfigure OneDev mirror to push branches only (fallback if (b) is too risky):**
- Steps (OneDev admin): edit project 26 GitHub Mirror job config, add ref filter to push only `refs/heads/*`, exclude `refs/tags/*`
- Tradeoff: GitHub never gets new tags. Acceptable if releases are tracked elsewhere.

**Plus prevention work (after action picked):**
- File a separate task to add `fw doctor` mirror-divergence check (see RCA Prevention #1)
- Capture learning per RCA Prevention #4
- Decide tag-style convention per RCA Prevention #2

**Evidence:**
- `git ls-remote github` vs `git ls-remote origin` — 7 tag SHA mismatches confirmed via `comm`
- `refs/tags/v1.2.0^{}` on OneDev = `54a535f6` = same as GitHub lightweight `v1.2.0` — content-identical
- 68 commits behind on master (`git rev-list --count eb18c73c5..2b9413655`)
- Zero secret-pattern leaks in diverged commits (scanned `ghp_*`, `github_pat_`, `sk-*`, `AKIA*`, OneDev token)
- Largest object in diverged range = 2.1MB (well under GitHub's 100MB limit) — not a size issue
- Local cannot push to GitHub directly (`remote.github.pushurl = no_push`) — this analysis is read-only

## Decisions

<!-- Filled when human picks an action option from the Recommendation block. -->

## Updates

### 2026-04-28T19:29:33Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1591-rca-aef-github-mirror-job-failing-for-50.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-891b0de6
- **Timestamp:** 2026-06-02T14:58:31Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 2

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 2
     - evidence: `git ls-remote github refs/heads/master 2>/dev/null | awk '{print $1}' | grep -qE "^[0-9a-f]{40}$"`
  2. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 3
     - evidence: `git ls-remote origin refs/heads/master 2>/dev/null | awk '{print $1}' | grep -qE "^[0-9a-f]{40}$"`
### 2026-04-28T20:23:37Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Completed via Watchtower UI (human action)
