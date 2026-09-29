# T-3557 spike — independent reviewer verdicts on 10 open Human ACs

Reviewer: t3557-spike (independent, read-only). Date: 2026-09-30.
Watchtower: http://192.168.10.107:3002. Note: `bin/fw watchtower current` reported the running process
STALE against `web/blueprints/arcs.py` and `web/blueprints/bvp.py`. Both are uncommitted in-flight
changes (T-3574 perf work). No template was stale, so the render checks below reflect committed templates.

1. T-1718: Confirm gate UX on a synthetic task is actionable, not punitive
VERDICT: green
WHY: I fired the real gate on a synthetic task. I extracted `check_evolution_log()` from
`agents/task-create/update-task.sh:776` and ran it in isolation against a temp arc-tagged build task
(`arc_id: value-prioritisation`) whose `## Evolution` held only a template comment, with
NEW_STATUS=work-completed. It printed "ERROR: Cannot complete arc-tagged build task — ## Evolution
section is empty/template-only." The message cites T-1718, names the `## Evolution` section and the
file path, and gives the example entry format (`### YYYY-MM-DD — [topic]` with What changed / Plan
impact / Triggered). It states the ≥30-char rule and lists "Use --skip-evolution to bypass (logged
Tier-2, T-1718)". It explains why, gives two options, and does not scold. The helper unit tests
(`tests/unit/evolution_log_gate.bats`, 17 tests) all pass. The audience for this message is agents
that trip the gate (T-2143), so this did not need the operator.
GUIDANCE: none. Optional: add a bats test that invokes `check_evolution_log` end-to-end. The existing
bats cover only the helper functions, not the gate firing.

2. T-334: Record 3-min demo video (Tier 1 action #5)
VERDICT: escalate
WHY: The Expected clause ("Video linked in repo README") appears met. README.md:6 links
https://youtu.be/qyjFjMHLWxM. YouTube oEmbed gives the title "Agentic Engineering Framework
Explained", channel Geelenandcompany.com. It was added by T-2678 at the operator's request. I cannot
confirm that this explainer is the 3-minute "Tier 0 block → task gate → audit pass" demo the AC
describes. Its length and content are not verifiable without watching it. Recording and publishing
a video is an outside-world act by the operator, and this criterion is also the go signal for a
public Show HN launch.
GUIDANCE: The operator should watch the video and rule on one question: does the existing explainer
satisfy this criterion? If yes, tick it; the outcome is already in place. If no, record the
Tier 0 → gate → audit demo and link it. Either way, the Show HN timing stays the operator's call.

3. T-3242: Tag-as-canonical is the right ruling for the release train
VERDICT: escalate
WHY: This is a sovereignty and project-direction call. It sets which version identity consumers
inherit from the install surface. The mechanism works as the ruling describes. The ## Decisions
section records the rejected inverse, and `bin/fw release tag-and-release --dry-run` refuses a
decreasing release. One piece of live evidence the operator should see before ruling: the dry-run
refuses a plain patch release today. The working-tree VERSION is 1.7.307 (uncommitted; it was
1.7.288 in HEAD) and the newest tag is v1.7.0. The output reads: "REFUSING to release: tag v1.7.1
would DECREASE VERSION (1.7.307 → 1.7.1) … reconcile VERSION or bump past it (--bump minor|major)".
So under this ruling, VERSION (still a per-tag commit counter) runs ahead of the tag line between
releases, and every default-bump release refuses until someone reconciles by hand. The ruling is
defensible, but in practice it currently makes `--bump patch` unusable. Also, the Step 1 text ("now
both 1.6.768-anchored") is out of date: `git show v1.6.768:VERSION` prints 1.6.72.
GUIDANCE: The operator decides whether tag-as-canonical stands, knowing about the patch-release
refusal above. If it stands, file a follow-up so that `fw version sync` / `_derive_version` stops
producing a VERSION ahead of the next patch tag, or so that the release reconciles automatically.
Otherwise every release needs a manual step.

4. T-2430: Lock-1 Part 1 — as root, deploy the holder under a dedicated non-agent service account
VERDICT: escalate
WHY: This is a root/sudo install of a security-critical privilege boundary: a service account,
read-only bind mounts, and `chattr +a` on the audit log. That puts it in the Tier 0 / consequential
and credential-handling classes. It is also not done yet: `systemctl status aef-govd` returns "Unit
aef-govd.service could not be found". The artefacts exist (`lib/govd_holder.py`,
`agents/govd/govd.sh`).
GUIDANCE: The operator runs the AC's Steps 1–3 as root after reading `lib/govd_holder.py` and the
emitted unit. Evidence of success: `systemctl status aef-govd` active, and a write from the
unprivileged account to the envelope fails with EACCES.

5. T-1957: Approve, reject, or --none the 3 proposed scoped drivers for arc-006
VERDICT: amber
WHY: D-586 / T-3429 changed how this works: adding a driver is now reviewer-gated, not a human call.
Only `--none` stays sovereign. Current state of `.context/arcs/value-prioritisation.yaml`:
- arc status is already `in-progress` (the AC's Expected transition has happened);
- `estimator-fidelity` (w3) is already in `scoped_drivers:` (approved 2026-05-21);
- two proposals remain.

`bin/fw arc review-driver value-prioritisation --all --dry-run` gives these verdicts:
- sovereignty-preservation: PASS on all three checks (scorable handler, distinct, 698-char rationale naming D1/D2/D4);
- adoption-friction: FAIL on (a) scorable, "no handler, no inline scoring: block, no scoring_file: (T-3428)". It passes (b) and (c).

No human decision is needed here.
GUIDANCE: The agent (not the human) should:
1. run `bin/fw arc approve-driver value-prioritisation --all-reviewed` to add sovereignty-preservation (this brings the arc to 2 of the cap of 3);
2. either write a `scoring:` spec for adoption-friction (validate with `fw bvp driver --validate-scoring`) and re-review it, or leave it proposed;
3. once that is done, reword the AC as an agent AC and tick it.
`--none` is moot because a driver is already approved.

6. T-3356: The audit.sh extraction is the right call, and the Sovereign question is correctly deferred
VERDICT: green
WHY: The extraction checks out.
- Commit 6904e656e moved anchor_task detection into `lib/audit-anchor-task.sh`, sourced at `agents/audit/audit.sh:23`.
- `bats tests/unit/audit_anchor_task_existence.bats` passes 9/9 in 1s (previously it hit >500s timeouts), including "audit.sh still emits warn + pass_over for the anchor rule".
- The RCA states the end-to-end equivalence on a fixture corpus.
- The disposition "behaviour-preserving, AC2 vs AC4 tension recorded" is honest and sound.

The deferral also checks out. The nested 188s `bats tests/lint/` question is registered as OBS-388
in `.context/inbox.yaml` (pending, headed "SOVEREIGN QUESTION (T-3356)") and cross-referenced from
OBS-391 and T-3302. Changing the audit's reporting contract is correctly left to the operator and
not made by an agent. The AC asks whether it was correctly deferred, and it was.
GUIDANCE: none for this AC. Separately, OBS-388 itself still awaits an operator ruling. It is the
main cost in the T-3302 nightly timeout and the T-3328 A4 blocker, so it deserves a slot in the
operator's queue.

7. T-1909: Arc badge placement and styling read well visually
VERDICT: green
WHY: I checked the live render with headless Playwright at 1400×900.
- /tasks: 15 `a.arc-badge` elements, e.g. "arc-003 · orchestrator-rethink". Computed style: 11.52px font, 999px radius (a pill), white on rgb(107,104,94), 1.6×7.2px padding. In the screenshot the dark pill is legible and smaller than the task name. It is clearly distinct from the white status/type/horizon selects and the grey BVP chip.
- /arcs/arc-grooming: 40 badges in the constituent table.
- Link: href `/arcs/orchestrator-rethink`, and navigating to it returns HTTP 200. The hover style is defined (`.arc-badge:hover` inverts to the secondary colours).
Screenshot: /tmp/t3557-badge.png.
GUIDANCE: none. This is a visual-taste criterion with no risk class, so it is decided here.

8. T-2087: /arcs/orchestrator-rethink (121 tasks) is navigable — table scrolls within bounds, header row stays visible
VERDICT: red
WHY: The table is bounded, but the header does not stick.
- Bounded: `.constituents-scroll` has max-height 60vh (540px at 900px viewport) and overflow-y auto, and holds 124 rows (12,063px of table).
- Not sticky: I scrolled `.constituents-scroll` to scrollTop=800. The container top stayed at 0, but the thead moved from top=1 to top=-799, i.e. out of view. The screenshot (/tmp/t3557-orch.png) shows rows with no header row.
- Root cause: the JS in `web/templates/base.html:1038-1040` wraps every bare `#content table` in `.table-responsive` (`overflow-x: auto`, base.html:346). That forces a computed `overflow-y: auto`, so the wrapper becomes the nearest scroll container for `position: sticky`. The wrapper is as tall as the table (12,063px) and never scrolls itself, so the sticky thead from `arc_detail.html:516` never engages. The outer `.constituents-scroll` is the element that actually scrolls.
- Separately, the full page is 5,592px (about 6 screens at 900px) because of the T-3564 story sections. That is by design and not this AC's defect.
- Load time was about 1.1s in my runs, so T-3574 did not interfere.
GUIDANCE: Build fix (agent): make the base.html auto-wrap skip tables that already sit inside a
scroll container, e.g. `:not(.constituents-scroll table)` or a `data-no-wrap` opt-out. The
alternative is to make `.constituents-scroll` the only scroller. Then add a Playwright geometry test:
scroll `.constituents-scroll` by 800 and assert that thead top ≈ the container top. Re-verify after
`bin/fw watchtower restart`. T-2087 is `work-completed` in active/, so the fix probably belongs in a
new bug task that references T-2087.

9. T-3335: Live wire-level smoke of the claim mutex
VERDICT: green
WHY: `termlink hub status` showed the hub running (PID 403200). I ran
`python3 tests/manual/s8_claim_smoke.py`, which exited 0:
- A: role=won, B: role=lost, "holder named = cand-A-…" (the LOST row names the winner);
- "after release → C: role=won";
- "released → re-electable", then SMOKE PASS.
This is internal and reversible (a throwaway smoke topic), so no human is needed.
GUIDANCE: none. Caveat for the arc-close demo: the script elects A then B one after the other, not
concurrently. It proves first-claim-wins and holder naming on real termlink, but not true
simultaneous contention. If the G1 demo needs that, add a threaded or two-process variant.

10. T-332: PRs merged or pending review
VERDICT: green
WHY: `gh pr view` shows:
- bradAGI/awesome-cli-coding-agents#2: MERGED 2026-03-09.
- e2b-dev/awesome-sdks-for-ai-agents#78: OPEN, no review decision, last updated 2026-03-06.
The criterion accepts "merged or pending review", so it is met. This is a read-only check; no
outside-world action was needed.
GUIDANCE: none for the AC. FYI: PR #78 has had no activity for about 7 months. Pinging or closing it
is an outside-world action and stays with the operator. The two deferred lists (kyrolabs/awesome-agents,
alebcay/awesome-shell) are outside this criterion.

---
Verdicts: 5 green, 1 amber, 1 red, 3 escalate (10 total)
