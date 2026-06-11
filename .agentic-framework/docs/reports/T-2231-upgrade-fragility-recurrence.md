# T-2231: Field upgrade failure on .121do — Nth recurrence of upgrade-fragility class

**Status:** inception, Recommendation GO (pending operator decision via Watchtower)
**Filed:** 2026-06-06
**Origin:** operator report — *"do our upgrades keep failing?"* on a `.121do` consumer
**Companion to:** T-1542 (40d consumer-side crash), T-2078 (4-slice v1 hardening GO),
T-2229 (BVP onboarding bootstrap GO), T-2093/T-2094/T-2095 (captured-but-stalled prevention)

## Problem Statement

The operator filed a fresh field-failure report on a consumer project shorthanded
as `.121do` (likely `/opt/121-*`; exact path + failure output pending operator
paste in the Dialogue Log of `.tasks/completed/T-2231-*.md`). The operator's
verbatim meta-question — *"do our upgrades keep failing?"* — has an
evidence-backed answer:

**Yes.** And the framework has known about the fragility class for at least
8 days, has filed structural prevention work (T-2093/T-2094/T-2095 under the
T-2078 GO'd v1 hardening), and the prevention work has not shipped while
field upgrades continue to fail.

## Evidence — the fragility timeline

| Date | Task | Status | Subsystem | Direct evidence |
|------|------|--------|-----------|-----------------|
| 2026-04-27 | T-1542 | started-work, **40d** | upgrade-step-4b | "fw upgrade from inside a consumer crashes at step 4b/9 — detect bare-from-consumer" |
| 2026-05-29 | T-2078 | **GO** (inception) | upgrade reliability | "deep review fw upgrade reliability for field deployment" — authorised 4-slice v1 chain |
| 2026-05-29 | T-2093 | captured, **8d** | exit-code discipline | V1-B — strict exit-code + rollback on mid-upgrade failure |
| 2026-05-29 | T-2094 | captured, **8d** | preflight | V1-C — pre-flight tooling check + post-upgrade fw doctor advisory |
| 2026-05-29 | T-2095 | captured, **8d** | self-vendor | V1-D — self-vendor extraction into a separate verb |
| 2026-06-06 | T-2229 | **GO** (inception) | BVP onboarding | "policy/value-drivers.yaml + .context/arcs/ not seeded by fw init/upgrade/vendor" |
| 2026-06-06 | T-2230 | **shipped** | BVP onboarding | Slice 1: `fw bvp driver --init` verb |
| 2026-06-06 | **.121do** | **new failure** | UNKNOWN | filed as T-2231; details pending operator paste |

## The structural class

**Sibling of L-461 (stale partial-completes), but on the *captured* side:**
GO'd inception + filed child slices → slices sit `captured` → forgotten in
the active backlog → recurrence of the failure class the children were
designed to prevent.

T-1985 / L-461 covers `started-work + Recommendation written + close gate
never fired` (filed work degrades stale on the close side).
This proposes the symmetric backstop: `captured + parent inception GO'd
N days ago → WARN that prevention has stalled` (filed work degrades stale
on the start side).

## Recommendation

**Recommendation:** GO

**Rationale:**

Evidence is overwhelming. Three field failures in 40 days, against a backdrop
of three captured prevention slices that haven't shipped in 8 days. The
prevention work was authorised by an explicit inception GO (T-2078). The
shipping path is agent-runnable (V1-B → V1-C → V1-D are all build slices with
no sovereignty dependency); only the `horizon` flip is operator-gated as a
priority call.

The .121do failure is the trigger; the systemic class is the real subject:
**captured-but-not-promoted prevention work degrades silently the longer it
sits, while field failures accumulate**. Shipping V1-B/C/D resolves the
immediate fragility class; the sibling-of-L-461 detector closes the structural
hole that let the chain stall.

DEFER would be a hedge per T-2144 — evidence is complete; the only unknowns
are .121do's exact symptom (Spike A) and the operator's preferred shipping
pace (sequential vs parallel, ladder vs all-at-once). Both are build-time
questions that resolve under any GO path.

**Evidence:**

- T-1542 frontmatter: `status: started-work`, `created: 2026-04-27` (40d).
- T-2078 completed/: workflow_type inception, Recommendation GO.
- T-2093/T-2094/T-2095 frontmatter: `status: captured`, `created: 2026-05-29` (8d). Names: "V1-b ... strict exit-code", "V1-c ... pre-flight", "V1-d ... self-vendor extraction".
- T-2229 GO'd 2026-06-06 via Watchtower (commit 2f0d1420d).
- T-2230 work-completed 2026-06-06 (commit 9eeaf6dfc).
- .121do — operator-reported now; details pending paste.

## Open Questions

(See `.tasks/completed/T-2231-*.md` §Open Questions for the formal IW-N
disposition table. IW-1 / IW-3 / IW-5 block on the operator's paste of the
.121do failure output. IW-2 / IW-4 / IW-6 are recommendation-ready.)

## Update — 2026-06-06T13:25Z: Operator GO recorded + .121do classified

**Operator decision (Watchtower 2026-06-06T13:14:29Z, commit `28490709c`):** GO.

**.121do shorthand decoded (no operator paste required):** `192.168.10.121` is the **ring20-dashboard host** (per PL-001-004 + `fw recall "121"`). The "do" suffix is `dashboard → do`. The framework already had a live TermLink remote session (`tl-tfjl34mm` on hub `ring20-dashboard:9100`, state=ready); probing it reproduced the failure exactly.

**Live failure (reproduced via `termlink remote exec`):**

```
$ cd /root/ring20-dashboard && .agentic-framework/bin/fw upgrade
ERROR: fw upgrade invoked from inside the consumer's vendored framework
  FRAMEWORK_ROOT: /root/ring20-dashboard/.agentic-framework
  target_dir:     /root/ring20-dashboard
  Vendored copy:  /root/ring20-dashboard/.agentic-framework
  Source and target collapse — do_vendor would self-copy and corrupt state.
  No changes made.
Run from an upstream framework repo with explicit target:
  cd /path/to/agentic-engineering-framework && bin/fw upgrade /root/ring20-dashboard
```

**fw doctor on ring20-dashboard:**

```
WARN  Version mismatch: pinned=1.6.7 installed=1.6.260
WARN  [host] Duplicate framework hook(s) in /root/.claude/settings.json: 14 overlap
```

The `.framework.yaml` pin says `1.6.7` (init 2026-04-08); installed is `1.6.260`. The operator has been trying to `fw upgrade` from inside the consumer; the vendored shim correctly refuses to self-copy (T-680 collapse check), so the pin stays stuck **253 versions behind** while the current install reports a refreshed shim.

### IW disposition (now resolved with wire-level evidence)

- **IW-1 — answered (confidence 3):** .121do failure IS T-1542's class — `fw upgrade` invoked from inside a consumer's vendored framework, source/target collapse refused, no progress. The vendored shim's refusal is structurally **correct** (preventing self-corruption per do_vendor's T-680 collapse check); the UX gap is that the operator has no in-consumer path to bump the pin and re-vendor.
- **IW-3 — answered (confidence 2):** .121do is **NOT** a new class. It is a textbook recurrence of T-1542's existing started-work scope (40 days open).
- **IW-5 — answered (confidence 3):** T-1542 and the V1-B/C/D chain are **the right fix**. Specifically T-2095 (V1-D — self-vendor extraction into a separate verb) directly addresses the in-consumer upgrade path the operator wants. T-1542 is **not subsumed** by V1-B/C/D — it is the **root cause** they share; closing T-1542 means shipping T-2095 (at minimum).
- **IW-2** (sequential vs parallel ship pace) — remains operator-call.
- **IW-4** (captured-prevention-stalled audit detector) — answered, agent-buildable as own slice post-V1.
- **IW-6** (T-2078 inception_decisions/unlocks_inception_decision traceability) — deferred; addressed in a follow-up audit slice.

### Recovery options for ring20-dashboard (operator authorisation needed)

The framework cannot edit cross-repo. The available recoveries:

- **(A) Upstream-side upgrade from this host** (one-shot): `cd /opt/999-Agentic-Engineering-Framework && bin/fw upgrade /root/ring20-dashboard` — this is what the consumer's error already recommends. Cross-machine variant via TermLink: cross-machine, destructive shape — **requires operator GO** (cd /opt/999-Agentic-Engineering-Framework && bin/fw upgrade target via the TermLink-routed shim).
- **(B) Wait for V1-D (T-2095) to ship**, then the consumer can self-upgrade via the new verb. Right durable fix; takes a build cycle.

The agent's recommendation: ship V1-B → V1-C → V1-D under the existing T-2231 GO (build path enumerated above), use (A) for ring20-dashboard as a one-shot recovery while V1-D is in flight.

## Dialogue Log

### 2026-06-06 — Operator bug report (verbatim)

> "anoteh rfailing uipgrade !!!!!! please chekc messages and asses , incpoet
> to fricking failure from .121do do our upgrades keep faling ???!!!"

**Agent action:**
1. Checked inbox (`fw note list`), pickup channel (`fw pickup status`),
   TermLink local + remote (`termlink inbox list`, `termlink remote inbox list`)
   — no new content carrying the .121do output.
2. Walked the upgrade-fragility history — table above is the receipt.
3. Filed this inception with the pattern + a placeholder for the .121do
   paste in the Dialogue Log of `.tasks/completed/T-2231-*.md`.
4. Requesting operator paste of the .121do failure output so IW-1/IW-3/IW-5
   can resolve.

**Operator decision needed:**
- GO on the chain (`fw inception decide T-2231 go --rationale "..."`) — or NO-GO/DEFER via Watchtower.
- Paste the .121do failure output so the agent can classify against V1-B/C/D symptom inventory and confirm A1 (.121do is a known class).
- Authorise the horizon flip on T-2093/T-2094/T-2095 (`fw task update T-XXX --horizon now`) — this is the structural unblock the chain needs.

## Cross-references

- `.tasks/active/T-1542-fw-upgrade-run-from-inside-a-consumer-pr.md` — 40d started-work
- `.tasks/completed/T-2078-deep-review-fw-upgrade-reliability-for-f.md` — GO inception
- `.tasks/completed/T-2093-v1-b-fw-upgrade-strict-exit-code-discipl.md` — V1-B captured
- `.tasks/completed/T-2094-v1-c-fw-upgrade-pre-flight-tooling-check.md` — V1-C captured
- `.tasks/completed/T-2095-v1-d-fw-upgrade-self-vendor-extraction-i.md` — V1-D captured
- `.tasks/completed/T-2229-onboarding-bootstrap-gap--fw-upgradeinit.md` — GO today
- `.tasks/completed/T-2230-t-2229-slice-1--fw-bvp-driver---init-ver.md` — shipped today
- L-461 — sibling pattern (started-work + Recommendation, close never fires)
- T-1985 — auto-tick rail (the existing close-side mitigation for L-461)
