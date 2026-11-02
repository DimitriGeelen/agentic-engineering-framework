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
4.2 A2, A4 to A9: not yet asked.
4.3 **A3 Where a merged PR lands** (2026-11-02, given with A1): the operator merges, and the merge lands on
GitHub; OneDev is no longer where it lands. This is option 3 of Q3: GitHub becomes the source repo.
4.3.a Follow-up open: is OneDev retired, kept as a mirror of GitHub, or kept as a backup only?
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
