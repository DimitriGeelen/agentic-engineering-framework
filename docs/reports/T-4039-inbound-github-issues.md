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

Every comment uses one fixed, machine-readable template: a stage marker, the date, the task id and a link. The sync can then read back the stage the issue is in, and the submitter sees a consistent record.

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

## Dialogue Log

- **2026-10-10, operator:** "We've got our first user, our second user beside me … has submitted bug fixes in GitHub … Mike Acker-Voy is the GitHub user [MikeEchoVoid] … devise a way to pull in these bug fixes, bugs and enhancement requests, systematically, regularly … ingest it, classify, categorize it, then incept it. Before that also give a notification back to the requester … that we have ingested it and the different steps … you serve it to me and you offer me to tell what to do with it. And then we give that message back. And then once it gets in, we need to assign a task … link it to task … when we start developing it, we update the GitHub issue. When we test it … once it gets submitted in a release … I find it really important to have a structured way to ingest it, automate it, to classify it, to service it to me operator so I can decide … but also to feedback what we do with it in the framework, with consistent structured information into the issue tickets in GitHub."
