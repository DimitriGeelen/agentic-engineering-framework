# 072 — Reviewer fails-open (rc=0) on catalogue-not-found

- **Filed by:** claude-code @ /opt/termlink (via .pickup drop, G-063-safe — no inbound topic consumer)
- **Date:** 2026-07-03
- **Severity:** MEDIUM (governance blind-spot: a disabled reviewer looks like a passing one)
- **Component:** `lib/reviewer/static_scan.py` (+ vendor/update packaging)
- **TermLink-side tracking:** T-2330 (this bug), T-2329 (the co-discovered vendoring gap)

## Symptom

On a consumer install (/opt/termlink, vendored .agentic-framework), `fw reviewer T-XXX`
inline AND `--dispatch` both returned:

    ERROR: catalogue not found at /opt/termlink/policy/anti-patterns.yaml

…yet the process exited **rc=0**. The dispatch bus artifact literally read
`reviewer: ERROR (rc=0)`.

## Why it matters (fails-open)

`update-task.sh` runs the completion-time auto-review as `... ) || true` (~line 1499,
measurement-only). A hard error that exits rc=0 is therefore **swallowed**: the reviewer
silently no-ops on *every* completed task and nothing surfaces the failure. A governance
tool that is disabled but reports success is worse than one that is absent — it manufactures
false assurance. Classic G-019 "the framework was blind" pattern.

## Root cause (two independent bugs — one bug = one filing, both noted here for causality)

1. **This filing (fails-open):** `static_scan.py` `main()` prints the catalogue-not-found
   error (~line 2456-2458) but does not exit non-zero. It should `sys.exit(2)` (or similar)
   so callers/monitors/CI can detect a broken reviewer. Bonus: `update-task.sh` should not
   `|| true`-swallow a rc that signals "reviewer could not run" vs "reviewer ran, found
   nothing".

2. **Related (T-2329, vendoring):** the catalogue path resolves to
   `framework_root/policy/anti-patterns.yaml` then `project_root/policy/anti-patterns.yaml`
   (`static_scan.py:2452-2457`). The vendored `.agentic-framework/` ships **no `policy/`
   dir at all**, so both paths miss. The AEF vendor/update process must include `policy/`
   in consumer installs. (Worked around locally by copying the 514-line catalogue from this
   AEF checkout; that copy is gitignored and will vanish on the next vendor refresh.)

## Suggested fix

- `static_scan.py`: exit non-zero on catalogue-not-found (bug #1).
- Vendor process: package `policy/anti-patterns.yaml` into consumer `.agentic-framework/`
  (bug #2 / T-2329).
- Optional: `fw doctor` check that the reviewer catalogue is present + parseable.

## Repro

    cd <consumer-project-without-policy-dir>
    fw reviewer <any-completed-task>        # prints ERROR, exits 0
    echo $?                                 # -> 0  (should be non-zero)
