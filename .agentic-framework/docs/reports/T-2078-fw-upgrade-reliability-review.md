# T-2078: fw upgrade reliability review — field deployment hardening

**Status:** in-progress (review phase)
**Origin:** user request, 2026-05-28 — "deep review the upgrade prompt and improve for more reliability and deployment success in the field"
**Scope reviewed:**
- `lib/upgrade.sh` (1265 lines) — single-file driver for 10-step upgrade flow
- `tests/unit/upgrade_fresh_machine_simulation.bats` (117 lines, 3 tests) — slim fresh-machine guard
- `docs/reports/T-1633-fw-upgrade-no-local-path.md` — fresh-machine crash RCA
- `docs/reports/T-1830-fw-upgrade-incident-meta-rca.md` — boundary-observability meta-RCA
- T-1635 closed task — fresh-machine sim's own scope
- T-1542 (predecessor RCA), T-1217/T-1278/T-1839/T-1912 (corrections layered onto upgrade)

This file is the thinking trail per C-001. Updates incrementally.

---

## Dialogue Log

### 2026-05-28 — initial framing
- **User:** "please deep review the upgrade prompot and improve for more reliability and deployment success in the field"
- **Agent interpretation:** "upgrade prompt" = `fw upgrade` command flow (lib/upgrade.sh), not a literal Claude prompt template. Verified by `grep` for `do_upgrade` in `bin/fw` → routes to `lib/upgrade.sh`. No alternative artefact in the repo.
- **Decision:** file as inception (review > 3 files, no concrete fix scope yet); ship findings + recommendation; let human GO unlock build slices per T-1984 + G-066.

---

## Known prior incidents

| Task | Class | Surfaces |
|---|---|---|
| T-1542 | self-target corruption (premature close — shipped louder dead-end) | `fw upgrade` from inside consumer's `.agentic-framework/` self-copied state |
| T-1633 | inception that closed the structural gap T-1542 missed: no upstream URL convention; no fresh-machine simulation | (this report's parent inception) |
| T-1634 | bare-from-consumer auto-clone path (`--from-upstream` + `upstream_repo:` in `.framework.yaml`) | shipped in lib/upgrade.sh:212-314 |
| T-1635 | fresh-machine simulation bats | `tests/unit/upgrade_fresh_machine_simulation.bats` (slim, 3 tests, dry-run only) |
| T-1109 | enumeration-divergence: `fw upgrade` silently skipped `web/` because per-file copy list diverged from `do_vendor`'s canonical list | T-1157 collapsed to single `do_vendor` call (step 4b) |
| T-1217 | self-vendor: framework's own `.agentic-framework/` went stale relative to `lib/` | step 0 self-vendor loop, lines 316-338 |
| T-1278 | shim migration could overwrite framework repo's `bin/fw` with the shim, infinite-loop next call | step 4c added FRAMEWORK.md sibling check + `rm -f` before `cp` |
| T-1839 | silent downgrade after framework VERSION rollback (T-1828) | step 9 + step-1 precheck (T-1912) refuse ahead-direction unless `--force-downgrade` |
| T-1912 | runtime-vs-pin split-brain: T-1839 fixed pin only, runtime was still copied first | added pre-step-1 mirror of step-9 guard, lines 379-397 |
| T-1830 | async-boundary observability meta-RCA (mirror sync, pickup-bridge, peer-subscribe, federated hubs) — not upgrade-specific but informs reliability frame | (V1 candidate 2+4: heartbeat + audit-time stall detector) |

Pattern: each fix layers a guard onto the previous fix. The driver is now 10 steps with side-band steps `4b`, `4c`, `8b` — and the numerator/denominator drifted (header text says `[4b/9]` and `[4c/9]` while every other step says `[N/10]`).

---

## Findings — concrete reliability defects

Numbered for traceability. Severity = how likely this fails in the field × how invisibly it fails. **High** = silent or hard to diagnose; **Medium** = visible failure but no auto-recovery; **Low** = cosmetic / clarity-only.

### F1 — Step-numbering header drift `[4b/9]` `[4c/9]` vs `[5/10]` (Low → governance signal)

`lib/upgrade.sh:641 + 656` print `[4b/9]` and `[4c/9]` while every other step (1, 3, 4, 5, 6, 7, 8, 9, 10) prints `[N/10]`. There IS no step 2. There's a phantom `8b` (audit-trail, line 1175) after step 9. The numbering is hand-maintained and has decayed.

**Why it matters for the field:** operators following along with logs / paste-into-issues lose trust in the upgrade flow when its own announced structure doesn't match what runs. Field-incident reports cite step numbers; mismatched headers force every consumer to re-read the source.

**Fix shape:** centralize step labels as a numbered array; emit `[i/N]` from a loop. ~30 lines refactor.

### F2 — Self-vendor runs unconditionally on every consumer upgrade (Medium)

`lib/upgrade.sh:316-338` — before any consumer work, the framework's own `.agentic-framework/lib/` is sync'd from `$FRAMEWORK_ROOT/lib/`. This was T-1217's fix for stale-vendor; it correctly catches the "developer ran upgrade and forgot to re-vendor self" case. But:

- Fires every time a consumer is upgraded — N×M self-vendor calls for N upgrades, all but the first redundant.
- Mutates `$FRAMEWORK_ROOT`'s working tree (`.agentic-framework/lib/*.sh`) when invoked from a consumer's vendored bin/fw on a developer machine. Surprise dirty tree in the framework repo.
- Not gated on `$FRAMEWORK_ROOT != $target_dir/.agentic-framework` resolution — if a consumer's vendored copy somehow IS the framework root (cwd-trap class), it still runs.

**Why it matters for the field:** consumer upgrade should not modify the developer's framework repo on the same host. Multi-tenant LXC hosts with several consumers all firing the cron-triggered upgrade would each touch the framework's working tree.

**Fix shape:** move self-vendor to a separate verb (`fw vendor self` or `fw upgrade --self-vendor`); fire from framework's pre-push only; consumer `fw upgrade` never touches `$FRAMEWORK_ROOT`.

### F3 — Live (non-dry-run) upgrade is NOT covered by the fresh-machine simulation (High) — **Status: shipped (T-2092)**

**T-2092 (2026-06-01):** docker-based live-upgrade simulation gate landed at
`tests/integration/upgrade_live_simulation.bats`. Runs FULL live upgrade
end-to-end inside isolated `debian:trixie-slim` container in ~19 s (well
under the 5-min budget). Skips cleanly when docker / docker daemon / apt
repos unreachable. On first run the gate caught a real pipefail regression
in `lib/upgrade.sh:1318` (pyc_count grep pipeline exits 1 on clean
consumers → set -e kills do_upgrade silently before summary) — fixed in
the same commit. Exactly the class this F finding said was untested.

(Original finding text preserved below for context.)


`tests/unit/upgrade_fresh_machine_simulation.bats:112-117`:

> NOTE on live (non-dry-run) upgrade: the full vendor copy takes ~8 minutes (~65MB rsync...) — impractical for a unit test gate. ... A docker-container variant of the full live upgrade is the natural release-gate follow-up (see T-1635 ## Evolution).

This is the load-bearing observation. The simulation that T-1633 elevated to *"the load-bearing piece"* (sub-problem 3, capitalised) only exercises the dry-run announcement path — the actual mutation path is untested. Every real upgrade in the field is the first time the live path runs against that exact consumer's state. Bare-from-consumer + auto-clone HANDOFF is asserted; but the upstream's bin/fw upgrade actually mutating a vendored consumer (vendor copy + settings.json regen + version bump + audit trail + git hooks reinstall + enforcement baseline) on a scrubbed env is NOT in the gate.

**Why it matters for the field:** the class T-1633 explicitly committed to closing — "fresh-machine upgrade simulation, runs on every release, blocks the release" — is half-shipped. Slim slice was the time-boxed compromise; the docker variant is still a TODO 5 weeks later.

**Fix shape:** docker-based bats gate that exercises the FULL flow end-to-end on a minimal Debian/Alpine image with no developer artifacts. Acceptable runtime budget: 5 minutes (mark `tag:slow`, run on release tag + nightly, not every PR).

### F4 — Step exit-codes inconsistent: WARN-and-continue vs return-1 (High)

Step 4 (git hooks): failure → `WARN`, skipped++, continue. (line 628)
Step 4c (shim migration FRAMEWORK.md sibling): failure → `return 1` (line 680).
Step 4b (vendor): `do_vendor 2>&1 | sed 's/^/ /'` — exit code lost through pipe; failure invisible.
Step 5 (settings.json regen): no exit check on `generate_claude_code_config "$target_dir"` (lines 878, 953).
Step 10 (enforcement baseline): failure → `SKIP`, skipped++. (line 1209)

The operator cannot predict from output whether the upgrade is partially-applied or fully-rolled-back. There is no rollback.

**Why it matters for the field:** mid-upgrade failure leaves the consumer with NEW lib/*.sh but OLD settings.json + OLD hooks → settings reference functions or paths that no longer exist. Next Claude Code session fails in surprising places.

**Fix shape:** either (a) introduce strict mode where any step's non-zero aborts AND reverts the .bak files written so far; or (b) explicit `--strict` flag that callers can opt into. Audit-trail emits PARTIAL when intermediate failure detected.

### F5 — `do_vendor 2>&1 | sed ...` swallows exit code under pipefail (High)

`lib/upgrade.sh:646-649`:

```bash
do_vendor --target "$target_dir" --source "$FRAMEWORK_ROOT" --dry-run 2>&1 | sed 's/^/  /'
```

Bash's pipefail is set at the top of `bin/fw` for the dispatch wrapper, but inside `lib/upgrade.sh:do_upgrade` the calling context's pipefail status determines whether `sed`'s exit (always 0) masks `do_vendor`'s exit. If do_vendor fails (e.g., source tree missing a file), the upgrade reports success.

**Why it matters for the field:** T-1109's enumeration-divergence was exactly this class. We closed it with T-1157 (single canonical list) but didn't close the "vendor returns non-zero, pipe eats it" failure mode.

**Fix shape:** `local _rc=${PIPESTATUS[0]}` immediately after, gate on $_rc.

### F6 — Step 5 settings.json regen mutates global `force=true` then restores (Medium)

`lib/upgrade.sh:876-879`:

```bash
local save_force="${force:-false}"
force=true
generate_claude_code_config "$target_dir"
force="$save_force"
```

If `generate_claude_code_config` errors or exits mid-function (e.g., via `set -e` from a sub-call), `force` is left at `true` for the rest of `do_upgrade`. Subsequent steps then see `force=true` they never authorised.

**Why it matters for the field:** rare but corrosive. The `--force` flag is a sovereignty bypass — a stuck-on `force=true` from an error path crosses governance boundary silently.

**Fix shape:** pass force as a function arg to `generate_claude_code_config`, or use a subshell to scope the override: `(force=true; generate_claude_code_config "$target_dir")`.

### F7 — `changes` counter inflates by subsystem, not by mutation count (Low)

Each step does at most one `changes++`. So when step 4b vendors 200 files, the count grows by 1. When step 9 updates a single line, it also grows by 1. The "1 change(s) applied" footer is essentially "1 subsystem touched", but the wording suggests file count.

**Why it matters for the field:** auditability — operators reading upgrade output cannot estimate the mutation surface. Audit-trail (`.context/audits/upgrades.yaml`) records `from_version` / `to_version` only, no per-step counts.

**Fix shape:** emit a structured summary table at the end (subsystem → file count → status). Optional `--json` mode for cron integrations.

### F8 — No pre-flight tooling check (`python3`, `git`, `diff`, `sed`, `mktemp`) (Medium)

The flow assumes all five. On a minimal LXC / Alpine container any one missing crashes mid-step with a generic `command not found` and no rollback. The fresh-machine simulation uses Debian-derived `/usr/bin` so this gap is never exercised.

**Why it matters for the field:** the framework targets ARM/Alpine/macOS hosts (TermLink is documented Homebrew + cargo). Each has different python3 conventions (alpine `apk add python3 py3-pip`).

**Fix shape:** explicit pre-flight at the top of `do_upgrade` after arg parse: `for cmd in python3 git diff sed mktemp; do command -v "$cmd" >/dev/null || { echo "ERROR: required tool missing: $cmd" >&2; return 1; }; done`. Cheap insurance.

### F9 — Inline python3 heredocs (≥4 sites, ~250 lines total) are untestable (Medium)

`_do_dedupe_user_hooks` (lines 12-117), step 5 hook analysis (lines 792-849), step 5 dup analysis (lines 895-921), step 6 MCP analysis (lines 972-984 + merge 998-1015). Each is one-shot, no test surface.

**Why it matters for the field:** when one of these fails (e.g., a settings.json schema migration breaks the extractor), the diagnostic is "ERROR|<exception>" with no test to point at. Field debugging is grep through error output.

**Fix shape:** extract each into `lib/upgrade/<analysis>.py` with a `bats`/`pytest` sibling. The shell call becomes `python3 "$FRAMEWORK_ROOT/lib/upgrade/extract_hooks.py" "$file"`. T-1109/T-1157's mistake of "two divergent enumerators" can't happen if there's only one tested function.

### F10 — No post-upgrade verification (High)

`do_upgrade` writes files and prints "Upgrade Complete". It does NOT run `fw doctor`, NOT exercise the regenerated hooks, NOT verify `.framework.yaml` parses, NOT confirm `bin/fw --version` works in the consumer. The audit-trail records the upgrade happened, not whether it left the consumer healthy.

**Why it matters for the field:** the canonical first sign of "upgrade went sideways" is *next time the operator runs anything*, by which point the working memory of what was just upgraded is gone. Post-upgrade `fw doctor` would close the loop within the same invocation.

**Fix shape:** at the end of `do_upgrade` (after step 10), if `changes > 0` and `--dry-run = false`, run `PROJECT_ROOT="$target_dir" "$FRAMEWORK_ROOT/bin/fw" doctor 2>&1 | head -20`. Non-blocking advisory; exit code propagated as warning.

### F11 — Bare-from-consumer auto-clone trusts upstream URL without verification (Medium)

`lib/upgrade.sh:292-298`:

```bash
echo -n "  Cloning... "
if ! git clone --depth=1 --quiet "$_upstream_url" "$_tmpd/fw" 2>"$_tmpd/clone.err"; then
    # ...
fi
```

After clone, immediate re-exec of `"$_tmpd/fw/bin/fw" "${_replay_args[@]}"` (line 310). No check that the cloned repo IS an agentic-framework (no `FRAMEWORK.md` / `bin/fw` / `lib/upgrade.sh` sanity check before exec).

**Why it matters for the field:** a typo in `.framework.yaml: upstream_repo:` could point at any git URL; whatever's at `<clone>/bin/fw` gets executed against the consumer. Low-probability but governance-violation when it happens.

**Fix shape:** between clone and re-exec, assert `[ -f "$_tmpd/fw/FRAMEWORK.md" ] && [ -x "$_tmpd/fw/bin/fw" ] && [ -f "$_tmpd/fw/lib/upgrade.sh" ]`. Refuse with diagnostic if not.

### F12 — Step 4c shim migration mutates `$HOME/.local/bin/fw` without operator consent on the run (Medium)

`fw upgrade` from a consumer can replace the user's global `~/.local/bin/fw` symlink with the project-detecting shim. T-665 origin; defensive guards layered (T-1278). But the consent model is: "if it's currently a symlink to a `.agentic-framework/bin/fw`, replace". User did not ask for their HOME to be modified by running upgrade in `/opt/some-consumer`.

**Why it matters for the field:** principle of least surprise. Multi-user hosts where root runs `fw upgrade` on a consumer should not silently mutate other users' shims.

**Fix shape:** add `--no-shim-migrate` flag (default off — keep current behavior), document the consent model explicitly in `fw upgrade --help`. Long-term: opt-IN with `--migrate-shim` once consumers in the field are caught up.

### F13 — Hardcoded `[N/10]` denominators (Low)

Adding step 11 (e.g., post-upgrade verification per F10) requires hand-editing all 8 surviving step headers. Same class as F1.

**Fix shape:** consolidated with F1.

### F14 — No `--only <subsystem>` flag (Low — feature, not defect)

Operator wants to refresh just CLAUDE.md without firing the full 10-step flow. Currently impossible without manual `cp $FRAMEWORK_ROOT/lib/templates/claude-project.md`. Surface area is large enough that selective refresh would be a useful escape hatch.

**Fix shape:** `--only claude-md,seeds,hooks,settings,mcp` flag list. Steps not selected get a `SKIP (--only)` line.

### F15 — Step ordering implicit, not declared (Low → governance signal)

Steps are encoded by their position in the function body. A maintainer adding "step 11" must guess where in the body it goes, what other steps it must come after (e.g., must come after step 4b vendor or .agentic-framework/ isn't current), etc. The implicit DAG is in maintainers' heads.

**Fix shape:** convert each step to a function with a docstring naming `depends_on:` predecessors. Driver iterates a registry. Hard refactor; defer to V2.

---

## Cross-cutting observations

### O1 — The fix-pattern shape repeats: "one more guard"

Six of the layered fixes (T-1217, T-1278, T-1839, T-1912, T-1542, T-1109) each added one defensive check at the moment of breakage. None refactored the surface. The 1265-line file is the cumulative result.

**Antifragility framing (D1):** the system did absorb each incident, but did not strengthen its shape. Each new guard is more surface for the next maintainer to keep in their head. T-1830's pattern — convert failure events into structural change — applies to upgrade as much as to async boundaries.

**Implication:** the prudent V1 ships **F2 + F3 + F4 + F5 + F8 + F10** (the High and Medium correctness + observability fixes) without yet refactoring the step driver. V2 is the F1 + F13 + F15 step-driver refactor, gated on V1 telemetry showing the simpler fixes did NOT regress field success.

### O2 — Asymmetric guards class (L-441)

F4 (inconsistent exit codes) and F5 (pipefail swallow) are L-441 instances on upgrade. The framework already taught itself this lesson on the pickup pipeline (T-2072 just shipped). Apply the same rule here: every step must declare and honour its failure semantics; the driver enforces them uniformly.

### O3 — Field telemetry blind spot

There is no telemetry channel from "consumer ran fw upgrade and it failed" back to the framework. The audit-trail at `.context/audits/upgrades.yaml` records SUCCESS only. The 30-day field-failure rate is unknown. T-1830's audit-time stall detector (V1) is exactly the right shape: each consumer's upgrade run posts a heartbeat / outcome; framework's audit cron surfaces stale or failed instances.

**Implication:** F10 (post-upgrade verification) lays the rail for O3: structured success/fail with optional opt-in remote reporting via `fw bus post --remote`. Same envelope shape as TermLink dispatch.

### O4 — The "deep review" frame the user requested aligns with G-019

The user's word "field" is the missing predicate that L-441/G-019 generalises. Every existing fix is reactive to a witness. The fresh-machine simulation gate (T-1635) is the only proactive control — and its slim variant doesn't exercise the live mutation path. Closing that (F3) is the single highest-leverage move.

---

## Recommendation

**Recommendation:** **GO** on T-2078 with a 4-slice V1 + 1-slice V2 sequence. Defer step-driver refactor (F1/F13/F15) to V2 — V1 ships only behavioural / correctness / observability fixes that don't touch the 10-step shape.

### V1 build slices — **LADDER COMPLETE 2026-06-06**:

| Slice | Closes | Task | Status |
|---|---|---|---|
| **V1-a** Docker-based live-upgrade simulation gate (release-blocking) | F3 | T-2092 | **SHIPPED** (2026-06-01) |
| **V1-b** Strict exit-code discipline + dry-run PARTIAL footer (`--strict`, `failed_steps`, PIPESTATUS, subshell-scoped `force=true`) | F4 + F5 + F6 | T-2093 | **SHIPPED** (2026-06-06) |
| **V1-c** Pre-flight tooling check (`python3 git diff sed mktemp`) + post-upgrade `fw doctor` advisory (non-blocking, PROJECT_ROOT-scoped) | F8 + F10 | T-2094 | **SHIPPED** (2026-06-06) |
| **V1-d** Self-vendor extraction (`_self_vendor_libs` helper + `fw vendor self` subcommand + `--no-self-vendor` flag) | F2 (organisational; N×M closure path-forward only) | T-2095 | **SHIPPED** (2026-06-06) |
| **Out-of-ladder** Durable in-consumer upgrade fix (`.upstream` sentinel + 3-leg fallback chain + self-heal yaml-persist) | T-1542 class | T-2232 | **SHIPPED** (2026-06-06) |

**Regression net at V1 ladder close: 33/33 PASS** across `tests/unit/{t2093,t2094,t2095,t2232}*.bats` + `upgrade_fresh_machine_simulation.bats`.

**V1-D scope decision (per T-2095 §Context / §Recommendation):** narrow refactor — helper extraction + new public verb + opt-out flag — *without* default-flip. T-1217's invariant (framework's `.agentic-framework/lib/` stays in sync) is preserved on every developer machine that hasn't yet wired `fw vendor self` into pre-push. The §F2 N×M closure ("self-vendor fires once per framework commit, not once per consumer upgrade") is **path-forward**, not part of this slice:
1. Operator wires `bin/fw vendor self` into framework's `.git/hooks/pre-push`
2. Operator adds `--no-self-vendor` to consumer-upgrade scripts on dev machines
3. (V2) After field observation, remove the inline call entirely

**V2 gating:** "after V1 ships and stabilizes" — V1 ladder is now shipped; V2 slices can be filed once field telemetry confirms no V1 regression (target: 30 days of clean upgrade-outcome audit cron firings).

### V2 build slices (after V1 ships and stabilizes):

| Slice | Closes | Cost | Risk |
|---|---|---|---|
| **V2-a** Step-driver refactor: array-of-steps, dependency declaration, programmatic `[i/N]` | F1 + F13 + F15 | L | High — touches every step's announcement, needs comprehensive bats |
| **V2-b** Inline-python extraction → `lib/upgrade/*.py` with unit tests | F9 | M | Low — defensive refactor, mechanical |
| **V2-c** Field telemetry: upgrade outcome → `fw bus post` envelope | O3 + F11 | M | Low — additive |
| **V2-d** `--only <subsystems>` selective refresh | F14 | S | Low — additive flag |

### Out of scope (separate inceptions if pursued):

- Upstream URL signing / signature verification (F11 long-form). Crosses into supply-chain territory.
- Multi-version migration support (current model assumes monotonic version up). Pre-mature.
- Cross-platform parity (Alpine, macOS, BSD) test matrix. Useful but downstream of F3's docker variant.

### Rationale for the split

V1 is correctness + observability: stop the silent failure classes (F3 closes the load-bearing test gap; F4/F5/F6 stop mid-upgrade corrosion; F8 + F10 catch broken environments and broken outcomes). Each V1 slice is independently shippable.

V2 is structural — the step-driver refactor and python extraction. Those are higher-effort and depend on V1's safety net (the docker test gate) being green before any large refactor is safe.

### Open question (request human decision)

**Q1.** Should `--from-upstream URL` accept a local path (`file:///`) in production, or only in the bats simulation? Currently both work. Field operators might pass a `/tmp/copy-of-framework` URL by accident. Recommendation: emit advisory WARN on `file://` paths outside `/tmp` and `/var/tmp`; refuse in non-`--dry-run` mode without `--force` for paths NOT matching `^file://(/tmp|/var/tmp)/`.

---

## Wire-evidence (artefacts traceable to this review)

- `lib/upgrade.sh` lines cited above (all valid against commit `ce010034`)
- `tests/unit/upgrade_fresh_machine_simulation.bats` lines 112-117 (the documented gap)
- `docs/reports/T-1633-fw-upgrade-no-local-path.md` § "3. Fresh-machine simulation guard (THE LOAD-BEARING PIECE)"
- `docs/reports/T-1830-fw-upgrade-incident-meta-rca.md` (boundary-observability frame)

---

## Decision (filled in by human via fw inception decide T-2078 …)

(Pending human GO/NO-GO/DEFER.)

If GO: agent files V1-a through V1-d as four separate build tasks, each with `unlocks_inception_decision: T-2078:<slug>` so the GO-scope traceability gate (T-1984/G-066) closes when each ships.

If NO-GO: this report stays as the audit trail of where the upgrade flow is in 2026-05-28. Re-open when the next field incident makes the cost of inaction visible.

If DEFER: human names which of the 15 findings warrants further evidence before committing to V1, and which V1 slices are tightest scope.
