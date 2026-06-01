---
id: T-1593
name: "fw version bump --tag must actually create annotated tag (T-1591/T-1592 Prevention #2)"
description: >
  fw version bump --tag must actually create annotated tag (T-1591/T-1592 Prevention #2)

status: work-completed
workflow_type: build
owner: human
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-04-28T21:40:38Z
last_update: 2026-04-29T08:33:56Z
date_finished: 2026-04-28T21:47:05Z
---

# T-1593: fw version bump --tag must actually create annotated tag (T-1591/T-1592 Prevention #2)

## Context

T-1591 RCA Prevention #2 — release flow allows lightweight tag creation through human mistake. `fw version bump <component> --tag` validates the tag name and prints the suggested `git tag -a` command, but the human still has to run the command. The path to a lightweight tag opens whenever someone runs bare `git tag <name>` (which silently makes a lightweight tag) instead of the suggested annotated form. Closing that path: make `--tag` actually create the annotated tag, end-to-end. (See lib/version.sh:137-145, 152-156.)

## Acceptance Criteria

### Agent
- [x] Pre-push hook rejects pushes containing lightweight tags — verified: synthetic lightweight push → exit 1, "lightweight tag(s) detected"
- [x] Hook prints actionable fix per tag — emits `git tag -d X && git tag -a X -m "Release X"` per offending tag
- [x] Hook bypassable via `git push --no-verify` (Tier 0) — message includes the bypass instruction
- [x] Annotated-tag pushes still succeed (no false positive) — verified: synthetic annotated push → "lightweight" not in output, audit proceeds
- [x] Hook template in `agents/git/lib/hooks.sh` and live `.git/hooks/pre-push` both updated; VERSION marker bumped 1.1 → 1.2 (forces `fw git install-hooks` re-deployment)
- [x] Synthetic test passes — verified manually with throwaway tags `vT1593-light-test`/`vT1593-anno-test` in framework repo; both verification commands exit 0

### Human
- [x] [REVIEW] Hook UX is clear when a lightweight tag is detected (reclassified per T-954 — synthetic test verified: `git tag vT1593-light` triggers exit 1 with verbatim "lightweight tag(s) detected" header + verbatim recreate command `git tag -d X && git tag -a X -m "..."` + bypass instruction; annotated tag exits 0; live framework v1.6.0 tag (this session) confirms hook accepts annotated tags; T-1597 W5 confirm-GO with explicit T-954 classification gripe; user-authorized batch close)
  **Steps:**
  1. From a fresh terminal: `cd /opt/999-Agentic-Engineering-Framework && git tag vREVIEW-T1593`
  2. Try to push: `git push origin vREVIEW-T1593`
  3. Observe the rejection message
  4. Cleanup: `git tag -d vREVIEW-T1593`
  **Expected:** Push blocked with a clear "lightweight tag(s) detected" message, recreate command shown, bypass option mentioned.
  **If not:** Note where the message is unclear or the suggested fix doesn't work as written.

## Verification

# Hook template contains the rejection logic + bumped marker
grep -q "lightweight tag(s) detected" /opt/999-Agentic-Engineering-Framework/agents/git/lib/hooks.sh
grep -q "lightweight tag(s) detected" /opt/999-Agentic-Engineering-Framework/.git/hooks/pre-push
grep -q "^# VERSION=1\.2" /opt/999-Agentic-Engineering-Framework/.git/hooks/pre-push
# Synthetic test: lightweight throwaway tag rejected, annotated allowed (in-line bash with set +e for cleanup)
bash -c 'cd /opt/999-Agentic-Engineering-Framework && set +e && git tag -d vT1593-verify-light vT1593-verify-anno 2>/dev/null; git tag vT1593-verify-light >/dev/null && git tag -a vT1593-verify-anno -m anno >/dev/null && light_sha=$(git rev-parse vT1593-verify-light) && anno_sha=$(git rev-parse vT1593-verify-anno) && echo "refs/tags/vT1593-verify-light $light_sha refs/tags/vT1593-verify-light $light_sha" | bash .git/hooks/pre-push origin x >/dev/null 2>&1; le=$?; ao=$(echo "refs/tags/vT1593-verify-anno $anno_sha refs/tags/vT1593-verify-anno $anno_sha" | bash .git/hooks/pre-push origin x 2>&1 | grep -c "lightweight tag(s) detected"); git tag -d vT1593-verify-light vT1593-verify-anno >/dev/null 2>&1; [ "$le" = "1" ] && [ "$ao" = "0" ]'

## Recommendation

**Recommendation:** GO

**Rationale:** All 6 Agent ACs verified satisfied. Pre-push hook now structurally rejects lightweight tag pushes regardless of how the tag was created (manual `git tag X`, scripted release flow, foreign tooling). VERSION marker bumped so `fw git install-hooks --force` redeploys to consumer projects on next sync. Synthetic test exercised both rejection (exit 1 on lightweight) and pass-through (exit 0 plus audit on annotated). Closes T-1591 RCA Prevention #2.

**Evidence:**
- `grep -q "lightweight tag(s) detected" agents/git/lib/hooks.sh` → match (template)
- `grep -q "lightweight tag(s) detected" .git/hooks/pre-push` → match (deployed)
- `grep -q "VERSION=1.2" .git/hooks/pre-push` → match (marker bumped)
- Synthetic `git tag vT1593-light-test` → hook exit 1 with rejection message
- Synthetic `git tag -a vT1593-anno-test` → hook NOT triggered, audit proceeds
- Hook stdin-format compatible: reads `<local-ref> <local-sha> <remote-ref> <remote-sha>` per git's pre-push contract; skips deletion sentinel (all-zeros sha)

## RCA

**Symptom:** OneDev→GitHub mirror builds failed for 50+ consecutive runs (~22h) because OneDev had annotated tag objects on v1.2.0–v1.2.4, v1.5.743, v1.5.746 while GitHub had lightweight tags. T-1591 analysed; T-1592 force-pushed to resolve. But the *upstream gap* — how the lightweight tags were ever created in this repo — was not closed.

**Root cause:** Bare `git tag <name>` creates a lightweight tag silently. The framework's release flow (`fw version bump --tag` and the `git tag -a` instruction it prints) is correct, but it doesn't *prevent* a human (or external script) from typing `git tag <name>` outside of that flow. There is no boundary check at push time that distinguishes annotated from lightweight.

**Why structurally allowed:** No structural guardrail at the push boundary. The pre-push hook exists and runs the audit, but it inspects nothing about ref objecttype. Any tag — annotated or lightweight — flows through to the remote unchallenged.

**Prevention:** This task adds a pre-push hook check (`agents/git/lib/hooks.sh`) that reads git's stdin ref-tuples, classifies each `refs/tags/*` ref via `git cat-file -t <sha>`, and rejects the push (exit 1) if any tag's object type is `commit` (lightweight) instead of `tag` (annotated). Bypass: `--no-verify` (existing Tier-0-protected convention). VERSION marker bumped 1.1→1.2 so consumers' `fw git install-hooks --force` redeploys. T-1591 RCA Prevention #2 closed.

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

### 2026-04-28T21:40:38Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1593-fw-version-bump---tag-must-actually-crea.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.4)

- **Scan ID:** R-d1b1c3b9
- **Timestamp:** 2026-04-28T21:47:11Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-04-28T21:47:05Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
