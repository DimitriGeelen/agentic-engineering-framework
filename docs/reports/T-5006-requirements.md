---
title: "Outside contributions through GitHub — requirements (role chain step 1: requirements collector)"
task: T-5006 (with T-5007)
arc: github-contributions (arc-027)
role: requirements-collector
version: 0.1
date: 2026-11-02
status: collecting (interview mode)
---

# Outside contributions through GitHub — requirements

## 0 Version history

| Version | Date | Change | Task |
|---|---|---|---|
| 0.1 | 2026-11-02 | Skeleton; stakeholders; question list; answers A10-A12 carried in from the T-5007 dialogue | T-5006 |

## 1 Why this document exists

1.1 An outside contributor (Mehdi, GitHub MikeEchoVoid) wants to send pull requests and proposed how
(`T-5006-github-contributions.md`). The operator also wants cross-project requests (bugs, enhancements,
structural items) to move from the sidecar to GitHub issues (`T-5007-pickups-to-github.md`).
1.2 Method: ring20-manager's design role chain (their T-2222 v0.3), step 1, requirements collector, interview
mode. Card: `T-4123-inputs/02b-ring20-manager-role-cards.txt`. Later steps (threat modeler, security floor
and phasing, architect, evidence, pseudo-code, external panel, planner) follow after the operator signs this
list off.

## 2 Stakeholders

2.1 **Operator** (Dimitri): owns the framework, approves and merges, decides releases.
2.2 **Outside contributors**: Mehdi first; later anyone on GitHub.
2.3 **Peer project agents** (010, 050, 055, 832, ring20, others): send bugs and requests; test fixes.
2.4 **AEF agents**: take in issues and PRs, run the review loop, relay peer reports.
2.5 **Consumer projects**: install the framework through `fw upgrade`; everything merged reaches them.
2.6 **Protected systems**: the OneDev source repo (`origin`), the GitHub mirror, the release train
(`bleeding-edge` → `master`), CI, the peers' hosts (their names must not go public).
2.7 **Adversaries**:
2.7.a a malicious contributor who hides harmful code in a PR (a supply-chain path into every consumer);
2.7.b a compromised or careless peer bot account or token;
2.7.c a confused agent that copies host names, paths or secrets into a public issue;
2.7.d a hurried approver who merges without the review loop;
2.7.e the mirror sync itself, which can erase merged work (it already did: #76, #77, #79).

## 3 Questions

Interview mode: one at a time; "skip", "back" and "overview" work.

3.1 **Q1 Purpose**: in your words, what must be true when this arc is done?
3.2 **Q2 Who may contribute**: anyone on GitHub, invited contributors only, or Mehdi first as a pilot?
3.3 **Q3 Where a merged PR lands**: merge on GitHub and bring it into OneDev at once; never merge on GitHub
(apply on OneDev, the mirror marks the PR merged); or make GitHub the source.
3.4 **Q4 Who merges**: only you; or an AEF agent after your recorded approval?
3.5 **Q5 Task reference in outside commits**: the intake task id plus issue number (Mehdi's proposal); the
issue number alone; or a task created in the fork.
3.6 **Q6 Checks before you look**: what must run on a PR automatically (tests, audit, lint), and what may a
fork PR's CI see?
3.7 **Q7 Framework gates before landing**: must a contributed change pass the same review loop as our own
work (review seats, criteria, Verification), and at which strength?
3.8 **Q8 Protecting history**: branch protection on GitHub `bleeding-edge`, and how it fits the mirror sync.
3.9 **Q9 Licence terms**: Apache-2.0 section 5 alone, a DCO sign-off line, or a CLA?
3.10 **Q10 Which requests move to GitHub** — answered (A10).
3.11 **Q11 Who files the issue for a peer** — answered (A11).
3.12 **Q12 Telling the source project** — answered (A12).
3.13 **Q13 The old path**: `fw pickup` and sidecar requests: keep, wrap (they become issues), or retire?
3.14 **Q14 What may never go public**: hosts, IPs, paths, accounts, secrets; anything else? Who checks?
3.15 **Q15 Security reports**: private GitHub security advisory, or another route?
3.16 **Q16 Your time**: how much review time per week is acceptable; how are refusals given?
3.17 **Q17 Migration**: what happens to open pickups, auto-deferred envelopes and existing issues?
3.18 **Q18 Gap review** (card 3.4): credential custody, compromised sessions, approval fatigue, offline
operation, recovery, revocation, identity, unsupported cases.

## 4 Answers

4.1 **A1 Purpose** (2026-11-02): the operator chose two of the four offered statements:
4.1.a an outside contributor can open a PR against `bleeding-edge` and see tests run on it;
4.1.b peer projects' bugs and requests live as GitHub issues, with AEF relaying them and asking the reporter
to check the fix.
4.1.c Not chosen as purpose: "merged work lands in OneDev and ships without being lost" and "nothing reaches
consumers without the same review loop". Recorded as candidate requirements, not dropped; they are asked
directly under Q3 (landing) and Q7 (gates).
4.1.d Operator, on 4.1.c: "So I do merge it, but it lands in GitHub, not in OneDev anymore." Recorded as the
answer to Q3 (below, A3), given ahead of order.
4.2 **A2 Who may contribute** (2026-11-02): **1 — Mehdi first, as a pilot.** The whole circuit runs end to end
with one contributor who knows the framework; it opens wider only after it has held. Reason given: with GitHub
as the source repo (A3), a bad merge lands where consumers install from.
4.2.a A7 to A9: not yet asked.
4.6 **Q6 Checks before you look** — in discussion (2026-11-02). Operator: "the framework's directives are one"
(the framework's own checks come first), "but why do we run them on GitHub's runner? This I don't understand."
4.6.a Agent's explanation: GitHub's runner is a throwaway machine outside the operator's network. A PR's code
is untrusted until reviewed (adversary 2.7.a); running it there means a harmful PR can damage nothing of ours,
and the contributor sees the result on the PR (A1.a). Running it on our own hosts is possible (a self-hosted
runner, OneDev's build server, or an AEF agent that checks the PR out) but executes untrusted code inside the
network, next to credentials and the peers' hosts.
4.6.b Operator: "But do I need to pay for that? Then I need to start to use GitHub resources." Facts
(2026-11-02): the GitHub repo is public, and GitHub-hosted runners are free for public repositories. GitHub
resources are already in use: `test.yml` runs on every push to `master`, and its last three runs
(2026-10-20, 2026-10-20, 2026-10-29) all FAILED unnoticed. A same-day field report (ring20-dashboard, G-128,
T-5008: a review seat on a shared host killed a production service) is a live example of why untrusted code
should not run on the operator's hosts.
4.6.c Operator: "Then I depend on GitHub infrastructure to do that, right?" Agent: yes, for the pre-merge
checks. Two qualifiers: (1) A3 already makes GitHub the source repo, so the dependency exists either way;
Actions adds the runner, not a new vendor. (2) Portability (directive D4) is kept if the workflow only calls the
framework's own commands (`fw audit`, `fw test`, the task check), so the same checks can run elsewhere
(OneDev's build server or an isolated local seat, once T-5008 lands) if GitHub is down or its terms change.
Candidate requirement: the CI workflow contains no logic of its own, only calls to framework commands.
4.6.d Operator: "What are the costs from GitHub?" Agent (web sources, 2026-11-02): public repositories are free
on standard GitHub-hosted runners, with no minute cap; GitHub's 2025-12-16 changelog says public-repo usage
stays free. Paid only: private repos beyond the free quota, and "larger" runners. A $0.002/min fee on
self-hosted runners in private repos was announced for 2026-03-01 and reported postponed; it never applied to
public repos. Not checked against GitHub's live billing page.
4.6.e **A6** (2026-11-02): "I would like to have it under my own control. OK, let's do GitHub runners, but let's
have an activity that also starts developing and testing our own runners for later. That needs to be a
high-priority activity, not immediately but high priority."
4.6.f Recorded as: (1) now: every check (tests, structure audit, lint, the framework task check) runs on
GitHub-hosted runners, through framework commands only (4.6.c), so it can move; (2) a separate high-priority
task in this arc, scheduled next (not started now): build and test our own isolated runner under the operator's
control (candidate: a throwaway VM or container on the operator's Proxmox, on a network segment that cannot
reach other hosts, driven by OneDev's build server or registered as a runner), and prove it runs the same checks.
The goal is control: the operator wants the checks to end up on their own infrastructure.
4.4.a **Merge target** (operator, 2026-11-02, while discussing Q7): "where do I merge it to? To bleeding-edge."
Confirmed: outside PRs target and are merged into `bleeding-edge` on GitHub (Mehdi's point 1); `master` keeps
receiving fast-forwards at release time only (release train); nothing outside merges into `master`.
4.7 **Q7 Gates before merge** — in discussion (2026-11-02). Agent offered review by reading, at a rung set by
risk (1 / 3 / 5), or a floor of rung 3, or rung 5 always. Operator: "at least it should have been tested. How
can we test it, and depending on the risk test it more thoroughly, and have the test results judged like we do
with any external tester. It follows the normal review logic, maybe a little more stringent."
4.7.a Agent's reading: (1) every PR is tested, not only read: the automated checks on GitHub (A6) always;
(2) higher risk means deeper testing (more of the suite, then field tests in real projects); (3) the test
results are judged the way field reports are (WORKS / FAILS with evidence), by the normal review logic, one
step stricter (floor rung 3 for outside code). Open: where the deeper tests run before the merge, since running
an unmerged PR runs a stranger's code (G-128).
4.7.b **Operator: "That means the risk automatically gets increased, because it comes from external."**
Requirement: a PR from outside the estate is assessed one risk level higher than the same change made by us
(low → medium, medium → high, high stays high). Its testing depth and review strength follow the raised level.
4.7.c **A7 Where deeper tests run before the merge** (operator, 2026-11-02): **option 1** — the review seats
read the PR first (they do not run it); only if they find nothing alarming does testing start. Trusted peer
testers then run the PR in a throwaway copy of their project, never the live one, and post WORKS / FAILS on the
PR through the secondary account (4R.6.c). Higher risk means more testers and more scenarios. When T-5009 (own
isolated runner) exists, deep tests move there.
4.5 **A5 Task reference** (2026-11-02): **1 — intake task id plus issue number**, "T-4935 (#104): …". The
commit-msg hook stays unchanged; the intake task file must be on `bleeding-edge` before the PR is opened.
4.4 **A4 Who merges** (2026-11-02): **1 — only the operator, with the GitHub merge button.** AEF agents run the
review loop and post a recommendation on the PR; no agent holds merge rights.
4.3 **A3 Where a merged PR lands** (2026-11-02, given with A1): the operator merges, and the merge lands on
GitHub; OneDev is no longer where it lands. This is option 3 of Q3: GitHub becomes the source repo.
4.3.a Follow-up (2026-11-02): OneDev retired, a mirror of GitHub, or a backup only? **Operator: 1 — OneDev
becomes a mirror of GitHub.** We push to GitHub; OneDev copies it (the reverse of today). OneDev's builds and
the private copy on the operator's network stay.
4.3.b Facts that bear on it: today `origin` is OneDev and pushes to GitHub; `fw mirror sync` runs every 15
minutes in that direction; consumers already install from GitHub (`lib/consumer-recover.sh:19` calls it the
canonical public mirror); the session, hooks, release train and handovers push to `origin`.
4.10 **A10** (T-5007 IW-1, 2026-11-02): bug reports, enhancement requests and other structural items move to
GitHub issues; field reports, live consults and notices stay on the sidecar. PRs are not a third kind: each
PR is the fix or build for one issue. Open: which further structural kinds (agent suggested wrong
documentation, design proposals, a cleaned per-release verdict thread; security reports go private).
4.11 **A11** (T-5007 IW-2): AEF relay is the path every agent has: the agent reports to AEF, AEF cleans host
detail and files the issue naming the source project. Per-project GitHub bot accounts are an optional
addition (operator likes the idea; it means every agent needs an account). One shared cleaning step for both
routes.
4.12 **A12** (T-5007 IW-2): when the issue reaches fixed or released, AEF tells the source project's agent to
check; their verdict comes back as a field report and confirms or reopens the issue.

## 4R Review findings braided in (T-5007 reviews, 2026-11-02)

Input from `T-5007-review-codex.md` (sound with fixes) and `T-5007-review-opencode.md` (unsound as specified,
fixable). Each finding is put to the operator one at a time; the answer becomes a requirement or a conflict.

4R.1 **F1 Cleaning is too weak.** `lib/issues.py:_scrub` (line 1441) replaces a local-host regex and this
machine's own hostname with `[host]`; its docstring says names it cannot recognise are not caught. It runs only on
release evidence (line 1521), never on issue bodies.
4R.1.a **Operator (2026-11-02): rewrite fresh** (option 1). AEF never copies a peer's text; it writes the issue
from a fixed template; the cleaner is a gate that refuses on any hit, never a filter that repairs.
4R.1.b **Operator: "What I do want to prevent: oh, it's not good enough, we ping it back and it disappears in the
void."** Recorded as a requirement: a refusal never loses a report. Every peer report is recorded locally on
arrival, before any public step; a refused draft stays in a visible "held" state with its reason; AEF rewrites
it; a report still held after a set time (or attempts) surfaces to the operator by name (operator pending,
Watchtower); the sending project is told either the issue number or that it is held and why. Nothing is ever
bounced back to the sender as the only copy.

4R.2 **F2 Relayed issues lose the lifecycle.** `fw issues sync` classifies owner-authored issues as internal
(ledger only: no stages, no submitter confirmation). **Operator (2026-11-02): option 1** — AEF files relayed
issues with a `relayed` label and a source field; sync gives them the full lifecycle, and where it would wait for
the GitHub author it waits for the source project's verdict over the sidecar. One account, no new credentials.

4R.3 **F3 No reopen; the 14-day sweep can close too early.** **Operator (2026-11-02): option 1** — a FAILS
verdict (source project over the sidecar, or a "not fixed" reply on GitHub) reopens the issue: back to accepted,
task reopened or a follow-up linked, a cleaned public comment posted. The sweep skips an issue while a requested
check is pending; an overdue check surfaces to the operator by name instead of closing silently.

4R.4 **F4 Naming the source project is a disclosure.** **Operator (2026-11-02): option 3, "unless requested
otherwise"** — the relayed issue names the real source project by default; a project that asks not to be named
gets "reported by a project in the maintainer's estate" with the mapping kept only in AEF's local ledger. The
cleaning gate (F1) still removes hosts, IPs, paths, accounts and tokens; only the project name is allowed.

4R.5 **F5 Bot accounts per peer.** GitHub machine accounts must be created and owned by a human; one free
machine account per person (both reviews). Agent offered: no bots in this arc; one shared machine account; one
per peer. **Operator (2026-11-02): alternative — identify peers by unique, stable project ids following the
TermLink naming convention, instead of GitHub accounts.** Under discussion: identity comes from the id stamped
by the relay, not from who is logged in to GitHub.
4R.5.a A TermLink identity has three layers: host (`//<host>/…`), hub id (16 hex characters), project id (the
project name). Agent recommended publishing the project id only. **Operator: the hub id might be worse, "because
you give away part of a key."** Not verified whether the hub id is derived from key material; treated as
sensitive either way. Requirement: hub ids and host names never appear in public text; the cleaning gate (F1)
refuses them.
4R.5.b **Operator (2026-11-02): confirmed.** No bot accounts in this arc. The relay stamps the project id (the
project name) on the issue; nothing else from TermLink goes public. The full address stays in AEF's local
ledger, used only to reach the project over the sidecar (F2, F3).

4R.6 **F6 The relay is a single point of failure and a bottleneck.** Agent offered: (1) nothing lost, delays
visible, AEF has no veto; (2) plus a direct fallback through a shared account; (3) accept as is.
4R.6.a **Operator rethink (2026-11-02), revises F5:** the concern with accounts was the number of accounts, not
tokens. One secondary GitHub account, only for creating and updating issues, shared with **trusted** peers who
file and update directly; this also lets peers that test a PR send their results to it. Other peers go through
the AEF relay. Under discussion: how the account is shared, and its permissions.
4R.6.b Agent offered: (1) one account, a separate fine-grained token per trusted peer, scoped to issues and PR
comments on this repo only (no push, no merge), revocable per peer; (2) one shared token; (3) only AEF holds a
token. **Operator: "AEF holds at least — my AEF instance here holds at least [one], right?"** Read as: the
operator's own AEF instance always holds a token of the secondary account (for the relay and the lifecycle);
trusted peers get their own on top. **Operator: "Sounds good" (option 1, confirmed 2026-11-02).**
4R.6.c Resulting model (revises 4R.5.b): one secondary GitHub account for issues and PR comments only; the
operator's AEF instance holds a token; each trusted peer holds its own fine-grained token, scoped to issues and
PR comments on this repo, revocable per peer; the trusted-peer list is an operator-owned policy file. Machine
traffic leaves the operator's personal account. F1 (cleaning gate), F5 (project-id stamp) and F2 (lifecycle)
apply to direct posts as well as relayed ones.
4R.6.d **Relay route, remainder of F6 — operator: option 1.** A peer keeps its report until AEF acknowledges with
an issue number or a held status; the sidecar holds messages while AEF is down; a report waiting too long
surfaces to the operator by name; AEF has no veto: it files and adds its view as a comment. Only the cleaning
gate (F1) can hold a report, visibly.

4R.7 **F7 Duplicates.** Pickup dedup (content hash + project) is lost on the GitHub route; sync has only a title
similarity hint. **Operator (2026-11-02):** AEF must do the matching, because it has far stronger tools: the
component fabric, the vector database (semantic match) and BM25 keyword search. AEF matches each new ticket
against existing tasks and tickets, links the new ticket to the main one (or closes it as part of it), records
the link in the main ticket, and when the main ticket is closed, closes all linked tickets.
4R.7.a Agent's view: agreed, with two refinements under discussion — (a) a linked reporter whose check FAILS
reopens their own ticket (unlinked), because the symptom may differ; (b) a weak match is never linked
silently: high confidence links, medium confidence posts "possible duplicate of #N" for the operator.
4R.7.b **Operator: option 1 — the design plus both refinements.** Matching runs in `fw issues sync` on every new
ticket (relayed and direct alike), against tasks and tickets, using the fabric, vector and BM25 search.

4R.8 **F8 No migration plan.** **Operator (2026-11-02): option 1 — forward only, old command wrapped.** The 82
processed pickups stay (each became a task); the 4 auto-deferred are filed on GitHub when their blocker clears;
`fw pickup send` for bug reports and feature proposals routes to the new filing command (direct for trusted
peers, relay for the rest); learnings and patterns stay on the sidecar; the GitHub issue templates ask for a
cleaned description and the project id, not raw `fw doctor` output or logs.

4R.9 **F9 "Fixed" must be tied to the source repo** (codex 8). Dissolved by A3: GitHub is the source repo, so a
fix merged there is the authoritative one.

## 5 Glossary

(filled as terms settle: contribution, PR, issue, relay, peer bot, source repo, mirror, landing)

## 6 Requirements

(drafted after the interview)

## 7 Conflicts

(none recorded yet)

## 8 Earlier requirements

8.1 Mehdi's proposal points 1-8 (`T-5006-github-contributions.md`): each will be marked kept, changed or
dropped.

## 9 Drawings

(D-1 context view, D-2 main flow incl. refusal path, D-3 lifecycle of a contribution: after the interview)
