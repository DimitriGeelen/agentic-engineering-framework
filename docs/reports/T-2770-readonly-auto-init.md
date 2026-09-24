# T-2770 — should a read-only `fw` query auto-init and vendor into cwd at all?

**Task:** T-2770 (inception) · **Researched:** 2026-09-24 (autonomous run) · **Phase:** exploration complete, decision pending

The question as filed: when `fw` runs non-interactively in a directory that is not a
framework project, `bin/fw` runs `do_init` on `$PWD`, vendors the framework there, and
re-execs. So a read-only query creates a project and writes a vendored tree into the
caller's cwd. T-2769 fixed the *stream*; it deliberately did not decide whether the side
effect itself is right.

Every finding below names the command or file:line that produced it.

---

## 1. What the branch is today

`bin/fw` ~986–1025, inside the "No framework project detected" path — so it can only fire
when the cwd is **not** already a project. Non-TTY takes `do_init "$PWD" --provider claude
>&2` then `exec "$0" "$@"`.

Two narrowings already landed, and **both recorded in code that they were not deciding this
task**:

| Task | Change | Its own note |
|---|---|---|
| T-2769 | `2>/dev/null` → `>&2`. The narrative was on **stdout**, so the old redirect suppressed the wrong stream; every `fw <cmd> --json` from a non-project dir emitted prose before its JSON, rc=0 | "Whether a read-only query should trigger it at all is a separate question, deliberately not decided here (T-2770)" |
| T-2835 | `_fw_cmd_is_known` — an **unrecognised** verb (`fw doctro`) used to reach auto-init and bootstrap the caller's directory | "Deliberately NOT deciding T-2770 … That question has consumer blast radius and stays open" |

**Finding 1 — the mechanism this task imagines building already exists.** The condition
already excludes `init`, `help`/`-h`/`--help`, `version`/`-v`/`--version`, `update`,
`hook`, `vendor`, and any `--help` query. Several are read-only. The live question is
*which verbs belong on the list that is already there* — a far smaller change than the
task's framing implies, and not a new mechanism at all.

## 2. IW-1 — does the T-519 ordering encode a requirement? **No. Artefact.**

`bin/fw:470` — `# --- Vendor (T-482/T-497, moved before auto-init for T-519) ---`, `:472` —
`# Must be defined before auto-init dialogue because do_init calls do_vendor.` T-519's own
Context: *"`fw doctor` interactive init … sources `lib/init.sh` which calls `do_vendor()`,
but `do_vendor` is defined at line 1173"*. A bash **function-definition ordering** bug.

No policy intent. The task's suspicion that the ordering hides a requirement is
**disconfirmed**, removing one reason to hesitate.

## 3. IW-2 — which callers rely on scripted auto-init? **None. The one that hit it was harmed by it.**

This is the evidence gap the 52-day DEFER named, and it resolves in the opposite direction
to the framing. `tests/unit/install_verify_no_cwd_init.bats:1-12` records a **measured live
incident**:

> T-2799: install.sh's own verify() step must never initialise a project in the caller's
> cwd. Step 3 (`fw doctor`) used to run against the caller's cwd; under a non-TTY pipe
> (`curl | bash`) that reaches bin/fw's auto-init branch and silently seeds
> `.agentic-framework/`, `.git`, `.tasks/`, `.context/` etc. wherever the user happened to
> be standing — while still printing a green "Step 3/3: fw doctor passes" checkmark.
> **Measured live against GitHub master, 2026-08-04: an empty cwd ended up with a complete
> initialised project after nothing but the documented `curl | bash` one-liner.**

So the only identified caller of a read-only verb into this branch was the project's **own
documented install path**, the outcome was **damage to a stranger's directory**, and it was
reported by a green checkmark. That is the exact false-green shape the framework elsewhere
treats as the worst class of defect.

**Where the fix went matters.** T-2799 repaired the **caller** (`install.sh:456,461` — "no
target given — PATH tooling only … the unannounced-cwd-init class T-2799 exists to
prevent"), not the branch. The branch still does this for any other non-TTY caller of a
read-only verb. One caller was cured; the disease was left in place, which is why this
question is still open.

**Counter-evidence sought, and what was found.** One test pins the behaviour:
`tests/unit/fw_help_no_autoinit.bats:76` — *"auto-init still fires for a real command from
a non-project directory"*. Read in context this is a **discriminating control**, present so
the help-exclusion assertions cannot pass vacuously — not a caller depending on the effect.
Narrowing would require re-pointing that control at a verb that still auto-inits (a write
verb), which is a test edit, not a broken dependency.

No cron entry, CI step, or documented workflow was found that runs a read-only `fw` verb
from a non-project directory expecting a project to appear. Searched:
`.context/cron-registry.yaml`, `install.sh`, `docs/consumer-project-setup.md`, `README.md`,
`tests/`.

## 4. IW-4 — what is lost if a read-only verb refuses instead? **Nothing that is not already lost.**

Since T-2835, an **unknown** verb from a non-project directory already gets a clear refusal
rather than a bootstrap. The alternative behaviour is therefore already implemented,
already shipped, and already the norm for a neighbouring case — a read-only verb would
simply join it. The user-visible result is an error naming `fw init` instead of a ~27 MB
vendored tree they did not ask for.

## 5. Recommendation

**GO — narrow, not remove.** Add the read-only query verbs (`status`, `list`, `show`,
`doctor`, and the other pure-read verbs) to the exclusion list that already exists at
`bin/fw:987-991`. Leave auto-init in place for write verbs, where a caller plausibly *does*
mean "set this up". Leave the interactive (TTY) dialogue untouched — a human at a prompt is
being asked, not surprised.

Rationale, in one line each:

- The mechanism exists; this is a list edit, not a redesign (Finding 1).
- The ordering that looked load-bearing is an artefact (IW-1).
- The only measured caller was the project's own installer, and it was **harmed** (IW-2).
- The refusal path is already built and already used for unknown verbs (IW-4).
- Blast radius is bounded: it changes behaviour only in directories that are *not*
  projects, where today's behaviour is to write an unrequested project.

**What the operator is deciding**, and why it is theirs: consumer blast radius. Any
consumer script that today runs a read-only `fw` verb in a fresh directory and *depends* on
the implicit bootstrap would start erroring. None was found here, but consumer projects
were not searched — the project-boundary gate (T-559) refuses that from this session, and
per-project dispatch for a read-only census is a separate, larger unit. The honest summary
is: **no evidence of reliance in this repository, and unsearched elsewhere.**

Build slices, if GO: (1) add the verbs to the existing condition and re-point the
`fw_help_no_autoinit.bats:76` control at a write verb; (2) a test per newly-excluded verb
asserting a non-project directory stays untouched; (3) one line in the error naming
`fw init`, matching T-2835's wording.

## 6. Dialogue log

No human dialogue occurred during this exploration — it ran autonomously. The operator's
standing instruction was to work the highest-value eligible task; this one's blocker was
recorded as an evidence gap, and the evidence was reachable inside this repository. The
go/no-go remains the operator's and is not taken here.
