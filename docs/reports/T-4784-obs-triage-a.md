# T-4784 — Observation triage A (OBS-099..OBS-255)

Range: pending observations OBS-099 through OBS-255 in `.context/inbox.yaml` (126 entries).
Checked 2026-10-26 against bleeding-edge @ eea53bb06+ (code, git log, completed tasks, commands run today).
Read-only worker: nothing but this file was written.

| Verdict | Count |
|---|---:|
| RESOLVED | 61 |
| DUPLICATE | 15 |
| STILL-VALID | 32 |
| UNCLEAR | 18 |
| **Total** | **126** |

Notes for the parent:
- Several clusters chain corrections. The focus-theft chain OBS-143/144/147/208/210/211 ends at OBS-212 (the resolver loop was the writer). OBS-212 itself is RESOLVED: focus is per-session now (`check-active-task.sh:49` `fw_focus_file`), and the loop's latch and stall fixes landed in T-2914/T-2915.
- OBS-119 and OBS-120 have one fix between them, and so do OBS-188 and OBS-189. Each pair is a single proposed task.
- OBS-108 is a TermLink defect. By gap homing it belongs in the termlink repo, not here.

| id | verdict | evidence | proposed action |
|---|---|---|---|
| OBS-099 | RESOLVED | lib/upgrade.sh:759 `_SELF_VENDOR_ROOT_DATA` includes status-transitions.yaml | dismiss |
| OBS-103 | STILL-VALID | tools/corpus_conformance.py:200 `_extract_tokens` regexes raw text, no comment stripping | "corpus conformance: strip comments before vocabulary-set token extraction" (build) |
| OBS-104 | UNCLEAR | Deliberately not gated (T-2689). Advisory only, no defect | decide whether lane-margin slack becomes a lint WARN |
| OBS-105 | STILL-VALID | agents/handover/handover.sh:143-330 has a push timeout but no retry/sleep (grep) | "handover --commit: retry a transient push failure once" (build) |
| OBS-106 | RESOLVED | T-2692 and T-2693 completed; `grep -c @ .agentic-framework/.upstream` = 0 today | dismiss |
| OBS-107 | RESOLVED | Truncation is now a documented boundary (docs/context-compaction.md:13-25), and CLAUDE.md recovery points to `fw resume status` | dismiss (documented limit) |
| OBS-108 | UNCLEAR | TermLink binary defect; not verifiable from this repo | home in termlink repo; settle by `termlink file receive --replay` on a 2+ transfer queue |
| OBS-109 | UNCLEAR | Dialect question with 832; needs a rail decision, not code | raise on 832 rail |
| OBS-110 | RESOLVED | 8cd856637 (T-2714) | dismiss |
| OBS-111 | STILL-VALID | web/smoke_test.py:81,155: timeout=5 per request, no overall budget | "Watchtower smoke test: overall time budget" (build) |
| OBS-112 | UNCLEAR | bin/fw:4459-4496 now reads version from the consumer's .framework.yaml; not run (doctor >5 min) | settle: run doctor consumer-fleet section, check for `v,` |
| OBS-113 | STILL-VALID | tools/corpus_lint.py rule list has no lane-membership rule (dangling-flow-ref … unread-node-prose) | "corpus lint: flag flow nodes assigned to no lane" (build) |
| OBS-114 | RESOLVED | lib/verification-port.sh extractor takes the first exact `## Verification` block only (`if (!seen)`, T-2921) | dismiss |
| OBS-115 | RESOLVED | `grep -c linkEventThrow tests/fixtures/832/pair-draft-3.bpmn` = 0 (re-pinned, T-2706) | dismiss |
| OBS-116 | STILL-VALID | No element-vocabulary intake check in tools/, lib/ or tests/ (grep) | "BPMN fixture intake: element-vocabulary check incl. scaffolding tags" (build) |
| OBS-117 | DUPLICATE | Design constraint for the OBS-116 check | fold into OBS-116 task |
| OBS-119 | STILL-VALID | tools/bpmn_to_tasks.py:84 `AUTHORITY_NO_OWNER={"authority"}` vs policy/standards/aef-bpmn-mapping-v1-partI.md:68 collapse map `authority→agent` | "bpmn_to_tasks: authority lane compiles to owner agent per Part I §3" (build) |
| OBS-120 | DUPLICATE | The unresolvable lanes are the authority lanes; fixed by OBS-119 | fold into OBS-119 task |
| OBS-121 | STILL-VALID | web/templates/arc_detail.html:465 `p.get('weight', 4)` ignores weight_suggestion (CLI lib/arc.sh:2435 reads both) | "arc_detail approve form: prefill weight_suggestion" (build) |
| OBS-122 | RESOLVED | /proc/<watchtower pid>/fd/1 → live .context/working/watchtower.log, not (deleted), today | dismiss |
| OBS-123 | STILL-VALID | arc_detail.html:462 plain form POST; web/blueprints/arcs.py:1301-1359 return bare `<p>` 400 bodies that replace the page | "arc approve-driver: render errors in-page, keep the arc page" (build) |
| OBS-124 | UNCLEAR | Instance fixed (T-2725, T-2728); the general "can this check ever pass" surface is a design question | inception if wanted |
| OBS-127 | RESOLVED | c3e96e75e (T-2719) | dismiss |
| OBS-130 | RESOLVED | `bats tests/unit/update_task_episodic_gen.bats` 4/4 ok today (T-2733) | dismiss |
| OBS-133 | RESOLVED | T-2739 completed (remediated the 20 tasks) | dismiss |
| OBS-134 | RESOLVED | `pytest tests/unit/test_arcs_pages_tokens.py` 6 passed today; 8e4fb4e4d | dismiss |
| OBS-135 | UNCLEAR | Playwright not re-run (needs server, minutes) | settle: run test_all_routes_height for /inception and /review |
| OBS-136 | RESOLVED | T-2744 triage done; T-3621/T-3794 unit-suite ratchet gates pre-push | dismiss |
| OBS-137 | RESOLVED | T-2743; .tasks/templates/default.md:200-222 pipe-buffer guidance | dismiss |
| OBS-138 | RESOLVED | T-2742; CLAUDE.md Tier 0 scope section + tests/unit/tier0_scope_boundary.bats | dismiss |
| OBS-139 | STILL-VALID | lib/seeds/tasks/greenfield T-001/002/004/005 have `## Verification` with no SIGPIPE hint; only T-003 has it | "seed tasks: carry the verification hint block" (build) |
| OBS-140 | RESOLVED | tests/playwright/conftest.py:318 base_url depends on watchtower_server (T-2782) | dismiss |
| OBS-141 | RESOLVED | agents/task-create/update-task.sh ~3003 matches only commits whose subject carries the task id (component resolution) | dismiss |
| OBS-142 | UNCLEAR | Playwright baseline not re-run (~53 min suite) | settle: full playwright run vs 13-failure baseline |
| OBS-143 | DUPLICATE | Root cause corrected in OBS-212 (resolver loop) | dismiss → OBS-212 |
| OBS-144 | DUPLICATE | Same chain → OBS-212 | dismiss |
| OBS-145 | RESOLVED | bin/fw:11540-11567 runs `pytest tests/unit/` (T-2745) | dismiss |
| OBS-146 | RESOLVED | Self-reported measurement contamination; no code defect | dismiss |
| OBS-147 | DUPLICATE | Same chain → OBS-212 | dismiss |
| OBS-148 | RESOLVED | `grep "bvp rank" CLAUDE.md` empty; docs no longer cite the missing verb | dismiss |
| OBS-149 | STILL-VALID | Only 2 task files carry confirmed `bvp_scores:` today; agents may confirm (D-661) but none have run | "BVP: judge-and-confirm sweep of proposed scores" (build) |
| OBS-150 | RESOLVED | bin/fw:35-40 semver build metadata (T-4055); `fw --version` = v1.8.14+1421.g065de9eab | dismiss |
| OBS-151 | RESOLVED | lib/upgrade.sh:793 self-vendors VERSION; VERSION == .agentic-framework/VERSION == 1.8.14 | dismiss |
| OBS-152 | RESOLVED | Fixed in T-2793 (cand.parent floor) | dismiss |
| OBS-153 | UNCLEAR | doctor bin/fw:3689-3692 and audit check_self_vendor_drift (audit.sh:3637) still separate lists | settle: seed one drift per file class, compare doctor/audit/`vendor self --check` |
| OBS-154 | RESOLVED | Narrative retracted in T-2793 | dismiss |
| OBS-155 | RESOLVED | Updates-section copy corrected the same session | dismiss |
| OBS-156 | DUPLICATE | Same defect as OBS-150 (resolved, T-4055) | dismiss |
| OBS-159 | STILL-VALID | bin/fw:4643 unbounded `du -sm $HOME/.agentic-framework` in doctor | "doctor: bound or drop the global-install du scan" (build) |
| OBS-160 | RESOLVED | `grep localhost:3000 lib/verify-acs.sh lib/arc.sh` → none | dismiss |
| OBS-161 | RESOLVED | bin/watchtower.sh:141 persist_port writes the allocated port to .framework.yaml | dismiss |
| OBS-162 | UNCLEAR | No ancestor guard found in lib/init.sh; not reproduced | settle: stale parent .agentic-framework, `fw init` in child, read `Source:` |
| OBS-163 | RESOLVED | install.sh:343 no longer symlinks claude-fw into the global; T-2800 GO removes the global, so the bin/fw:4646 advice matches policy | dismiss |
| OBS-164 | RESOLVED | tests/unit/fw_doctor_vendored_drift.bats:19-48 uses a mktemp fixture, not the live tree | dismiss |
| OBS-165 | RESOLVED | bin/fw:3483+ walks every PATH entry (T-3358) | dismiss |
| OBS-166 | DUPLICATE | Correction of OBS-164 (resolved) | dismiss |
| OBS-167 | RESOLVED | `bats tests/unit/fw_router.bats` 0 failures today | dismiss |
| OBS-168 | RESOLVED | Pre-push unit-suite ratchet (T-3621, d6344344a T-3794) | dismiss |
| OBS-169 | RESOLVED | T-2813 completed | dismiss |
| OBS-171 | STILL-VALID | lib/init.sh:123-124: target_dir is overwritten by the failed `cd` subshell before the echo → empty path in message | "fw init: name the missing directory in the error" (build) |
| OBS-172 | RESOLVED | bin/watchtower.sh:92-114 allocate_port; README.md:118 self-heal note | dismiss |
| OBS-173 | STILL-VALID | agents/git/lib/hooks.sh:364 PROJECT_ROOT=`git rev-parse --show-toplevel` (outer repo). Missing scanner is now loud (hooks.sh:673-689, T-2647) but still fail-open | "pre-commit: resolve secret scanner from the governed project, not git toplevel" (build; repro first) |
| OBS-174 | RESOLVED | T-2824, T-3103 recovered the worktrees | dismiss |
| OBS-175 | RESOLVED | T-2827 (bootstrap commit has a non-empty tree) | dismiss |
| OBS-176 | STILL-VALID | No completed-but-uncommitted detector found in agents/audit, lib, bin/fw (grep) | "audit: flag completed tasks whose close or deliverables are uncommitted" (build) |
| OBS-177 | RESOLVED | 8ccf4d02e, 3928464cb (T-2829) | dismiss |
| OBS-178 | RESOLVED | a0223ea78 (T-2827), 1cb8d515f (T-2828) | dismiss |
| OBS-179 | RESOLVED | T-3102 (governance-only dirt no longer blocks removal) | dismiss |
| OBS-180 | RESOLVED | agents/context/check-active-task.sh:236-258 bootstrap exemption (T-2936): work-on, task create and context focus pass with no focus | dismiss |
| OBS-181 | RESOLVED | T-2832 completed | dismiss |
| OBS-182 | DUPLICATE | Recurrence count of OBS-180 (resolved) | dismiss |
| OBS-184 | RESOLVED | T-2834 chain splitting (agents/context/lib/safe-commands.sh:35) | dismiss |
| OBS-185 | STILL-VALID | safe-commands.sh:64-70: "Deliberately NOT handled: command substitution … (OBS-185)" | "safe-commands: judge commands nested in $(…) and backticks" (build) |
| OBS-186 | RESOLVED | `bats tests/lint/help-router-parity.bats` 2/2 ok today | dismiss |
| OBS-187 | UNCLEAR | update-task.sh:1778 unsets TASKS_DIR, CONTEXT_DIR and _FW_PATHS_LOADED; PROJECT_ROOT stays exported | design decision: should PROJECT_ROOT be unset in P-011 runs |
| OBS-188 | STILL-VALID | bin/fw-router:31 header still documents the removed global fallback | "fix stale comments: fw-router header + fw_router.bats" (refactor) |
| OBS-189 | STILL-VALID | tests/unit/fw_router.bats:37 still says "red for a year" | same task as OBS-188 |
| OBS-190 | RESOLVED | T-2869; policy/standards/aef-bpmn-mapping-v1-partI.md | dismiss |
| OBS-191 | RESOLVED | Correction recorded (b067ba7cb); no code defect | dismiss |
| OBS-192 | RESOLVED | Positive probe result, informational | dismiss |
| OBS-193 | DUPLICATE | Captured as learning L-552 | dismiss |
| OBS-194 | RESOLVED | Unrecoverable lost note; guard shipped in T-2867 | dismiss |
| OBS-195 | RESOLVED | T-2867; `fw note add …` → "received 1 argument(s) it cannot use" today | dismiss |
| OBS-196 | RESOLVED | Resolution record for OBS-190 | dismiss |
| OBS-197 | DUPLICATE | Captured as learning L-553 | dismiss |
| OBS-198 | STILL-VALID | .tasks/templates/default.md has no `diff` exit-1 hint (grep) | "task template: add the diff-exits-1 pipefail hint" (build) |
| OBS-199 | UNCLEAR | Not reproduced (needs a post-/compact reading) | settle: compare .budget-status vs `checkpoint.sh status` after a compact |
| OBS-200 | STILL-VALID | Probe today: `python3 -c "…pathlib.Path('x').write_text('y')"` → is_bash_safe_command SAFE, has_bash_write_pattern no-write | "safe-commands: gate python3 -c write idioms (pathlib, write_text)" (build) |
| OBS-202 | STILL-VALID | Probe today: `has_bash_write_pattern 'bin/fw note "213917 -> 64395"'` → WRITE; the quote-stripped exemption (check-active-task.sh:236) covers bootstrap verbs only | "write-pattern: ignore > inside quotes for fw note" (build) |
| OBS-204 | RESOLVED | Scan clean (0 offending lines), nothing to fix | dismiss |
| OBS-205 | RESOLVED | tools/corpus_spec.py:738-745 nodes keep raw_children (T-4388) | dismiss |
| OBS-206 | STILL-VALID | tools/corpus_spec.py:771 hard error only when `el.get("id")`; id-less unsupported children still vanish | "corpus_spec: refuse id-less unsupported process children" (build) |
| OBS-207 | STILL-VALID | bpmn_to_tasks.py:52 TASK_TAGS={user,service,script}; no warning for businessRuleTask/manualTask etc. (grep) | "bpmn_to_tasks: warn on task-like node types outside TASK_TAGS" (build) |
| OBS-208 | DUPLICATE | Concurrent focus writer → OBS-212 | dismiss |
| OBS-209 | STILL-VALID | Today: 6 tasks with `arc_id: onboarding-curriculum/arc-017` vs 9 with legacy `arc:onboarding-curriculum` tag | "migrate arc-017 legacy arc: tags to arc_id" (refactor) |
| OBS-210 | DUPLICATE | → OBS-212 | dismiss |
| OBS-211 | DUPLICATE | → OBS-212 | dismiss |
| OBS-212 | RESOLVED | Focus is per-session (check-active-task.sh:49 `fw_focus_file`); loop fixes in T-2914/T-2915 | dismiss |
| OBS-213 | UNCLEAR | Latch fixed (T-2915); stall-guard reach not re-measured | settle: `fw orchestrator status` stall section vs dispatch history |
| OBS-215 | RESOLVED | `bats tests/integration/check_project_boundary.bats` 36/36 ok today | dismiss |
| OBS-216 | STILL-VALID | agents/task-create/update-task.sh:2625 unranged `s/^owner:.*/owner: X/` | "update-task: owner rewrite limited to frontmatter" (build) |
| OBS-217 | RESOLVED | agents/context/budget-gate.sh:19,107 now state that the block path writes .restart-requested | dismiss |
| OBS-218 | STILL-VALID | agents/audit/audit.sh:6002-6040 episodic section greps the summary line and never parses YAML (YAMLError handling exists only for task frontmatter, :1435-1581) | "audit episodic: parse each episodic YAML, FAIL on unparseable" (build) |
| OBS-219 | UNCLEAR | lib/arc.sh:684 still reads related_tasks; typed-field design not decided | inception: split related_tasks by meaning |
| OBS-220 | UNCLEAR | Meta-observation (audit of all raw-command scanners); partly covered by the T-3593 grammar work | inception if wanted |
| OBS-222 | RESOLVED | check-active-task.sh:~1456-1473 read-only Bash predicate path (T-2887 allowlist) | dismiss |
| OBS-223 | DUPLICATE | Same class as OBS-222 (resolved) | dismiss |
| OBS-226 | STILL-VALID | agents/observe/observe.sh:400 `--name "$text"` passes the full observation body | "fw note promote: short name, full text to description" (build) |
| OBS-227 | RESOLVED | `fw note add …` now refused (T-2867) | dismiss |
| OBS-228 | STILL-VALID | `bin/fw hook-disable` → "Unknown command"; only bin/hook-enable.sh exists | "fw hook-disable: governed inverse of hook-enable" (build) |
| OBS-229 | UNCLEAR | Could not locate the 'trigger'-substring closure-field heuristic in agents/audit today (grep) | settle: find the gap closure-field classifier and re-run 832's teeth leg |
| OBS-230 | STILL-VALID | partI.md:113 names tests/fixtures/aef-bpmn/inception-gonogo.bpmn (absent); fixtures exist at tests/fixtures/bpmn/inception-gonogo-{canonical,sample}.bpmn | "place the Part I reference fixture at its frozen path" (test) |
| OBS-232 | UNCLEAR | 3 concerns entries now carry closure_check_command (was 0) | decide whether open gaps must carry one (audit WARN?) |
| OBS-237 | STILL-VALID | lib/verify-acs.sh:298 `### Human\s*\n` and handover.sh:1381 still unanchored (narrow residual) | "anchor ### Human section regexes with ^" (refactor) |
| OBS-239 | RESOLVED | Working as designed; scope documented (CLAUDE.md Tier 0, T-2742) | dismiss |
| OBS-242 | UNCLEAR | Pinned copies are local (tests/fixtures/aef-bpmn/, corpus-832-goldens/ T-4501); cross-repo visibility not addressed | decide with 832 whether a pin manifest is needed |
| OBS-243 | RESOLVED | bin/fw:3191 doctor WARNs on a stale triple; lib/watchtower.sh:204 identity handshake; triple port 3000 matches the live listener today | dismiss |
| OBS-244 | DUPLICATE | Recurrence of OBS-243 (resolved) | dismiss |
| OBS-247 | RESOLVED | Environmental (proxy 403), no framework code involved | dismiss |
| OBS-248 | RESOLVED | Release-train model (T-3185); T-3002 | dismiss |
| OBS-249 | STILL-VALID | `fw corpus explain --help`: only `--search TERM`, no enumerate mode | "corpus explain --list: enumerate all maps" (build) |
| OBS-250 | UNCLEAR | Enhancement follow-ups (GPU reindex, embed failover), no defect | operator priority call |
| OBS-252 | STILL-VALID | web/search_utils.py: `grep -c designer` = 0; .context/designer not indexed | "semantic index: include designer map prose" (build) |
| OBS-253 | RESOLVED | d81ff7430 (T-4623): structure audit 262s → 149-158s | dismiss |
| OBS-254 | STILL-VALID | web/app.py:424 blanket `except Exception` → status unavailable | "/health: report the embeddings error class" (build) |
| OBS-255 | RESOLVED | lib/config.sh:74 fix; `set -euo pipefail; fw_config PORT` → 3000, rc 0 today | dismiss |
