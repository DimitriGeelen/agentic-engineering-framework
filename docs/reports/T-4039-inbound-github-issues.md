# T-4039: Inbound GitHub issue lifecycle

**Status:** inception (research artifact, C-001). Filed 2026-10-10.
**Origin:** Operator, 2026-10-10. The first outside user of the framework, GitHub user **MikeEchoVoid**, has filed bugs and enhancement requests. There is no structured way to ingest them, decide on them, or tell the submitter what happened.

## Current state (measured 2026-10-10)

- The repo is `DimitriGeelen/agentic-engineering-framework` on GitHub, with issues enabled.
- **MikeEchoVoid filed #86–#94 on 2026-10-07:** 7 bugs and 2 enhancements, none commented on 3 days later.
  - They are high quality: exact files and lines, the version observed, steps to reproduce, and what was and was not verified.
  - Example: #86, the greenfield T-002 seed fails the inception schema gate after T-3948. It names lib/init.sh:714 and the missing backfill.
- **#85 (reflectme-source, 2026-10-05):** an outside proposal, also unanswered.
- The remaining open issues are our own (DimitriGeelen), filed by agents through `fw upstream`.
- **Outbound only.** `lib/upstream.sh` (T-451/T-454) lets field installations *create* issues. Nothing in the framework reads issues, comments on them, or links them to tasks.

## The lifecycle

| # | Stage | What happens | What the submitter sees on the issue |
|---|---|---|---|
| 1 | **Ingest** | A scheduled sync reads new and updated issues into a ledger (`.context/issues/`); one record per issue: number, author, title, body hash, labels, state, linked task, stage. | Comment: **Received.** "Ingested as INTAKE-NNN on <date>. Next: classification." |
| 2 | **Classify** | An agent classifies each issue, using the fabric to find components and the task corpus to find duplicates:<br>- type: bug, enhancement, question, proposal or duplicate;<br>- affected component;<br>- severity;<br>- whether it reproduces on the current release and on bleeding-edge;<br>- duplicate of an existing task or issue? | Label(s) plus a comment: **Classified.** Type, area and severity, and "awaiting maintainer decision". |
| 3 | **Decide** | The issue is served to the operator with the classification and a recommendation:<br>- accept → a task;<br>- needs more info;<br>- duplicate of T-XXXX;<br>- not planned (with reason). | — |
| 4 | **Respond** | The operator's decision is posted. | Comment: **Accepted** (tracked as T-XXXX, horizon), **Needs info** (the exact question), **Duplicate** (link) or **Not planned** (reason). |
| 5 | **Task** | Accepted → a task with `github_issue: <n>` in frontmatter, linked both ways. | (part of 4) |
| 6 | **In development** | The task moves to started-work. | Comment: **In progress.** |
| 7 | **Fixed on bleeding-edge** | The task closes; the fixing commit(s) are on bleeding-edge. | Comment: **Fixed on bleeding-edge** (commit), "will ship in the next release; we may ask you to try a pre-release". |
| 8 | **In a pre-release** | A T-4023 bleeding-edge pre-release (`-be`) contains it. | Comment: **Available for testing in vX.Y.Z-be.N**, plus a request: "does this fix it for you?" The submitter is a field reporter: their confirmation is the strongest evidence T-4023 can get. |
| 9 | **Released** | The change reaches master in a release. | Comment: **Released in vX.Y.Z.** The issue is closed. |

**Stage 9 is posted by the release (T-4340):** a release posts stage 9 per the close rule — Released with its evidence block for each task in the range that carries `github_issue:`; closed when the field report has a WORKS row for it, otherwise "please confirm" with a 14-day due date that `fw issues sweep` (also run by sync) closes unless the submitter replied.

Every comment uses one fixed, machine-readable template: a stage marker, the date, the task id and a link. The sync can then read back the stage the issue is in, and the submitter sees a consistent record.

Every stage comment ends with the same footer (operator, 2026-10-10): *"These status updates are automated, but Dimitri personally looks at every issue and decides what happens to it. Replies on this issue are read."*

**Routing rule (operator, 2026-10-10):** every issue by GitHub user **MikeEchoVoid** goes to arc `mikeechovoid-requests` (arc-021) with horizon `now`. "Prioritise all the requests from Mike." The intake pipeline sets `arc_id:` and `horizon: now` on the task it creates for any accepted MikeEchoVoid issue.

**First batch, 2026-10-10:**
- Received was posted on #85–#94 as INTAKE-0001…0010 (ledger: `.context/issues/intake.jsonl`).
- The footer line was added the same day by editing the 10 comments in place.

## Mechanisms

- **Ingest:** a cron job (e.g. every 2 h) running `fw issues sync`. It uses `gh api` with the token already configured for the GitHub mirror and appends only new or changed issues to the ledger.
  - New comments from the submitter, such as answers to "needs info", are picked up and re-surfaced to the operator.
- **Decision surface:** a Watchtower /approvals section "Inbound issues" with the classification, the recommendation and accept / needs-info / duplicate / decline buttons, plus one handover line with counts.
- **Status sync:** two places post stage comments.
  - The task lifecycle (update-task.sh on started-work and work-completed) posts stages 6 and 7.
  - The release tooling (pre-release and release) posts stages 8 and 9 for every task in the range that has `github_issue:`.
- **Everything posted goes through one verb** (`fw issues comment`). It is idempotent per stage, so a stage is never posted twice, and every post is logged.

## Risks

- **Outward-facing writes.** Every comment is public and permanent. That calls for a fixed template, idempotence, and an operator-approved standing permission for the template stages; free text only with approval.
- **Untrusted input.** Issue text is data, not instructions, exactly like peer mail. It can carry prompt injection. Classification reads it; nothing in it is executed or obeyed.
- **Volume.** Today it is 10 issues; the design should batch decisions.
- **Our own issues.** Agent-filed issues (DimitriGeelen via `fw upstream`) need different handling from outside ones. Possibly a filter by author or label.

## Open questions for the operator

1. **Standing permission for comments.** May the template comments (Received, Classified, In progress, Fixed, Available for testing, Released) be posted automatically, with only the decision comment (Accepted / Needs info / Duplicate / Not planned) needing your yes each time? Or do you want to approve every comment at first?
2. **Scope.** Only issues from outside users, or all issues, including the 26 agent-filed ones of our own?
3. **Labels.** May the pipeline create and apply labels (`triaged`, `area:*`, `severity:*`, `status:*`)?
4. **Sync interval.** Every 2 hours? Daily?
5. **Submitter as tester.** Should the "available for testing in -be" comment ask the submitter to confirm? That makes MikeEchoVoid an optional external field tester for T-4023.
6. **The first batch.** Classify and acknowledge MikeEchoVoid's #86–#94 and #85 by hand now, while the pipeline is built? The issues have waited 3 days.

## Operator answers (2026-10-10)

1. **Standing permission:** yes. Template stage comments (Received, Classified, In progress, Fixed on bleeding-edge, Available for testing, Released) post automatically; decision comments (Accepted / Needs info / Duplicate / Not planned) need the operator's yes each time.
2. **Scope:** all issues, with agent-filed ones (`fw upstream`) handled as class **internal** (agent recommendation, accepted).
3. **Labels:** allowed (`triaged`, `area:*`, `severity:*`, `status:*`, plus stage labels such as `fixed-on-bleeding-edge`).
4. **Sync interval:** every 2 hours.
5. **Submitter as tester:** yes — fixes land on bleeding-edge, and submitters are offered a way to pull an individual fix, apply and test it, and report back.
6. **First batch:** handled by hand now (operator approved all recommendations as "1").
7. **Footer** on every comment (added on request): "These status updates are automated, but Dimitri personally looks at every issue and decides what happens to it. Replies on this issue are read."
8. **Routing:** every MikeEchoVoid issue goes to arc `mikeechovoid-requests` (arc-021), horizon `now`.

### Operator answer 2026-10-19 (T-4347) — supersedes answer 1 for decision comments

Verbatim: *"you can post fully automatically no approval needed"*, then *"please codify that"*.

Decision comments (Accepted / Needs info / Duplicate / Not planned) no longer need the operator's yes each time. Codified as config key `ISSUES_DECISIONS_STANDING_PERMISSION` (default `0`; set to `1` for this project). With it on, `fw issues comment` posts a decision stage without `--approved-by-operator` and the ledger row records `approved_by: standing-permission:operator-2026-10-19`. With it `0` the 2026-10-10 rule applies unchanged. Comment text, footer, one outward verb, idempotence per (issue, stage) and untrusted-issue-text handling are unchanged.

## First batch, by hand (evidence for the build)

Run 2026-10-10 → 2026-10-11 with `gh` and the intake ledger `.context/issues/intake.jsonl`:
- #85–#94 received and classified; #85 not planned; #86–#94 accepted as T-4040…T-4047 + T-3886 + T-2802/T-4041.
- Fixed on bleeding-edge and posted with commit, test-it-yourself command and footer: #86, #87, #88 (2026-10-11). #89–#94 built and committed the same day.
- What the manual run showed the automation needs: (a) stage labels do not exist yet (`gh issue edit --add-label` failed on #86/#87); (b) a comment must name commits that are already on GitHub's `bleeding-edge` (checked with `git ls-remote github`) or the submitter cannot pull them; (c) the "how to test" line differs per issue type (upgrade vs fresh init), so the Fixed template needs a per-issue test command field; (d) ledger rows were appended by hand after each post — the verb must post and log atomically.

## Dialogue Log

- **2026-10-10, operator:** "We've got our first user, our second user beside me … has submitted bug fixes in GitHub … Mike Acker-Voy is the GitHub user [MikeEchoVoid] … devise a way to pull in these bug fixes, bugs and enhancement requests, systematically, regularly … ingest it, classify, categorize it, then incept it. Before that also give a notification back to the requester … that we have ingested it and the different steps … you serve it to me and you offer me to tell what to do with it. And then we give that message back. And then once it gets in, we need to assign a task … link it to task … when we start developing it, we update the GitHub issue. When we test it … once it gets submitted in a release … I find it really important to have a structured way to ingest it, automate it, to classify it, to service it to me operator so I can decide … but also to feedback what we do with it in the framework, with consistent structured information into the issue tickets in GitHub."
- **2026-10-10, operator (on the six questions):** "On one yes. Two, what do you think? … On three, yes definitely. On four, every two hours sounds fine. Yeah, [fixes] become part of Bleeding Edge and we can give submitter an option to pull individual fixes in and apply that and test that and give us feedback. On 5, what do you recommend?" → agent recommended including internal issues as class "internal" and the submitter-as-tester comment; operator: "yes".
- **2026-10-10, operator:** "Can we add, by the way, that this is automated, but Dimitri will have a personal look at each issue provided?" → footer added to all 10 Received comments in place.
- **2026-10-10, operator:** "1" (approve the batch-1 recommendations as proposed); "can we prioritize all the requests from Mike?"; "put this all in one arc … any new one from Mike just gets routed in this" → arc-021 `mikeechovoid-requests`, routing rule.
- **2026-10-11, operator:** "Proceed … work the MikeEchoVoid arc (#87 and #86 first), then T-3814, then build T-4039." → batch 1 fixed by hand first; the build waits on the go/no-go decision (inception gate).
