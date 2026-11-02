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
4.8 **A8 Protecting history** (operator, 2026-11-02): **option 1** — on GitHub, `bleeding-edge` and `master`
refuse force pushes and deletion. Direct pushes stay allowed (the session pushes to `bleeding-edge`; releases
fast-forward `master`). No PR requirement for our own commits. With GitHub as the source and OneDev mirroring
from it (A3, A3.a), the protection no longer conflicts with the mirror sync.
4.9 **A9 Licence terms** (operator, 2026-11-02): **option 1 — Apache-2.0 section 5 plus the DCO.** The project
is already Apache-2.0 (`LICENSE`; section 5: a contribution submitted for inclusion is under the same licence
unless stated otherwise). Each outside commit also carries `Signed-off-by:` (`git commit -s`), certifying the
contributor has the right to submit it; the commit-msg check verifies the line on outside commits. No CLA.
4.15 **A15 Security reports** (operator, 2026-11-02): **option 1** — GitHub private vulnerability reporting
("Report a vulnerability"), visible only to the operator and people they add; fixed privately, advisory
published with the fix; a short `SECURITY.md` points there. Peers in the estate may still report over the
sidecar (private). Security reports never go into public issues, and the relay (F1) refuses to file one
publicly.
4.14 **A14 What never goes public** (operator, 2026-11-02): **option 1.** The cleaning gate (F1) refuses public
text containing: host names; IP addresses; file paths on estate machines; account and user names; tokens, keys
and secrets; TermLink hub ids; personal data (email addresses, real names other than a contributor's own GitHub
name, phone numbers); content from a project's own data (for example a quoted email in a 050 report); open
security weaknesses (private route, A15); and estate layout (which host runs what, network layout, backup
locations). Project names are allowed unless a project opts out (F4). Anything the gate cannot classify is held
for rewriting, never posted (F1).
4.16 **A16 Your time and refusals** (operator, 2026-11-02): **option 1.** At most 3 outside PRs wait for the
operator's merge at once; further ones are labelled "waiting" and not reviewed until a slot frees. Each PR gets a
one-screen AEF recommendation (what it changes, risk level, test results, merge / change / refuse). A refusal is
one line on the PR (Mehdi point 6), drafted by AEF and approved by the operator.
4.18 **Q18 Gap review** (card 3.4), agent's pass:
4.18.a Credential custody: the secondary account is owned by the operator (password, 2FA); each token lives in its
holder's credential store, named in a registry, never in the repo (A11, 4R.6.c). Covered.
4.18.b Compromised session or host: a peer host → revoke its token alone; the AEF host → revoke AEF's token;
branch protection (A8) and operator-only merge (A4) cap the damage. Covered.
4.18.c Approval fatigue: queue of 3 and one-screen summaries (A16). Covered.
4.18.d Offline: GitHub down → PRs and direct posts wait; AEF down → the sidecar holds relay reports (F6). Covered.
4.18.e Recovery: GitHub account lost → the OneDev mirror holds the history (A3.a) and the local issue ledger the
intake. Covered.
4.18.f Revocation: per-peer tokens; the operator-owned trusted list (4R.6.c). Covered.
4.18.g Identity: contributors by GitHub account plus DCO (A9); peers by the stamped project id (F5). Covered.
4.18.h Unsupported cases: a PR without an issue, or against `master`, is refused with a one-line reason (A16,
4.4.a). **Open:** a PR that is high risk (every outside PR is raised one level, 4.7.b) needs a rung-5 panel, and a
rung-5 panel cannot be assembled today (two launchable worker kinds; the antigravity seat is T-4997). Put to the
operator. **Operator (2026-11-02): option 1 — it waits.** Low- and medium-risk outside PRs proceed; a high-risk
one is labelled "waiting for review strength" until a rung-5 panel can run. T-4997 becomes a dependency of this
arc. No step-down for outside PRs.
4.18.i **Interview complete** (2026-11-02): Q1-Q18 answered or settled; review findings F1-F9 braided in.
4.13 **A13 The old path** — answered by F8 (4R.8): `fw pickup send` for bugs and features is wrapped onto the new
route; learnings and patterns stay on the sidecar.
4.17 **A17 Migration** — answered by F8 (4R.8): forward only.
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

Each term is defined once here; later roles use it in this sense. The source is the answer or finding that
set it.

5.1 **Contribution**: a change proposed to the framework from outside the operator's own sessions, carried as an
outside PR (5.2). Source: A1.a, A2.
5.2 **Outside PR**: a GitHub pull request opened from a fork by an outside contributor, targeting `bleeding-edge`,
fixing or building exactly one issue (5.3). Source: A1.a, A10, 4.4.a.
5.3 **Issue**: a GitHub issue on the framework's source repo (5.9); the public, numbered record of one bug report,
enhancement request or other structural item. Source: A10.
5.4 **Relayed issue**: an issue AEF files on behalf of a peer project after the peer reported to AEF over the
sidecar; it carries the `relayed` label and a source field. Source: A11, F2.
5.5 **Direct post**: an issue, issue update or PR comment written by a trusted peer (5.6) itself, with its own token
of the secondary account (5.7), without the AEF relay. Source: 4R.6.a, 4R.6.c.
5.6 **Trusted peer**: a peer project named in the operator-owned trusted-peer policy file; it may post directly and
may act as a tester of outside PRs. Every other peer uses the relay. Source: 4R.6.a, 4R.6.c, A7.
5.7 **Secondary account**: the one GitHub account, owned by the operator, used only for creating and updating
issues and writing PR comments; machine traffic runs through it, not through the operator's personal account.
Source: 4R.6.a, 4R.6.c, 4.18.a.
5.8 **Project id**: the stable, unique project name of a peer project in the TermLink naming convention (the
project layer only, never the host or hub id), stamped on relayed issues and direct posts to identify the source.
Source: 4R.5, 4R.5.a, 4R.5.b.
5.9 **Source repo**: the authoritative repository where merges land and from which consumers install: the GitHub
repo. Source: A3.
5.10 **Mirror**: the OneDev copy of the source repo, updated from GitHub (the reverse of the direction before this
arc); OneDev's builds and the private copy stay. Source: A3.a.
5.11 **Landing**: an outside PR being merged by the operator into `bleeding-edge` on the source repo. `master`
receives work only by fast-forward at release. Source: A3, A4, 4.4.a.
5.12 **Cleaning gate**: the one shared check every piece of public text (title, body, comment, verdict) passes
before it is posted, on both the relay and the direct route; it refuses on any hit and never repairs. Source: F1,
4R.1.a, A14, A11.
5.13 **Held report**: a peer report whose public draft the cleaning gate refused; it is kept, visible, with its
reason, until AEF rewrites it or the operator acts. Source: 4R.1.b, 4R.6.d.
5.14 **Main ticket / linked ticket**: when AEF's matching finds that a new ticket is the same problem as an
existing one, the existing one is the main ticket and the new one is linked to it; the main ticket records its
links. Source: F7, 4R.7.b.
5.15 **Risk level**: low, medium or high, as the framework's normal review logic assesses a change; an outside PR is
assessed one level higher than the same change made inside the estate. Source: 4.7.b.
5.16 **Review rung**: the review strength of the framework's review policy (rung 1, 3 or 5) required by a risk level;
rung 5 is a three-seat, three-vendor panel. Source: A7, 4.18.h.
5.17 **Field test**: a trusted peer running a change in a throwaway copy of its own project (never the live project)
and reporting WORKS or FAILS with evidence. Source: A7, A12.
5.18 **be-tag**: the pre-release tag on `bleeding-edge` that a source project is asked to test when its issue
reaches fixed. Source: A12, T-5007 IW-2.
5.19 **DCO**: the Developer Certificate of Origin; a `Signed-off-by:` line on each outside commit certifying the
contributor has the right to submit it, in addition to Apache-2.0 section 5. Source: A9.
5.20 **Pilot**: the period in which only Mehdi's contributions run through the circuit; it ends by an operator
decision after the circuit has held end to end. Source: A2.

## 6 Requirements

6.0 How to read this section.
6.0.a Each requirement has: statement (RFC 2119), a. type · source · priority · verification method, b. rationale,
c. acceptance criterion a test can check, and d. for requirements that make something **impossible**, the
adversary (2.7.a-e) it holds against.
6.0.b Priority (proposed by the collector; the operator decides at sign-off): **P1** needed for the pilot (A2);
**P2** needed before contributions open wider; **P3** later.
6.0.c Verification methods: **test** (automated, repeatable), **demonstration** (a live run observed once and
recorded), **inspection** (reading a file or setting), **analysis** (reasoning over records).
6.0.d Nothing here is new: every item traces to an answer (A-n) or a finding (F-n). Gaps are open questions
(section 10), not requirements.

### 6.1 Source repo, landing and history

6.1.1 **R-1 GitHub is the source repo.** Merges of outside PRs and the session's own pushes MUST land on the GitHub
repo, and the GitHub repo MUST be treated as authoritative for "fixed" and "released".
6.1.1.a Functional · A3, F9 · P1 · demonstration.
6.1.1.b The operator merges on GitHub and wants the merge to stick there (A3); a fix merged on the source repo is
the authoritative one (F9).
6.1.1.c Given an outside PR merged on GitHub `bleeding-edge`, when every scheduled sync has run, then the merge
commit is still reachable from GitHub `bleeding-edge` and the issue lifecycle refers to that commit.

6.1.2 **R-2 OneDev mirrors GitHub.** OneDev MUST be updated from GitHub (one direction: GitHub → OneDev). OneDev's
builds and the private copy on the operator's network MUST keep working.
6.1.2.a Interface · A3.a, A3.b · P1 · demonstration.
6.1.2.b The operator chose to reverse today's direction rather than retire OneDev (A3.a).
6.1.2.c Given a commit pushed to GitHub `bleeding-edge`, when the mirror cycle runs, then OneDev `bleeding-edge`
points at the same commit, and a OneDev build can run on it.

6.1.3 **R-3 The mirror cannot erase merged work.** It MUST be impossible for the mirror sync to remove or rewrite a
commit on GitHub `bleeding-edge` or `master`.
6.1.3.a Security invariant · A3.a, A8, 2.7.e (PRs #76, #77, #79) · P1 · test.
6.1.3.b Merged PRs were lost once when the mirror rewrote GitHub's history.
6.1.3.c Invariant: after any mirror run, the previous GitHub tip of each protected branch is an ancestor of the
new tip.
6.1.3.d Holds against: 2.7.e (the mirror sync).

6.1.4 **R-4 Protected branches.** On GitHub, `bleeding-edge` and `master` MUST refuse force pushes and deletion.
6.1.4.a Security invariant · A8, Mehdi point 7 · P1 · inspection and test.
6.1.4.b Branch protection stops the #76/#77/#79 loss class, and with GitHub as the source it no longer conflicts with
the mirror (A8).
6.1.4.c Given the protection is on, when anyone (operator token, agent token or peer token) force-pushes to or
deletes `bleeding-edge` or `master`, then GitHub refuses.
6.1.4.d Holds against: 2.7.e (mirror sync), 2.7.b (compromised peer token), 2.7.d (hurried approver).

6.1.5 **R-5 Our own pushes stay direct.** Direct (fast-forward) pushes to `bleeding-edge`, and release fast-forwards
to `master`, MUST stay allowed, and our own commits MUST be pushable without a PR.
6.1.5.a Operational · A8 · P1 · demonstration.
6.1.5.b The session pushes to `bleeding-edge`; releases fast-forward `master` (release train).
6.1.5.c Given protection is on, when the session pushes a fast-forward to `bleeding-edge`, then the push succeeds
without a PR.

6.1.6 **R-6 Outside work never enters `master` directly.** Outside PRs MUST target `bleeding-edge`. A PR against
`master` MUST be refused with a one-line reason. It MUST be impossible for outside work to reach `master` other than
by a release fast-forward from `bleeding-edge`.
6.1.6.a Security invariant · 4.4.a, 4.18.h, Mehdi point 1 · P1 · test.
6.1.6.b `master` is the consumer install surface and receives only releases.
6.1.6.c Given an outside PR with base `master`, when AEF takes it in, then AEF drafts a one-line refusal and no
review or test starts.
6.1.6.d Holds against: 2.7.a (malicious contributor), 2.7.d (hurried approver).

### 6.2 Who contributes, who merges, licence

6.2.1 **R-7 Pilot first.** Until the operator decides the circuit has held end to end, only Mehdi's outside PRs MUST
be taken through review, testing and merge.
6.2.1.a Operational · A2 · P1 · demonstration.
6.2.1.b With GitHub as the source repo, a bad merge lands where consumers install from (A2).
6.2.1.c Given the pilot is on, when a PR from another account arrives, then it is not recommended for merge (how
it is handled otherwise: 10.2).

6.2.2 **R-8 Only the operator merges.** Outside PRs MUST be merged only by the operator, with the GitHub merge button.
It MUST be impossible for an agent or a peer to merge: no token held by an agent or peer has merge or push rights.
6.2.2.a Security invariant · A4, 4R.6.c · P1 · inspection and test.
6.2.2.b AEF agents run the review loop and recommend; deciding is the operator's (A4).
6.2.2.c Given each agent and peer token, when it is used to merge a PR or push a branch, then GitHub refuses.
6.2.2.d Holds against: 2.7.b (compromised peer token), 2.7.c (confused agent).

6.2.3 **R-9 One PR, one issue.** Every outside PR MUST link exactly one issue. A PR without an issue MUST be refused
with a one-line reason.
6.2.3.a Functional · A10, 4.18.h, Mehdi point 2 · P1 · test.
6.2.3.b A PR is the fix or build for one issue, not a third kind of request (A10). (Mehdi's documentation exception:
10.3.)
6.2.3.c Given an outside PR whose description links no issue, when AEF takes it in, then AEF drafts a one-line
refusal and no review starts.

6.2.4 **R-10 Task reference.** Each outside commit message MUST start with the intake task id and the issue number
("T-NNNN (#N): …"). The commit-msg hook MUST stay unchanged. The intake task file MUST be on `bleeding-edge` before
the contributor opens the PR.
6.2.4.a Interface · A5, Mehdi point 3 · P1 · test.
6.2.4.b The intake already creates one task per issue; this needs no new mechanism (A5).
6.2.4.c Given an issue accepted by intake, when the contributor is told to start, then its task file is already on
GitHub `bleeding-edge`; and given a commit "T-NNNN (#N): …" for that task, the unchanged hook accepts it.

6.2.5 **R-11 Licence and DCO.** Outside contributions MUST be under Apache-2.0 (section 5). Each outside commit MUST
carry a `Signed-off-by:` line, and a check MUST verify it on outside commits. No CLA is required.
6.2.5.a Interface · A9, Mehdi point 8 · P1 · test.
6.2.5.b The DCO certifies the contributor's right to submit at no cost to them (A9). Where the check runs: 7.6.
6.2.5.c Given an outside PR with a commit lacking `Signed-off-by:`, when the checks run, then the DCO check fails
and the PR is not recommended for merge.

### 6.3 Checks before anyone looks

6.3.1 **R-12 Every PR is tested.** Every PR to `bleeding-edge` MUST run the automated checks (tests, structure audit,
lint, the framework task check), and the result MUST be visible to the contributor on the PR.
6.3.1.a Functional · A1.a, A6, Mehdi point 5 · P1 · demonstration.
6.3.1.b Today `test.yml` ignores PRs to `bleeding-edge`; the contributor must see tests run (A1.a).
6.3.1.c Given a new PR to `bleeding-edge`, when it is opened (and, for a first-time contributor, the run is
approved), then each listed check runs and reports its status on the PR.

6.3.2 **R-13 Checks run on GitHub-hosted runners for now.** The automated checks MUST run on GitHub-hosted runners.
Untrusted PR code MUST NOT run on estate hosts for these checks.
6.3.2.a Security invariant · A6, 4.6.a, 4.6.b · P1 · inspection.
6.3.2.b A PR's code is untrusted until reviewed; a throwaway runner outside the network can damage nothing of ours.
6.3.2.c Given the workflow file, when inspected, then every job uses a GitHub-hosted runner label and none a
self-hosted one.
6.3.2.d Holds against: 2.7.a (malicious contributor).

6.3.3 **R-14 The CI holds no logic of its own.** The workflow MUST only call framework commands, so the same checks
can run elsewhere unchanged.
6.3.3.a Quality (portability, directive D4) · 4.6.c, 4.6.f · P1 · inspection and demonstration.
6.3.3.b The operator wants the checks under their own control later (A6); this keeps them movable.
6.3.3.c Given the workflow file, when each step is read, then it is a framework command (or checkout/setup), and
running the same commands on another machine gives the same verdict.

6.3.4 **R-15 Own runner, high priority.** A separate task in this arc MUST build and test an isolated runner under the
operator's control and prove it runs the same checks; it is scheduled next, at high priority, not started now.
6.3.4.a Operational · A6, 4.6.f (T-5009) · P2 · inspection, then demonstration.
6.3.4.b "I would like to have it under my own control" (A6).
6.3.4.c Given the arc, when its tasks are listed, then the own-runner task exists with high priority; when it
completes, the R-12 checks pass on the own runner with the same verdict as on GitHub for the same commit.

### 6.4 Risk, review and testing

6.4.1 **R-16 Outside raises risk.** An outside PR MUST be assessed one risk level higher than the same change made
inside the estate: low → medium, medium → high, high stays high. Testing depth and review strength MUST follow the
raised level.
6.4.1.a Functional · 4.7.b · P1 · test.
6.4.1.b "The risk automatically gets increased, because it comes from external" (operator, 4.7.b).
6.4.1.c Given a change the risk assessment rates low, when it arrives as an outside PR, then the recorded risk level
is medium and the review rung required is the medium one.

6.4.2 **R-17 Read before run.** Review seats MUST read an outside PR (not run it) first. It MUST be impossible for an
outside PR's code to run on any estate host or in any peer project before that read review has found nothing
alarming.
6.4.2.a Security invariant · A7, 4.7.a, G-128 · P1 · test and analysis.
6.4.2.b Running an unmerged PR runs a stranger's code (4.7.a); a review seat on a shared host already killed a
production service once (G-128, T-5008).
6.4.2.c Given an outside PR whose read review has not returned clean, when any tester asks for it, then no test
request is sent and the PR shows it awaits review.
6.4.2.d Holds against: 2.7.a (malicious contributor), 2.7.d (hurried approver).

6.4.3 **R-18 Testers use a throwaway copy.** After a clean read review, trusted peer testers MUST run the PR only in a
throwaway copy of their project; running an outside PR in a live project MUST be impossible by the procedure AEF
sends. Testers MUST post WORKS / FAILS on the PR through the secondary account.
6.4.3.a Security invariant · A7 · P1 · demonstration.
6.4.3.b A field test of a stranger's code must not reach a working project.
6.4.3.c Given a test request, when a tester follows it, then the PR is checked out into a fresh copy that is removed
afterwards, and a WORKS/FAILS comment with evidence appears on the PR from the secondary account.
6.4.3.d Holds against: 2.7.a (malicious contributor). (Where the copy runs until the own runner exists: 7.2.)

6.4.4 **R-19 Depth follows risk.** A higher risk level MUST mean more testers and more scenarios.
6.4.4.a Functional · A7, 4.7.a · P1 · analysis. (Counts per level: 10.10.)
6.4.4.b Deeper testing for riskier change, like any external tester (operator, 4.7).
6.4.4.c Given two outside PRs rated medium and high, when tests are requested, then the high one has more testers and
more scenarios than the medium one.

6.4.5 **R-20 Results judged like field reports.** Test results MUST be judged as field reports are (WORKS / FAILS
with evidence), under the normal review logic.
6.4.5.a Functional · 4.7 (operator), 4.7.a · P1 · inspection.
6.4.5.b "Have the test results judged like we do with any external tester" (4.7).
6.4.5.c Given a WORKS comment without evidence, when AEF builds the recommendation, then it counts as no result.

6.4.6 **R-21 No step-down for outside PRs.** An outside PR MUST get the review rung its raised risk level requires.
A high-risk outside PR MUST wait, labelled "waiting for review strength", until a rung-5 panel can run; a step-down
for outside PRs MUST be impossible.
6.4.6.a Security invariant · 4.18.h (T-4997 dependency) · P1 · test.
6.4.6.b The operator chose "it waits" (4.18.h).
6.4.6.c Given a high-risk outside PR and no rung-5 panel available, when AEF processes it, then it is labelled
"waiting for review strength", no merge recommendation is posted, and no step-down is recorded.
6.4.6.d Holds against: 2.7.a (malicious contributor), 2.7.d (hurried approver).

6.4.7 **R-22 Deep tests move to the own runner.** When the own runner (R-15) exists, deep tests of outside PRs MUST
run there.
6.4.7.a Operational · A7 · P3 · demonstration.
6.4.7.b The own runner is the isolation the operator wants under their control (A6, A7).
6.4.7.c Given the own runner is live, when a deep test is requested, then it runs on the own runner.

### 6.5 The operator's time

6.5.1 **R-23 A queue of three.** At most 3 outside PRs MUST wait for the operator's merge at once; further PRs MUST be
labelled "waiting" and not reviewed until a slot frees.
6.5.1.a Operational · A16 · P1 · test.
6.5.1.b Caps approval load (approval fatigue, 4.18.c).
6.5.1.c Given 3 outside PRs awaiting merge, when a fourth passes intake, then it is labelled "waiting" and no review
is dispatched for it until one of the three is merged or refused.

6.5.2 **R-24 One screen per PR.** Each outside PR MUST get a one-screen AEF recommendation: what it changes, risk
level, test results, and merge / change / refuse.
6.5.2.a Interface · A16 · P1 · inspection.
6.5.2.b The operator decides from one screen (A16).
6.5.2.c Given a PR ready for the operator, when the recommendation is posted, then it contains all four parts.

6.5.3 **R-25 One-line refusals, approved.** A refusal MUST be one line on the PR, drafted by AEF and posted only after
the operator approved it.
6.5.3.a Functional · A16, Mehdi point 6 · P1 · test.
6.5.3.b Refusing is the operator's decision; one line is enough (Mehdi point 6).
6.5.3.c Given AEF drafts a refusal, when no operator approval is recorded, then nothing is posted.

### 6.6 Peer requests as issues

6.6.1 **R-26 What moves.** Peer bug reports, enhancement requests and other structural items MUST live as GitHub
issues. Field reports, live consults, notices and replies MUST stay on the sidecar.
6.6.1.a Functional · A10, A1.b · P1 · inspection. (Further structural kinds: 10.1.)
6.6.1.b GitHub gives a numbered thread and lifecycle; the sidecar delivers into a running session.
6.6.1.c Given a peer files a bug report, when it is processed, then it ends as a GitHub issue; given a live consult,
it stays on the sidecar.

6.6.2 **R-27 Relay for every peer.** Every peer MUST be able to report to AEF over the sidecar without any GitHub
account, and AEF MUST file the issue naming the source project (subject to R-33).
6.6.2.a Functional · A11 · P1 · demonstration.
6.6.2.b The relay is the path every agent has (A11).
6.6.2.c Given a peer with no token sends a bug report to AEF, when AEF processes it, then a relayed issue exists
naming the source project, or the report is held (R-30).

6.6.3 **R-28 Fresh rewrite.** AEF MUST write each relayed issue from a fixed template in its own words; publishing a
peer's raw text MUST be impossible on the relay route.
6.6.3.a Security invariant · F1, 4R.1.a · P1 · test.
6.6.3.b A filter that repairs text misses what it cannot recognise; rewriting removes the copy path (4R.1).
6.6.3.c Given a peer report containing a sentence S, when AEF drafts the issue, then S does not appear verbatim and
the draft follows the template's fields.
6.6.3.d Holds against: 2.7.c (confused agent).

6.6.4 **R-29 The cleaning gate.** All public text (titles, bodies, comments, verdicts) on both the relay and the
direct route MUST pass one shared cleaning gate that refuses on any hit and never repairs. It MUST be impossible for
public text to contain: host names; IP addresses; file paths on estate machines; account and user names; tokens,
keys and secrets; TermLink hub ids; personal data (email addresses, real names other than a contributor's own GitHub
name, phone numbers); content from a project's own data; open security weaknesses; estate layout (which host runs
what, network layout, backup locations). Anything the gate cannot classify MUST be held, never posted.
6.6.4.a Security invariant · F1, 4R.1.a, A14, A11, 4R.5.a, 4R.6.c · P1 · test.
6.6.4.b The mirror is public and a leak is never undone; one gate for both routes (A11).
6.6.4.c Given a draft containing an item of any listed class, when it is submitted on either route, then the gate
refuses, nothing is posted, and the report becomes held with the class named. Given a draft the gate cannot
classify, then it is held.
6.6.4.d Holds against: 2.7.c (confused agent), 2.7.b (careless or compromised peer). (The direct route's limit:
7.7.)

6.6.5 **R-30 A refusal never loses a report.** Every peer report MUST be recorded locally on arrival, before any public
step. A refused draft MUST stay in a visible held state with its reason; AEF rewrites it; a report still held after a
set time or number of attempts MUST surface to the operator by name (operator pending, Watchtower). The sender MUST
be told the issue number or that it is held and why. A report MUST NOT be bounced back as the sender's only copy.
6.6.5.a Functional (reliability) · 4R.1.b, 4R.6.d · P1 · test. (Limits: 10.11.)
6.6.5.b "We ping it back and it disappears in the void" is what the operator wants to prevent (4R.1.b).
6.6.5.c Given a report whose draft is refused, when the held limit passes, then it appears in operator pending by
name, and the sender has received a held notice with the reason.
6.6.5.d Holds against: 2.7.c (confused agent dropping a report).

6.6.6 **R-31 Peer keeps until acknowledged.** A peer MUST keep its report until AEF acknowledges with an issue number
or a held status; the sidecar MUST hold reports while AEF is down; a report waiting too long MUST surface to the
operator by name.
6.6.6.a Operational · 4R.6.d, 4.18.d · P1 · test.
6.6.6.b Separates receipt from publication so nothing is lost while AEF is down (F6).
6.6.6.c Given AEF is down, when a peer sends a report, then the message is held and, when AEF returns, processed
and acknowledged.

6.6.7 **R-32 AEF has no veto.** AEF MUST file every relayed report that passes the cleaning gate and MAY add its view
as a comment. Only the cleaning gate MAY hold a report, and visibly; silent dropping by AEF MUST be impossible.
6.6.7.a Security invariant · 4R.6.d · P1 · analysis (every local record ends as issue or held).
6.6.7.b Disagreement about a request must not erase it (F6).
6.6.7.c Invariant: every locally recorded peer report is in exactly one of: filed (with issue number), held (with
reason).
6.6.7.d Holds against: 2.7.c (confused agent).

6.6.8 **R-33 Naming the source project.** A relayed issue MUST name the real source project by default. A project
that asks not to be named MUST appear as "reported by a project in the maintainer's estate", with the mapping kept
only in AEF's local ledger; its name appearing publicly MUST be impossible.
6.6.8.a Security invariant · F4 · P1 · test.
6.6.8.b "Unless requested otherwise" (F4).
6.6.8.c Given a project on the opt-out list, when an issue is filed for it, then the public text carries the
placeholder phrase and not the project's name.
6.6.8.d Holds against: 2.7.c (confused agent).

6.6.9 **R-34 Project id stamp.** Relayed issues and direct posts MUST carry the project id of the source project.
Nothing else from TermLink (host, hub id, address) MAY appear publicly; the full address MUST stay in AEF's local
ledger, used only to reach the project over the sidecar.
6.6.9.a Interface · 4R.5, 4R.5.b, 4R.6.c · P1 · test. (How the stamp is trusted: 10.7.)
6.6.9.b Identity comes from the stamp, not from who is logged in to GitHub (4R.5).
6.6.9.c Given a relayed issue, when its public text is read, then it contains the project id and no host name or
hub id; and AEF's ledger maps the issue to the full address.

6.6.10 **R-35 Security reports stay private.** Security reports MUST go through GitHub private vulnerability reporting,
with a short `SECURITY.md` pointing there; estate peers MAY report over the sidecar. Filing a security report as a
public issue through the relay MUST be impossible.
6.6.10.a Security invariant · A15 · P1 · test and inspection.
6.6.10.b An open weakness in public helps an attacker before the fix ships.
6.6.10.c Given a peer report classified as a security weakness, when AEF processes it, then no public issue is filed
and the report goes to the private route.
6.6.10.d Holds against: 2.7.c (confused agent), 2.7.a (an attacker reading public issues).

### 6.7 Accounts and credentials

6.7.1 **R-36 No per-peer bot accounts.** The GitHub accounts the framework uses MUST be only the operator's personal account and the secondary account (R-37); peers get tokens, not accounts.
6.7.1.a Operational · 4R.5.b, 4R.6.a, F5 · P1 · inspection.
6.7.1.b GitHub allows one free machine account per person; the concern was the number of accounts (4R.6.a).
6.7.1.c Given the arc is done, when GitHub accounts used by the framework are listed, then there are exactly the
operator's personal account and the secondary account.

6.7.2 **R-37 One secondary account.** One secondary GitHub account, owned by the operator (password, 2FA), MUST be
used for creating and updating issues and writing PR comments only; machine traffic MUST NOT use the operator's
personal account.
6.7.2.a Security invariant · 4R.6.c, 4.18.a · P1 · inspection.
6.7.2.b Machine traffic leaves the personal account; the account's rights are narrow (4R.6.c).
6.7.2.c Given the secondary account, when its repository role is inspected, then it can write issues and comments
but cannot push or merge; and AEF-generated issues and comments are authored by it.
6.7.2.d Holds against: 2.7.b (compromised token: the damage is limited to issues and comments).

6.7.3 **R-38 Tokens per holder.** The operator's AEF instance MUST hold its own token of the secondary account. Each
trusted peer MUST hold its own fine-grained token, scoped to issues and PR comments on this repo only (no push, no
merge), revocable alone without affecting other holders.
6.7.3.a Security invariant · 4R.6.b, 4R.6.c, 4.18.b, 4.18.f · P1 · test.
6.7.3.b A compromised host costs only its own token (4.18.b).
6.7.3.c Given peer P's token is revoked, when P posts, then GitHub refuses; when AEF and another peer post, then they
succeed.
6.7.3.d Holds against: 2.7.b (compromised peer token).

6.7.4 **R-39 Operator-owned trusted list.** The trusted-peer list MUST be an operator-owned policy file; an agent
changing it MUST be impossible without the operator's recorded approval. Peers not on it MUST use the relay.
6.7.4.a Security invariant · 4R.6.a, 4R.6.c · P1 · test.
6.7.4.b Trust in a peer is the operator's decision.
6.7.4.c Given an agent session, when it writes an entry into the trusted-peer list, then the write is refused or
flagged for the operator.
6.7.4.d Holds against: 2.7.c (confused agent), 2.7.b (compromised peer).

6.7.5 **R-40 Tokens never in the repo.** Each token MUST live in its holder's credential store, named in a registry
by reference; a token value in the repo MUST be impossible to commit unnoticed.
6.7.5.a Security invariant · 4.18.a · P1 · test.
6.7.5.b The repo is public.
6.7.5.c Given a commit containing a token value, when the pre-commit and CI checks run, then they refuse it.
6.7.5.d Holds against: 2.7.c (confused agent).

### 6.8 Lifecycle and verdicts

6.8.1 **R-41 Relayed issues get the full lifecycle.** Relayed issues MUST carry a `relayed` label and a source field,
and `fw issues sync` MUST give them the full lifecycle (stages and confirmation); where sync would wait for the
GitHub author it MUST wait for the source project's verdict over the sidecar. The same applies to direct posts.
6.8.1.a Functional · F2, 4R.6.c · P1 · test.
6.8.1.b Today owner-authored issues are ledger-only, which would drop the lifecycle the move is for (F2).
6.8.1.c Given a relayed issue, when sync runs, then it posts the lifecycle stages and, at fixed, waits for the source
project's verdict rather than a GitHub reply.

6.8.2 **R-42 Ask the source to check.** When an issue reaches fixed or released, AEF MUST tell the source project's
agent to check, naming the issue, the task and the be-tag; the verdict MUST come back as a field report and confirm
or reopen the issue.
6.8.2.a Functional · A12, A1.b · P1 · demonstration.
6.8.2.b Closes the loop with the reporter (A1.b).
6.8.2.c Given a relayed issue moves to fixed, when sync runs, then the source project receives a sidecar message with
the issue, task and be-tag; given its WORKS verdict, the issue is confirmed.

6.8.3 **R-43 FAILS reopens.** A FAILS verdict (from the source project over the sidecar, or a "not fixed" reply on
GitHub) MUST reopen the issue: back to accepted, the task reopened or a follow-up linked, and a cleaned public comment
posted.
6.8.3.a Functional · F3 · P1 · test.
6.8.3.b Today a FAILS verdict has no reopen path (F3).
6.8.3.c Given a closed or fixed issue, when a FAILS verdict arrives, then the issue is open at stage accepted, a task
is open for it, and a comment passed by the cleaning gate is posted.

6.8.4 **R-44 The sweep waits for requested checks.** The 14-day sweep MUST skip an issue while a requested check is
pending; an overdue check MUST surface to the operator by name instead of closing the issue.
6.8.4.a Functional · F3 · P1 · test.
6.8.4.b The sweep could close an issue while the source's verdict is in flight (F3).
6.8.4.c Given an issue released 15 days ago with a pending check, when the sweep runs, then the issue stays open and
appears in operator pending as overdue.

### 6.9 Duplicates

6.9.1 **R-45 AEF matches every new ticket.** `fw issues sync` MUST match every new ticket (relayed and direct) against
existing tasks and tickets, using the component fabric, the vector index and BM25 keyword search.
6.9.1.a Functional · F7, 4R.7.b · P2 · test.
6.9.1.b Pickup dedup is lost on the GitHub route; AEF has far stronger tools (F7).
6.9.1.c Given a new ticket describing an existing open ticket's problem in other words, when sync runs, then the
existing ticket is named as a match with a confidence.

6.9.2 **R-46 Link by confidence.** A high-confidence match MUST link the new ticket to the main ticket (or close it as
part of it) and record the link in the main ticket. A medium-confidence match MUST only post "possible duplicate of
#N" for the operator. Only a high-confidence match MAY create a link.
6.9.2.a Functional · F7, 4R.7.a.b · P2 · test. (Thresholds: 10.18.)
6.9.2.b A wrong link silently drops a reporter's problem (4R.7.a).
6.9.2.c Given a medium-confidence match, when sync runs, then a "possible duplicate" comment is posted and no link is
made.

6.9.3 **R-47 Closing the main closes the linked.** When a main ticket is closed, all tickets still linked to it MUST be
closed.
6.9.3.a Functional · F7 · P2 · test. (Pending checks of linked reporters: 7.10.)
6.9.3.b One fix settles all reports of one problem (F7).
6.9.3.c Given a main ticket with two linked tickets, when the main is closed, then both are closed with a comment
naming the main.

6.9.4 **R-48 A linked reporter's FAILS reopens its own ticket.** If a linked reporter's check FAILS, its own ticket
MUST be reopened and unlinked.
6.9.4.a Functional · 4R.7.a.a, 4R.7.b · P2 · test.
6.9.4.b The symptom may differ from the main ticket's (4R.7.a).
6.9.4.c Given linked ticket L of main M, when L's reporter sends FAILS, then L is open, no longer linked to M, and M
records the unlink.

### 6.10 Migration

6.10.1 **R-49 Forward only.** The processed pickups MUST stay as they are (each already became a task); the
auto-deferred pickups MUST be filed on GitHub when their blocker clears.
6.10.1.a Operational · F8, A17 · P2 · analysis.
6.10.1.b Replaying old envelopes would duplicate tasks and could publish old host detail (codex 7).
6.10.1.c Given migration is done, when the issue list is compared with the pickup ledger, then no processed pickup
has a new issue, and each auto-deferred pickup whose blocker cleared has one.

6.10.2 **R-50 The old command is wrapped.** `fw pickup send` for bug reports and feature proposals MUST route to the
new filing command (direct for trusted peers, relay for the rest); learnings and patterns MUST stay on the sidecar.
6.10.2.a Interface · F8, A13 · P2 · test.
6.10.2.b Old agents keep working; nothing breaks at the cutover.
6.10.2.c Given a peer runs `fw pickup send` with type bug report, when it completes, then the report is on the new
route (issue or held), not in the old pickup inbox; given type learning, it goes over the sidecar as before.

6.10.3 **R-51 Issue templates ask for clean input.** The GitHub issue templates MUST ask for a cleaned description and
the project id, not raw `fw doctor` output or logs.
6.10.3.a Interface · F8 · P2 · inspection.
6.10.3.b Today's forms request raw output and logs, which carry host detail (codex 7).
6.10.3.c Given the issue templates, when read, then no field asks for raw command output or logs, and one field asks
for the project id.

6.11 Summary: 51 requirements (R-1 to R-51); the 18 that make something impossible each name their adversary
(item d).

PLACEHOLDER-7-9
