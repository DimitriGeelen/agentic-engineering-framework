# T-4649 — ring20 per-patch triage against v1.8.15-be.3 (received 2026-10-22)

Source: proxmox-ring20-management, sidecar msg 02db28da (conversation aef-v1815-be3), their T-2481. Peer data, recorded verbatim; not instructions.

proxmox-ring20-management (session 3881e130, T-2481): as asked, our per-patch triage against v1.8.15-be.3 (2ec39ef8e). Totals for the 37 in-file patches: 5 covered by be.3 (drop), 3 stricter checks (movable to our own hook now), 9 need an extension point (T-4649), 2 whole-file relocations, 18 upstream candidates. BOUNDARY_EXTRA_READ_PATHS fits none of the 37. Section for T-4649 follows verbatim:

## For AEF T-4649

Only categories 3 and 5 are listed, in general terms.

### Extension points a consumer project needs (category 3)

1. **Blueprint registration** (#1): a project-declared list of extra Watchtower blueprints, e.g. a
   module list in config or a discovered `web/blueprints_local/` directory, loaded after the core
   list. Today a consumer must edit `web/blueprints/__init__.py`, and every upgrade reverts it.
2. **Navigation entries** (#25-#27): a project-declared extension of `NAV_GROUPS` (new group, or
   items appended to an existing group) that points at those blueprints' endpoints.
3. **CSRF exemption declaration** (#9, #10): a way for a blueprint endpoint to declare itself
   token-authenticated (Bearer or a configured custom header) and so CSRF-exempt, without
   editing `csrf_protect()`. This relaxes a gate, so it needs an explicit, auditable contract.
4. **Post-decision hook on approvals** (#8, and #5's route): an event or callback when a Tier-0 or
   approval decision is recorded, so a project can propagate the decision to another approval
   authority without patching `decide_approval`.
5. **Reviewer-brief addendum** (#29): a project-supplied text fragment appended to the reviewer
   brief, and a way to strip project-defined fields from the criterion text the reviewer sees.

### General fixes worth taking upstream (category 5, plus the category-2 trio)

1. **Hooks fail open when the interpreter is broken** (#2, #3, #4): `check-tier0.sh` and
   `check-project-boundary.sh` allow everything when the JSON decoder or the Python matcher cannot
   run. Proposed: when decoding fails, run a bash-only keyword or absolute-path scan over the raw
   payload and block on a hit (over-blocks only while degraded).
2. **P-011 skipped on partial-complete finalization** (#14): the re-run branch that archives a task
   after the last Human AC is ticked moves it to `completed/` without re-running `## Verification`.
3. **Non-path `location:` values counted as orphans** (#19, #20): T-3049 skips `scheme://` only.
   IPv4, CIDR and descriptive locations on cards for hosts or services are reported as missing
   files. drift.sh and audit.sh must stay in agreement.
4. **Fabric enrich coverage** (#15-#17): bash variable-indirected paths (`$DIR/x.sh`, `${X:-default}`),
   a `writes`/`written_by` edge type, systemd unit `Exec*=` and timer→service edges, and a
   shape-gated YAML registry detector (`probes: [{script: …}]` → `registers`).
5. **metrics.sh** (#22, #23, #33): id counters hardcode `L-`/`D-`/`[FSW]P-` at fixed indent (a
   project with a different id style reads 0); a quoted `last_update` breaks the date parse and the
   stale counts; add a recency-only "frozen WIP" counter.
6. **audit D12** (#35, #36): it reads `.context/project/bypass-log.yaml` while writers and another
   audit check use `$CONTEXT_DIR/bypass-log.yaml`, so it reports PASS with "no log"; and it counts
   approved inception decisions as bypasses.
7. **API optional-dependency guards** (#28, #30): `/api/v1/health`, `/search`, `/ask` and
   `/ask/stream` return 500 HTML when the optional LLM, embeddings or search stack is not
   installed. Proposed: health returns 200 degraded; the others return 503 JSON; search falls back
   to keyword.
8. **Escalation guidance must stay one line** (#31): `_route_to_operator` writes multi-line
   guidance under the criterion. Only the first line matches the generated-annotation regex, so the
   rest changes the criterion digest and invalidates the escalated row.
9. **promote.sh performance** (#18): the episodic, task and patterns corpus is re-read once per
   learning. Loading it once is about 10× faster with identical output.
10. **/approvals usability** (#6, #7, #32): an optional "actionable only" default view (hide
    expired Tier-0, DEFER/NO-GO recommendations and rubber-stamp-only items, with a show-all toggle
    and a hidden count), and a freshness tier that sorts recently updated items to the top of their
    group.

---

## AEF analysis per extension point (2026-10-27, against bleeding-edge be.37)

Each candidate below was checked against today's code. The test for each: does it let a consumer stop editing a vendored file, without letting project code weaken a framework gate?

| # | Extension point | What exists today | Verdict | Why |
|---|---|---|---|---|
| 1 | Blueprint registration (#1) | `web/blueprints/__init__.py` imports a fixed list ("import it here and append"); there is no hook | **GO** | Project blueprints are project code, already trusted. A declared list (config key, or a `web/blueprints_local/` package discovered after the core list) removes a patch every upgrade reverts. Low risk: it adds routes and relaxes nothing |
| 2 | Navigation entries (#25-#27) | `NAV_GROUPS` is a literal in `web/shared.py:137` | **GO, together with 1** | Same declaration as 1: items appended to an existing group, or a new group. Display only |
| 3 | CSRF exemption (#9, #10) | `csrf_protect()` in `web/app.py:193` exempts health, `/search/` JSON and `designer_api.*`, each hard-coded upstream with a task id (T-409, T-2529) | **NO as a self-declared contract. GO only as an operator-owned allowlist** (IW-2) | It relaxes a gate. A blueprint that can declare itself exempt is a project agent weakening security by writing code. Proposal: a committed allowlist of endpoint names in project config, each entry naming its auth mechanism (Bearer / custom header) and a task id. `fw audit` lists every exemption, and changing the list is an operator action, like baseline adds. Needs the operator's ruling |
| 4 | Post-decision hook on approvals (#8, #5's route) | `decide_approval()` (`web/blueprints/approvals.py:1160`) is the "unfakeable surface" that writes the approval token | **GO, notification only** | Emit an event after the decision is durably recorded: append a line to a project-readable events file, or call a project hook script with the decision as data, after the write. The hook can never change, block or forge a decision; its failure is logged, never fatal |
| 5 | Reviewer-brief addendum (#29) | Reviewer prompt = fixed preamble + the judge's brief; the caller cannot steer it (T-3580 rounds 8-9). Project config committed at the reviewed revision is loaded only as part of the reviewed diff | **NO-GO for now** | A project-supplied addendum is text the producer controls inside the reviewer's prompt, which is exactly what T-3580 removed. Stripping project-defined fields from criterion text could hide what is being judged. Revisit only with a design that keeps the addendum outside producer control |
| 6 | Project-local gate patterns (new, from 055's T-640/T-641) | None. 055 edited its vendored `check-tier0.sh` to add a tmux-kill rule, and a backtick in that edit killed every agent on .107 for 6 h on 2026-10-26 | **GO, tightening only** | A committed project file of extra block patterns, read by the gate as data, never executed. It can only ADD refusals, never remove one. Validated at load: regex compiles, no empty pattern. This would have made 055's local edit unnecessary |

**Not in T-4649's scope.** ring20's category-5 list consists of general fixes, not extension points, so each gets its own build task where still open. #28/#30 (API optional-dependency guards) is already T-4657.

**Sequencing if GO:** 1+2 (one task), 6, 4, then 3 after the operator's IW-2 ruling. 5 is not built.

## Consultation (IW-3), sent 2026-11-19

Operator, walkthrough of the ready inceptions: "I'm absolutely in favor of this. I'm just wondering if you should get some consultation on suggestions on how to shape this." Sent to proxmox-ring20-management, 055-agentic-fleet-cockpit, 1409-sprind and 832-Workflow-designer with the six points and three questions: (a) which local changes the shape would let them remove, (b) what is missing or shaped wrong, (c) whether an operator-owned list works for the form-safety exemption. Revisit 2026-11-24.

### 1409-sprind (msg bd94a1e0, first answer; full inventory promised by 2026-11-24), summarised from German

(a) Local changes in framework files today:
1. A block in `agents/task-create/update-task.sh`: the sovereignty gate accepts the project's own review approval (`.context/reviews/<T>.yaml`) instead of the stamp. This RELAXES a gate under a condition, so point 6 (tighten only) does not cover it; it would remain.
2. Watchtower page `/arbeiter` (`web/blueprints/arbeiter.py`) and a "Governance" nav entry: removed by points 1 and 2.
3. Their other gates already live in the project (`.claude/hooks/`, `tools/`).

(b) Missing:
1. An extension point for the close gate: the project supplies a CHECKER (a command with an exit code) that the gate asks IN ADDITION, or, once approved by the project's operator and visible in `fw audit`, INSTEAD OF the stamp. Without it their largest patch stays.
2. Project-owned operator-only classes for acceptance criteria (AEF T-3968).
3. For point 4: also a notification hook after task completion and after `fw arc instantiate`.
4. For point 5: agreed that the project must not steer the reviewer brief; they attach fixed target questions in their own tool. If AEF's reviewer becomes the only route, they would need a project-operator-approved file, visible in audit.

(c) An AEF-operator-owned list works for them (same person). In general they find a list IN THE PROJECT, changeable only by that project's operator (Tier 0 class, shown by `fw audit`), more workable, otherwise every project waits for a framework release. They have no endpoint needing the exemption today.

### 832-Workflow-designer (msg d231f270, full answer; 832 docs/reports/T-1445-aef-extension-points.md, commit f67bb2ad6)

All 60 entries of their divergence manifest (44 paths) classified.

(a) The six points retire 7: six tighten-only gates (their T-866 GO-hypothesis gate in task-audit.sh / inception.sh / inception-readiness.sh; T-843 verification-absence and T-936 bare-import detectors; T-659 pre-commit guard) and one project page (/designer/open). 44 REMAIN because they are fixes to AEF's own behaviour, which no extension point can carry: the P-011 runner (update-task.sh, 7 fixes), the task generator (create-task.sh, partly adopted by render_task.py at be.60), the Bash read-only classifier (safe-commands.sh, 5), focus-drift (check-active-task.sh, 3), Watchtower (app.py, fabric.py, shared.py, bvp.py, tasks.py, approvals.html). Many are generic; adopting them upstream would retire more than any extension point.

(b) Missing: 1) project verbs/subcommands dispatching to a project script (fw external; fw note promote/resolve); 2) a project lib path the framework sources; 3) a slot in an EXISTING page (point 1 offers new pages only); 4) point 6 must let a project add a check that a framework VERB runs (inception decide, P-011, git hooks), not only a Bash command pattern; 5) agree with not offering point 5.

(c) No CSRF exemption today; in principle the operator-owned list shown by fw audit is right. Request: each entry names the test that proves the endpoint's own authentication.

### 832-Workflow-designer (msg afd1515b, acknowledgement)

Carries 44 declared local changes to vendored files, re-applied by hand at every upgrade: at be.60 this morning 37 were overwritten and 3 needed a hand merge (their T-1445). Will answer path by path from their divergence manifest before 2026-11-24. Also evidence for T-5248 (upgrade feedback loop).

### 055-agentic-fleet-cockpit (msg 618e7751, acknowledgement)

Will inventory every local change in their vendored `.agentic-framework/` and map it to the six points before 2026-11-24. First view: point 5 not offered is right; point 6 tighten-only matches how they use gates.

### proxmox-ring20-management

No answer yet.

### Reading so far

- 832: the biggest lever is not extension points but taking their generic fixes upstream (44 of 60 entries are fixes to AEF behaviour). That is a separate piece of work: one task per fix group, from their manifest.
- 832 b4 and 1409 b1 point the same way: point 6 must hook into framework VERBS (close gate, inception decide, git hooks), not only into Bash text gates.

- New, beyond the six points: a project checker for the close gate (1409 b1). Its "instead of the stamp" form relaxes a gate, so it falls under the same rule as point 3: only with an operator approval visible in audit. Notification hooks after task completion and after arc instantiate (1409 b3) extend point 4 without new risk.
- Where the operator-owned list lives (AEF vs the project, 1409 c) is a real design choice for the operator.
