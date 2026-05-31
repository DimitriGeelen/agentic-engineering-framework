# arc-006 value-prioritisation — wire-level demo evidence (T-2136)

This directory captures the **headline_mechanic** for the `arc-006` /
`value-prioritisation` arc firing live on this framework install.

> agent runs `fw bvp` → sees directive-weighted scores (D1/D2/D3/D4
> weights **9/7/5/3**) + composite cost (`blast_radius × 0.6 + tier × 0.3
> + effort × 0.1`); `fw bvp arcs` ranks arcs by global drivers; `fw arc
> approve-driver` flips draft → in-progress; `fw bvp confirm` moves
> proposed → confirmed; Watchtower `/bvp` shows quadrant scatter with
> live weight sliders; auto-promote off by default.

Arc YAML: `.context/arcs/value-prioritisation.yaml`
Anchor task: [T-1915](http://192.168.10.107:3000/tasks/T-1915) (inception, recommendation GO)
This task (the capture itself): [T-2136](http://192.168.10.107:3000/tasks/T-2136)

Capture context: 2026-05-31T09:02:34Z, framework repo at master ~ commit
`35e2c4f0` (T-2135 net just shipped — prior to this capture).

## Closing the arc with this directory

When you (the human) are ready to close arc-006, run:

```
cd /opt/999-Agentic-Engineering-Framework && bin/fw arc close value-prioritisation --demo docs/reports/value-prioritisation-demo/ --i-am-human
```

The `--demo` flag points the G-062 closure gate at this directory; the
gate accepts it once it sees ≥1 wire-level artefact traceable to the
headline_mechanic. The README + artefacts below satisfy that contract.
(`fw arc close` refuses under `$CLAUDECODE=1` per T-1671 — this is
deliberate; closure is a sovereignty boundary.)

## Files

| Artefact | What it proves | Shipping task(s) / commit |
|----------|----------------|---------------------------|
| `bvp-rank.txt` | `fw bvp --include-proposed` rendering tasks ordered by directive-weighted BVP, with the configured D1/D2/D3/D4 weights visible in scoring; SOURCE column distinguishes confirmed vs proposed (T-1938) | T-1918, T-1924, T-1925, T-1938 |
| `bvp-arcs.txt` | `fw bvp arcs` ranking arcs by rolled-up constituent-task scores (`SOURCE: derived-proposed` column, T-1937) | T-1936 (`64e1c057`), T-1937 (`ed7ef29f`), T-1939 (`5b53c74f`) |
| `bvp-task-detail-T-1850.txt` | `fw bvp T-1850` per-driver detail — DRIVER/NAME/WEIGHT/SCORE/CONTRIB table with D1=9, D2=7, D3=5, D4=3, F1=3 (proves both the directive-weight clause and the F-driver schema, M1) | T-1918, T-1933 (`296b7ad8`) |
| `bvp-arc-show.txt` | `fw arc show value-prioritisation` showing `scoped_drivers:` with one approved entry (`estimator-fidelity`, weight 3, `approved_at: 2026-05-21`) — proves `fw arc approve-driver` flipped draft → in-progress | T-1925 (`14d42a20`), T-1926, T-1957 (`bc474bdc`) |
| `bvp-weight-history-excerpt.yaml` | First 30 lines of `.context/bvp-weight-history.yaml` — audit row schema present, free-driver add tracked, R6 rationale field captured | T-1924 (`25207209`), M6 weight-change gate |
| `bvp-confirm-sovereignty-refusal.txt` | `fw bvp confirm` refuses agent invocation — message names §ACD/M6/D8, lists override flags (`--i-am-human` / `--from-watchtower`), mirrors T-1259 inception-decide and T-1671 arc-close patterns. Proves the sovereignty boundary on confirmed scores is enforced structurally, not by convention. | T-1924 (`25207209`) |
| `screenshot-bvp.png` | `/bvp` rendered showing (a) Live weight sliders for D1/D2/D3/D4=9/7/5/3 + F1 free driver, with D-drivers marked "protected" (D8 sovereignty visualised), Commit-changes button (greyed until slider moves), Rationale ≥30 chars (R6); (b) Add-free-driver form (M1); (c) Quadrant scatter with X-axis `Cost composite (F8: 0.6 × br + 0.3 × tier + 0.1 × effort)` and Y-axis `BVP score`, ~270 points (tasks + arcs), legend distinguishing confirmed/proposed. | T-1928 (`e87d6f99`) scatter, T-1929 (`311e7b79`) sliders, T-1934 proposed-scatter, T-1936 arc dots, T-1964 driver-add, T-1965 driver-remove |
| `screenshot-arcs-value-prioritisation.png` | `/arcs/value-prioritisation` rendered showing arc-level BVP signals (`Arc BVP_norm 0.415`, `Arc BVP_raw 56`, `Source: derived-proposed`), Drivers row `D1=9 · D2=7 · D3=5 · D4=3 · F1=3` exactly matching the headline_mechanic weights, and the `below threshold` G-062 audit-detective badge (T-1656). | T-1930 (`e350294e`), T-1936, T-1939 |

## What each headline-mechanic clause maps to

| Clause | Artefact(s) |
|--------|-------------|
| `fw bvp` shows directive-weighted scores | `bvp-rank.txt`, `bvp-task-detail-T-1850.txt` (WEIGHT column) |
| Composite cost (`br × 0.6 + tier × 0.3 + effort × 0.1`) | X-axis label in `screenshot-bvp.png` ("Cost composite (F8: 0.6 × br + 0.3 × tier + 0.1 × effort)"); F8 row visible in per-task detail |
| `fw bvp arcs` ranks arcs by global drivers | `bvp-arcs.txt` |
| `fw arc approve-driver` flips draft → in-progress | `bvp-arc-show.txt` (the `scoped_drivers: - name: estimator-fidelity ... approved_at: 2026-05-21` entry IS the flip) |
| `fw bvp confirm` moves proposed → confirmed (sovereignty-gated) | `bvp-confirm-sovereignty-refusal.txt` — gate present and refuses agent invocation. No task in the corpus currently has confirmed `bvp_scores:` because the gate has not yet been exercised by a human; that absence is itself part of the contract (proposed-only by default, human moves to confirmed deliberately). |
| Watchtower `/bvp` shows quadrant scatter with live weight sliders | `screenshot-bvp.png` |
| Auto-promote off by default | Captured indirectly: `bvp_scores:` is empty across the entire corpus (no task auto-promoted by the estimator) — confirmable via `grep -rl "^bvp_scores:" .tasks/ | wc -l` returning 0 (only proposed scores persisted). |

## What this directory does NOT do

This is **pre-close evidence**, not a close. The arc remains
`status: in-progress` in `.context/arcs/value-prioritisation.yaml`
until the human runs `fw arc close value-prioritisation --demo ...
--i-am-human` (or via Watchtower at `/arcs/value-prioritisation/close`,
which sets `--from-watchtower`).

Two open closure-relevant items separate from `demo_evidence`:

1. `proposed_scoped_drivers:` in the arc YAML has two unapproved
   candidates (`sovereignty-preservation` weight 5,
   `adoption-friction` weight 4 — both filed by T-1957 self-application).
   The human approves up to 3 with `fw arc approve-driver` or rejects
   all with `--none --justification "..."`.
2. The 50+ arc-006 partial-complete tasks have unchecked `[REVIEW]`
   Human ACs (see `/approvals` or `bin/fw review-queue`); none are
   closure-blocking under the G-062 gate (the gate fires on
   `demo_evidence` + headline_mechanic capture, not on member-task
   completion), but the human may want to clear them before closing
   to keep the arc-close record tidy.

## Cross-references

- Inception: `docs/reports/T-1915-bvp-inception.md` (the GO that filed
  T-NEW-2..15 build slices).
- Canonical doc: `docs/030-design/040-ValueDrivers.md` (T-1933).
- Same-pattern arc-005 demo: `docs/reports/orchestrator-rethink-demo/`
  (used as template for this capture's shape).
- Headline_mechanic gate: `lib/arc.sh` (G-062, T-1655 + T-1656 +
  T-1657 mechanism trio).
