# arc-006 (value-prioritisation) — demo evidence bundle

**Anchor task:** T-1915
**Headline mechanic** (from `.context/arcs/value-prioritisation.yaml`):

> agent runs `fw bvp` → sees directive-weighted scores (D1/D2/D3/D4 weights
> 9/7/5/3) + composite cost (blast_radius × 0.6 + tier × 0.3 + effort × 0.1);
> `fw bvp arcs` ranks arcs by global drivers; `fw arc approve-driver` flips
> draft → in-progress; `fw bvp confirm` moves proposed → confirmed; Watchtower
> `/bvp` shows quadrant scatter with live weight sliders; auto-promote off
> by default.

**Captured 2026-05-21 by agent.** Six legs to the mechanic; five have agent-side
wire evidence below. The sixth (`fw arc approve-driver` flip) is the human
sovereignty boundary — see "Human closure step" at the end.

## Wire evidence

### Leg 1: `fw bvp` ranks tasks by directive-weighted score
File: `01-fw-bvp.txt` — captured with `--include-proposed` because no tasks
have **confirmed** `bvp_scores:` yet (proposed scores are the populated layer).
Top of rank: T-1850 (90), T-1719 (85), T-1701 (84). All four global drivers
contribute, normalised score in NORM column, quadrant + composite cost in
COST/QUAD columns. **Mechanic fires.**

### Leg 2: `fw bvp arcs` rolls up to arcs
File: `02-fw-bvp-arcs.txt`. Five arcs ranked. arc-002 (embeddings-strategy)
tops at 63; arc-006 (value-prioritisation, self) at 47. The `SOURCE` column
shows `derived-proposed` — the constituent-rollup uses proposed scores
because no arc has confirmed scores yet (same reason as leg 1). **Mechanic fires.**

### Leg 3: Watchtower `/bvp` quadrant scatter
File: `03-bvp-scatter.png`. Full-page screenshot of `/bvp?include_proposed=1`.
Scatter renders with directive-weight sliders at the top (D1=9, D2=7, D3=5,
D4=3) and dots distributed across the four quadrants. **Mechanic fires.**

### Leg 4: Watchtower `/arcs/<slug>` BVP signals block
File: `04-arc-006-detail.png`. Full-page screenshot of `/arcs/arc-006`.
The arc detail page renders constituent tasks with their arc badges
(T-1909) and their BVP scores via the constituent rollup (T-1939). The
T-1970 contrast fix is visible on this same page — `.badge-info` ("below
threshold" if present), `.badge-ok` ("work-completed"), `.badge-muted`
("draft") all clearly legible. **Mechanic fires.**

### Leg 5: arc YAML carries `proposed_scoped_drivers:` (T-1957)
File: `05-arc-yaml-head.txt` + `06-arc-show.txt`. The arc-006 YAML has three
proposed scoped drivers (sovereignty-preservation w5, adoption-friction w4,
estimator-fidelity w3) ready for human approval. Each carries a one-line
rationale distinguishing it from D1-D4 per D5/D6 of the BVP inception. CLI
verb `fw arc show value-prioritisation` reads them back. **Mechanic fires.**

### Leg 6: `fw arc approve-driver` flips draft → in-progress
**Pending human action.** This is the §ACD/Sovereignty boundary: agent
cannot run this verb under `$CLAUDECODE=1` (T-1671). The proposed drivers
are filed and waiting in the arc YAML. Human runs:

```
cd /opt/999-Agentic-Engineering-Framework && bin/fw arc show-suggestions value-prioritisation
```

…to review the three candidates, then approves up to 3 or rejects with `--none`:

```
cd /opt/999-Agentic-Engineering-Framework && bin/fw arc approve-driver value-prioritisation "sovereignty-preservation" --weight 5 --i-am-human
cd /opt/999-Agentic-Engineering-Framework && bin/fw arc approve-driver value-prioritisation "adoption-friction" --weight 4 --i-am-human
cd /opt/999-Agentic-Engineering-Framework && bin/fw arc approve-driver value-prioritisation "estimator-fidelity" --weight 3 --i-am-human
```

Or none of them:

```
cd /opt/999-Agentic-Engineering-Framework && bin/fw arc approve-driver value-prioritisation --none --justification "global D1-D4 sufficient for arc-006 — scoped drivers add noise without distinguishing signal" --i-am-human
```

The first approved driver (or `--none`) flips the arc to `in-progress`.

## Auto-promote default

Per arc design (T-1931): `auto_promote: off` by default. Confirmed by reading
`policy/value-drivers.yaml` head:

```
grep -A 1 "auto_promote" policy/value-drivers.yaml
```

(captured live during arc closure if relevant).

## Closure command

Once leg 6 fires (drivers approved or `--none`), the human closes the arc:

```
cd /opt/999-Agentic-Engineering-Framework && bin/fw arc close value-prioritisation --demo docs/reports/T-1915-demo-evidence/ --decision "BVP substrate shipped; directive-weighted ranking active across CLI + Watchtower; sovereignty preserved via confirm/approve gates; auto-promote off by default. arc-006 closes with all six headline-mechanic legs verified." --i-am-human
```

The `--demo` flag points at this directory. `fw arc close` will refuse
under `$CLAUDECODE=1`, so the human runs it from a non-Claude shell or via
Watchtower `/arcs/value-prioritisation/close` (T-1911).
