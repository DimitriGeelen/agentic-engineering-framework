You are building T-3635 in /opt/999-Agentic-Engineering-Framework (branch bleeding-edge, main checkout, NO worktree). Run `bin/fw work-on T-3635` alone on its line first. Follow CLAUDE.md.

Context: on 2026-10-01 the operator recorded GO on inception T-3535 (project objectives), with no §4 item rejected. So all of docs/reports/T-3535-objectives-v2.md is ratified: §1 objectives, §2 arc mapping, and the §4 recommendations (capability-overlay → NONE and park; ewcr-arc0-contract-evidence → O-1; inception-review-loop → abandoned as superseded, which is the operator's arc action and NOT yours; add O-6, cost).

1. Write real Agent ACs into the task file FIRST (Edit tool), for example:
   - objectives.yaml exists, parses, and matches v2 §1 plus O-6 verbatim;
   - every arc YAML carries `supports:` per §2/§4;
   - capability-overlay is parked;
   - no consumer-shipping path picks up the file.
2. Write `.context/project/objectives.yaml` with: headline, objectives O-1..O-5 from §1 verbatim, O-6 from §4 verbatim, and out_of_scope from §1. Add a header comment: the source (T-3535, v2 doc, GO 2026-10-01) and "authored intent; progress is derived, never written here" (IW-1).
3. Add `supports: [O-n, ...]` to each arc YAML in .context/arcs/ per the §2 table and §4 (NONE → `supports: []`). For inception-review-loop, leave `supports:` untouched and its status as it is: the operator abandons it in Watchtower.
   - Check first whether anything validates arc YAML keys (`grep -rn "supports" lib agents web`, the arc schema, `fw audit`). If an unknown key would trip a check, add it to that schema rather than skipping it.
   - Record in Decisions that `supports:` is the field name (the inception called it `serves_objective`; v2 settled on `supports:`).
4. Park the capability-overlay arc: if `fw arc` has a verb for horizon or parking, use it; otherwise record that there is no verb and leave it.
5. Directive 4: check that `fw upgrade`, `fw vendor` and `fw init` never copy `.context/project/objectives.yaml` into a consumer. Prove it with a grep of their copy lists, or with a run of upgrade_fresh_machine_simulation.bats plus a check that the file is absent in the fixture consumer.
6. Close the task if every gate passes without a skip flag.

Do not touch: agents/termlink/termlink.sh, lib/verdict_ledger.py, lib/tier0_action.py, agents/context/check-tier0.sh, agents/git/lib/hooks.sh, bin/fw, bin/claude-fw, lib/pickup.sh, and the init templates (other workers own them).

COMMIT WITH AN EXPLICIT PATHSPEC: `git commit -m "T-3635: ..." -- <paths>`. All workers share one git index.

Rules:
- NEVER use --no-verify, --force, --skip-*, or FW_ALLOW_* flags. If a gate blocks you, stop and report it.
- Run `bin/fw context focus` and `bin/fw work-on` alone on their line.
- Run everything in the FOREGROUND. Never background a command and end your turn.

Print only: commits, per AC done or not, the arc → supports table you wrote, and whether the task closed.
