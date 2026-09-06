# T-3289 Observation Triage — Worker w1

Scope: OBS-201, OBS-203, OBS-214, OBS-231, OBS-234, OBS-235, OBS-236, OBS-245, OBS-246, OBS-271.
Each verdict verified against the current tree (branch `bleeding-edge`, 2026-09-06), not against the observation text alone.

**Tally: 4 PROMOTE / 6 DISMISS / 0 DEFER**

---

## OBS-201 — `yaml,sys` screenshot in repo root (python-as-shell)

**VERDICT: DISMISS — already fixed by T-2990.**

- The artifact is gone: `ls ./yaml,sys` → no such file. T-2990's Verification pins removal of all four junk files (`os`, `sys`, `yaml`, `yaml,sys`) — `.tasks/completed/T-2990-root-level-postscript-junk-written-by-im.md:230`.
- Consequence (1), the mechanism diagnosis, was done and *reproduced, not asserted*: a python `import yaml,sys` line executed as bash runs ImageMagick's `import` screenshot tool with the last token as output filename (T-2990 task body lines 255-265, AC at line 105 with a fake `import` on PATH).
- Consequence (2), detection, shipped: `lib/root-pollution.sh` + `fw doctor` WARN "Repo root: N untracked binary file(s)" (`bin/fw:1698-1712`, commit 2d6d7c668).
- Nothing in the observation remains unaddressed.

## OBS-203 — `.budget-status` cross-session fail-open

**VERDICT: PROMOTE — residual half of the fix is missing in the enforcement reader.**
Proposed task: "budget-gate fast path must reject a `.budget-status` cache it cannot attribute to its own session (OBS-203 residual)" — workflow_type: build.
AC: a bats test writes a fresh `.budget-status` attributable to a different session/process and asserts budget-gate's fast path treats it as unknown and falls through to the slow path (transcript re-scan) instead of enforcing on it.

- T-3241 shipped the observation's fix shape *partially*: every writer now stamps `session_id` (`agents/context/budget-gate.sh:358,402,415,425`) and `checkpoint.sh budget` is a safe reader that reports `unknown` on a foreign-session cache (T-3241 ACs 198-199, six-case bats).
- But the enforcement reader — budget-gate's own fast path — still loads only `level`/`tokens`/`timestamp` with no `session_id` comparison (`agents/context/budget-gate.sh:143-152`). The exact fail-open path OBS-203 measured (foreign low value → gate reads "ok" near critical) is still open at the gate that blocks/allows tools.
- Second residual worth carrying into the task: the stamp is read from the shared `.context/working/session.yaml`, which a concurrent cron `claude -p` worker in the same project also reads — so the stamp identifies the *project*, not the *writing process*, and may not discriminate the very scenario OBS-203 described. The fix should attribute the write to a process/transcript, not to the shared session file.

## OBS-214 — resolver in-flight latch live repro + incomplete self-vendor bypass

**VERDICT: DISMISS — both findings fixed (T-2915; T-3125/T-3126).**

- Primary (latch never expires): T-2915, T-2916, T-2917 all in `.tasks/completed/`. The age bound is implemented in `lib/resolver.py:66-81` (`FW_RESOLVER_INFLIGHT_MAX_AGE_MIN`, comment cites "nine tasks latched five weeks, T-2915 origin").
- Secondary (FW_SKIP_SELF_VENDOR_CHECK skips the hook check but not the pre-push audit): structurally dissolved rather than patched. T-3125 made the pre-push self-vendor gate judge the *committed tree being pushed* — working-tree-only drift is "WARN … push allowed" (`agents/git/lib/hooks.sh:981`). T-3126 added the ref/worktree scope partition to audit FAILs (`agents/audit/audit.sh:566-586`) and the pre-push hook now treats worktree-scoped audit FAILs as non-blocking (`agents/git/lib/hooks.sh:1130-1178`). The "2 commits unpushable while a concurrent worker holds the tree" scenario no longer blocks.

## OBS-231 — owner vocabulary: 10 invalid rows at rest, no at-rest validator

**VERDICT: PROMOTE — still true, and the corpus churned exactly as predicted.**
Proposed task: "owner-at-rest audit rail (CTL-030 shape) + repair the 10 invalid owner rows (OBS-231)" — workflow_type: build.
AC: `fw audit` emits a WARN naming every task file whose frontmatter `owner:` is empty or outside {human, claude-code, agent}, and the current invalid rows are repaired to valid values.

- Re-measured today (frontmatter-scoped, 3276 task files): still exactly 10 invalid — 6 × `claude` (T-327, T-1875, T-1877, T-1878, T-2057, T-2058 — same six as the observation) + 4 × empty.
- The empty set churned: OBS-231 listed T-249, T-1511, T-2567, T-2720; today it is T-249, T-1511, T-2567, **T-3172** (`.tasks/completed/T-3172-bpmn-compiler-rejects-the-frozen-standar.md`). One repaired, one *new* invalid row appeared — direct confirmation of the observation's thesis that nothing validates files at rest and the state silently drifts.
- No rail exists: the only owner check in audit is CTL-025, which validates owner *only* for partial-complete tasks in `active/` (`agents/audit/audit.sh:4910-4927`). `is_valid_owner()` (`lib/enums.sh:101`) is reachable only at the create/update seam, exactly as the observation stated.

## OBS-234 — 4 hook-shaped scripts that cannot fire

**VERDICT: PROMOTE — still true, byte-for-byte.**
Proposed task: "resolve 4 orphaned hook-shaped scripts in agents/context/: wire into settings.json or decommission (OBS-234)" — workflow_type: decommission.
AC: each of check-dispatch-pre.sh, check-visual-verification.sh, commit-cadence.sh, pl007-scanner.sh is either registered in `.claude/settings.json` or removed/relocated with a Decisions entry recording why.

- Verified today: all four scripts still exist in `agents/context/` and all four have **zero** references in `.claude/settings.json` (grep count 0 for each).
- No fix task exists: the only `.tasks/` references to OBS-234 are the census task T-2940 (origin) and two unrelated rail tasks. The misleading-standing-guard hazard the observation names is unchanged.

## OBS-235 — curriculum corpus routes dead in consumers (tools/ not vendored)

**VERDICT: DISMISS — already fixed by T-2942.**

- `.tasks/completed/T-2942-vendor-the-corpus-reader-and-aef-maps-so.md:63` opens with "Fix for **OBS-235**". Its ticked AC: "`tools/` is in `do_vendor`'s includes list" (line 90); `.context/designer/projects` is vendored wholesale (Decision at line 131) and path resolution works framework-relative by construction (lines 80-83, 145-146).
- Present in current code: `bin/fw:536` `includes=(...)` with the tools/corpus origin comment at `bin/fw:564-576`.
- Hardened since by T-3144 (`lib/vendor-visibility.sh`): post-vendor check that the consumer's git can actually *see* what was written, catching the stale-allowlist re-drop loop that would regress this class.

## OBS-236 — agent-side grep is a ugrep shim; recursive sweeps drop ignore-pattern-matched files

**VERDICT: PROMOTE — measured, twice-corrected, bounded, and never codified.**
Proposed task: "codify the agent-side ugrep-shim divergence as a learning + CLAUDE.md note; re-measure any `grep -r`-authored baselines (OBS-236)" — workflow_type: build.
AC: a learning entry exists (`fw context add-learning`) plus a CLAUDE.md/agent-facing note stating that agent-side *recursive* grep silently drops files matched by any in-scope ignore pattern (including tracked files like `.context/working/focus.yaml`), and that only `grep -r`-authored baselines need re-measurement.

- No learning exists (`grep ugrep .context/learnings.yaml` → nothing) and no CLAUDE.md/FRAMEWORK.md codification.
- T-2951 was the rail-exchange task: it *corrected* OBS-236's text (recursion-only bound, `--ignore-files` attribution, index-blindness mechanism — task body lines 75-93) and pinned that the inbox entry carries the corrections, but shipped no structural or documentary fix. T-3020 worked around the shim once (`-F` comment at line 185).
- The corrected observation makes the action finite: only `grep -r`-authored baselines are suspect, single-file/glob invocations are safe. That bounded scope is exactly what makes this a small, closable task rather than an open-ended sweep. The corrupted sentence it prevents — "I swept and found nothing" — is a false-green class this repo treats as its worst kind.
- (Environment note: in this dispatched worker's shell `which grep` → `/usr/bin/grep`, so the shim is harness-dependent; the codification should say *when* it applies, not assert it universally.)

## OBS-245 — `fw vendor self` copies untracked working-tree files

**VERDICT: DISMISS — already fixed by T-3165.**

- Commit 4d2bdaf2c "T-3165: fw vendor self stops sweeping a concurrent task's uncommitted files"; task in `.tasks/completed/`.
- Implementation matches the observation's suggested direction ("skip untracked sources or name them and refuse") exactly: `_sv_guard_init`/`_sv_is_withheld` (`lib/upgrade.sh:186-232`) build a dirty set from `git status --porcelain` (untracked `??` explicitly counted, comment at lines 192-193), withhold each dirty file from real runs, and *name each file at the moment it is withheld* with escape hatches `FW_VENDOR_ONLY` (caller's own files) and `FW_VENDOR_ALL=1` (logged Tier-2).
- Dry-run/`--check` deliberately unguarded so drift detection stays honest (comment at lines 174-177).

## OBS-246 — `fw handover --commit` blocks its own push via VERSION stamp

**VERDICT: DISMISS — structurally fixed by T-3125 (plus interim workaround b30bafa9c).**

- The observation's second fix direction ("treat a VERSION-only delta as not-yet-drift") shipped: `_t3125_vendor_class` in the pre-push gate excludes VERSION on purpose — "it is sync-only, outside --check, and is rewritten on every commit" (`agents/git/lib/hooks.sh:881-882`), so the handover's VERSION stamp can no longer trip the self-vendor refusal.
- More broadly T-3125 re-based the gate on the committed tree being pushed; working-tree-only staleness (which is what an in-flight handover creates) is WARN + push allowed (`agents/git/lib/hooks.sh:981`).
- Interim workaround was b30bafa9c "T-100201: vendored VERSION resync after handover stamp (OBS-246 workaround)"; T-2983 documented the live repro. Both predate the structural fix.

## OBS-271 — sender_id is not an identity discriminator on agent-chat-arc

**VERDICT: DISMISS — superseded by active task T-3286 (duplicate of in-flight work).**

- The actionable core (co-resident agents collapse to one correspondent because producers stamp no per-agent identity) is precisely T-3286, created 2026-09-06, `status: started-work` (`.tasks/active/T-3286-agent-chat-producers-must-stamp-metadata.md`): producers (`agent-send.sh:161`, `agent-respond.sh:88/96`) will stamp `metadata.agent_id`; the reader already resolves `agent_id` first and falls back to the shared crypto fingerprint only when producers stay silent (commit f06513da7, which also registers G-105).
- The `from_project` half (defaults to None, inconsistent casing) was addressed before *and* independently of this OBS by T-2905: `rail_project_label()` emits one normalized label (lowercased, separator-normalized) from config/dirname (`lib/rail-identity.sh:190-201`), `RAIL_PROJECT_LABEL` is in `FW_CONFIG_REGISTRY` (`lib/config.sh:217`) satisfying the observation's own parity constraint, and hook `check-rail-mcp-label.sh` blocks label-less MCP rail posts.
- Nothing remains that T-3286 does not carry. Recommend cross-linking OBS-271 as evidence on T-3286 at dismissal.

---

## Summary table

| OBS | Verdict | Disposition detail |
|-----|---------|--------------------|
| OBS-201 | DISMISS | fixed by T-2990 (removal + mechanism repro + root-pollution doctor rail) |
| OBS-203 | PROMOTE | build: budget-gate fast path rejects unattributable `.budget-status` (T-3241 fixed writers + checkpoint reader only) |
| OBS-214 | DISMISS | fixed by T-2915 (latch age bound) + T-3125/T-3126 (push-gate scope) |
| OBS-231 | PROMOTE | build: owner-at-rest audit rail + repair 10 invalid rows (re-verified; set churned, proving no rail) |
| OBS-234 | PROMOTE | decommission: wire-or-remove 4 orphaned hook-shaped scripts (re-verified: 0 settings.json refs) |
| OBS-235 | DISMISS | fixed by T-2942 ("Fix for OBS-235"), hardened by T-3144 |
| OBS-236 | PROMOTE | build: codify ugrep-shim divergence as learning + doc note; re-measure `grep -r` baselines |
| OBS-245 | DISMISS | fixed by T-3165 (`_sv_is_withheld` guard, names + refuses untracked/dirty sources) |
| OBS-246 | DISMISS | fixed by T-3125 (VERSION excluded from vendor-class; committed-tree basis) |
| OBS-271 | DISMISS | superseded by active T-3286 (agent_id stamping, G-105); from_project half fixed by T-2905 |
