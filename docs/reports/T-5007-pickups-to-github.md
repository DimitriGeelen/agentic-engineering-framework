# T-5007: Move cross-project pickup requests from the sidecar to GitHub issues

Inception research artefact. Arc: `github-contributions` (draft), sibling of T-5006. Status: exploration.
Roles as in T-5006: researcher (AEF agent), two independent review seats, operator decides; peer projects consulted as the senders.

## Today (2026-11-02)

| Channel | What it carries | Volume |
|---|---|---|
| Sidecar peer messages | field reports, consults, notices, requests, replies | 806 messages total, 48 pending in the store |
| `fw pickup` envelopes | structured work requests from peer projects | 82 processed, 10 rejected, 4 auto-deferred |
| GitHub issues → `fw issues sync` | outside reports; each becomes a task with lifecycle comments | ~107 issues: 76 operator account, 28 Mehdi (MikeEchoVoid), 3 others; 242 intake lines |

GitHub intake already has what pickups lack in public: a numbered thread, lifecycle stages (accepted, fixed, released), and closing on the submitter's confirmation.

## What GitHub cannot carry as-is

- **Host detail.** Peer field reports name hosts, paths and accounts. The mirror is public; those stay off it.
- **Live consults.** A peer asking a question mid-task needs an answer in minutes; the sidecar delivers into the running session, GitHub does not.
- **Identity.** Peers would post from one GitHub account (the operator's) or need their own; the issue would not show which project sent it unless the body says so.

## Dialogue Log

### 2026-11-02 — operator raises the question
- Raised together with T-5006 (Mehdi's PR proposal): "migrate from pickup request over sidecar, moving that also to GitHub".
- Filed as its own inception (one inception, one question) in the same arc.

### 2026-11-02 — IW-1: what moves
- Agent offered: (1) work requests only, (2) all but live consults, (3) everything. Recommended 1.
- **Operator chose 1:** bug reports, enhancement requests, and anything else structural; asked for suggestions of other structural kinds.
- Agent's suggestions (pending operator's pick): documentation that disagrees with the code; design proposals like Mehdi's (GitHub Discussions or an issue labelled `proposal`); a sanitised per-release verdict thread. Security reports are the exception: they go to a private GitHub security advisory, never a public issue.
- Stays on the sidecar: field reports with host detail, live consults, notices, replies.
- **Operator added: PRs too, "but they are I guess part of either two?"** Agent: yes. A PR is not a third kind of request; it is the proposed fix for a bug issue or the build of an enhancement issue (Mehdi's rule 2: one PR, one issue). How PRs are taken in is T-5006's question; here they only count as the follow-up to an issue.
