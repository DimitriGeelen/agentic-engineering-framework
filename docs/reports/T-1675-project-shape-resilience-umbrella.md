# T-1675 — Project-shape resilience umbrella

**Workflow type:** inception
**Arc:** project-shape-resilience (anchor T-1675)
**Companion incidents:** T-1257, T-1542, T-1634, T-1635, T-1673
**Anchor incident (this session):** `bin/fw config list` framework-repo conflation

This artifact summarises the analysis already filed in the task body
(`.tasks/active/T-1675-*.md`) and adds the spike measurements that
informed the recommendation. The task body remains the primary
artifact; this file exists to satisfy C-001 and to give the
human-review surface a single landing page.

## 1. The pattern in one sentence

Framework code that assumes ONE project shape (initialized consumer)
and silently degrades on the others — framework-repo, fresh consumer,
vendored-skewed consumer.

## 2. Project shapes (4 enumerated)

| Shape                        | Signal                                                 |
|------------------------------|--------------------------------------------------------|
| framework-repo               | `FRAMEWORK.md` + `bin/fw` at root, no `.framework.yaml` |
| consumer-initialized         | `.framework.yaml` + `.agentic-framework/bin/fw`        |
| consumer-uninitialized       | bare directory, no fw artefacts                        |
| consumer-vendored-skewed     | `.framework.yaml` present, vendored shim out of sync   |

## 3. Spikes

### A3 — Refactor surface measurement

**Run on master at d791fbbdc..2f3e61dca:**

| Probe                                              | Count |
|----------------------------------------------------|------:|
| `grep -rE "\.framework\.yaml" lib/ bin/fw`         |   103 |
| Files containing references                        |    11 |
| Sites doing `[ -f .framework.yaml ]` existence tests |   ~13 |

A3 (refactor surface ≤50 sites) **holds**. Lever 1 is a tractable
refactor: ~13 conflation sites across 11 files, all in `lib/`.

### A2 — Filesystem-only classifier feasibility

A 25-line bash function, run against 4 synthetic fixtures + 13 real
consumer projects on this host:

```bash
fw_project_context() {
    local root="${1:-$(pwd)}"
    if [ -f "$root/FRAMEWORK.md" ] && [ -x "$root/bin/fw" ] \
       && [ ! -f "$root/.framework.yaml" ]; then
        echo framework; return
    fi
    if [ -f "$root/.framework.yaml" ] \
       && [ -x "$root/.agentic-framework/bin/fw" ]; then
        # vendored-vs-framework version compare (skew detection)
        ...
        echo consumer-initialized; return
    fi
    if [ -f "$root/.framework.yaml" ] \
       && [ ! -d "$root/.agentic-framework" ]; then
        echo consumer-vendored-skewed; return
    fi
    if [ ! -f "$root/.framework.yaml" ] \
       && [ ! -d "$root/.agentic-framework" ] \
       && [ ! -f "$root/FRAMEWORK.md" ]; then
        echo consumer-uninitialized; return
    fi
    echo unknown
}
```

| Fixture                                          | Expected                  | Got                         |
|--------------------------------------------------|---------------------------|-----------------------------|
| `/opt/999-Agentic-Engineering-Framework`         | `framework`               | `framework` ✓               |
| fresh `mktemp -d`                                | `consumer-uninitialized`  | `consumer-uninitialized` ✓  |
| synthetic: `.framework.yaml` + shim symlink      | `consumer-initialized`    | `consumer-initialized` ✓    |
| synthetic: `.framework.yaml` only, no shim       | `consumer-vendored-skewed`| `consumer-vendored-skewed` ✓|
| 13 real consumer projects on this host           | `consumer-initialized`    | `consumer-initialized` × 13 ✓|

A2 (filesystem-only disambiguation) **holds**. No env-var inputs
needed. No exotic edge cases on the live host.

**Caveat for the build task:** the `consumer-vendored-skewed`
detection in this spike fires on STRUCTURAL skew (yaml present + no
shim dir). True VERSION skew (yaml + shim dir + version mismatch)
needs the comparison logic exercised on a real fixture; none of the
13 live consumers exhibit it. Build task should add a fixture that
forces version skew explicitly.

## 4. Anchor demonstration

```
$ cd /opt/999-Agentic-Engineering-Framework
$ bin/fw config list
No .framework.yaml found at /opt/999-Agentic-Engineering-Framework/.framework.yaml
$ echo $?
1
```

`_config_list()` at `lib/config-file.sh:177-181` hard-fails. Same
error a broken consumer would see; conflates "framework repo
(expected absent)" with "consumer broken (genuinely absent)".

## 5. Three structural levers (recommendation: Lever 1 first)

See `## Recommendation` in the task body for full rationale, sequence,
and promotion criteria. Summary:

| Lever | What                              | Effort   | When  |
|-------|-----------------------------------|----------|-------|
| 1     | `fw_project_context()` classifier | ~0.5 day | first |
| 2     | Three-shape test matrix           | per verb | next  |
| 3     | Upgrade-simulation CI (T-1635)    | bigger   | over Q |

## 6. Pre-existing constituent tasks (arc-tagged)

- T-1257 — completed: `bin/fw` vs `.agentic-framework/bin/fw` agent guidance
- T-1542 — active: `fw upgrade` from inside consumer crashes step 4b/9
- T-1634 — captured: `fw upgrade no-args` upstream URL resolution
- T-1635 — captured: `fw upgrade` fresh-machine simulation guard
- T-1673 — completed: cross-repo card absolute-path orphan check (this session)

## 7. Human review surface

- This artifact — entry point
- Task file — full Problem Statement / Assumptions / Recommendation
- `fw task review T-1675` — Watchtower view with QR + decision form

## Dialogue log

This artifact was triggered by the user's question 2026-05-02:
"how do we cater for this stucturally, to improve the rate of
successful upgrades?" — referring to the `fw config list` and `fw
push 502` incidents in this session.

The agent's answer (in conversation) was the three-lever framing.
The user replied "yes prio now" to the offer to file an inception arc
tying T-1542 / T-1634 / T-1635 + the conflation pattern under one
concern.

This task and its arc were created in direct response. The
exploration plan time-boxes (3 × 30min) are NOT executed in this
filing turn — they execute when a human GO decision lands and the
build task takes them on. Filing first; deciding next.
