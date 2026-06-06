# T-2231: Field upgrade failure on .121do — Nth recurrence of upgrade-fragility class

**Status:** inception, Recommendation GO (pending operator decision via Watchtower)
**Filed:** 2026-06-06
**Origin:** operator report — *"do our upgrades keep failing?"* on a `.121do` consumer
**Companion to:** T-1542 (40d consumer-side crash), T-2078 (4-slice v1 hardening GO),
T-2229 (BVP onboarding bootstrap GO), T-2093/T-2094/T-2095 (captured-but-stalled prevention)

## Problem Statement

The operator filed a fresh field-failure report on a consumer project shorthanded
as `.121do` (likely `/opt/121-*`; exact path + failure output pending operator
paste in the Dialogue Log of `.tasks/active/T-2231-*.md`). The operator's
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

(See `.tasks/active/T-2231-*.md` §Open Questions for the formal IW-N
disposition table. IW-1 / IW-3 / IW-5 block on the operator's paste of the
.121do failure output. IW-2 / IW-4 / IW-6 are recommendation-ready.)

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
   paste in the Dialogue Log of `.tasks/active/T-2231-*.md`.
4. Requesting operator paste of the .121do failure output so IW-1/IW-3/IW-5
   can resolve.

**Operator decision needed:**
- GO on the chain (`fw inception decide T-2231 go --rationale "..."`) — or NO-GO/DEFER via Watchtower.
- Paste the .121do failure output so the agent can classify against V1-B/C/D symptom inventory and confirm A1 (.121do is a known class).
- Authorise the horizon flip on T-2093/T-2094/T-2095 (`fw task update T-XXX --horizon now`) — this is the structural unblock the chain needs.

## Cross-references

- `.tasks/active/T-1542-fw-upgrade-run-from-inside-a-consumer-pr.md` — 40d started-work
- `.tasks/completed/T-2078-deep-review-fw-upgrade-reliability-for-f.md` — GO inception
- `.tasks/active/T-2093-v1-b-fw-upgrade-strict-exit-code-discipl.md` — V1-B captured
- `.tasks/active/T-2094-v1-c-fw-upgrade-pre-flight-tooling-check.md` — V1-C captured
- `.tasks/active/T-2095-v1-d-fw-upgrade-self-vendor-extraction-i.md` — V1-D captured
- `.tasks/completed/T-2229-onboarding-bootstrap-gap--fw-upgradeinit.md` — GO today
- `.tasks/completed/T-2230-t-2229-slice-1--fw-bvp-driver---init-ver.md` — shipped today
- L-461 — sibling pattern (started-work + Recommendation, close never fires)
- T-1985 — auto-tick rail (the existing close-side mitigation for L-461)
