# Risk matrix — <change being assessed> (T-XXXX)

<!-- T-5313 (T-5310 GO, operator 2026-11-20; template from ring20, their arc-012).
     Copy to docs/reports/T-XXXX-risk-matrix.md for the task that makes the change.
     One matrix per change. Risks scoring 6 or more get a mitigation task in the
     standing arc "risk" and an entry in .context/project/concerns.yaml (type: risk).
     Validated by lib/risk_register.py (run by `fw audit`, gaps section). -->

## When a matrix is required

Fill one for any change that **alters a trust boundary**:

- a **new sandbox** or isolation boundary (a model or worker running with tools somewhere new);
- a **new credential use** (a token, key or login used by something that did not use it before, or in a new place);
- a **new network path** (a new route to a host, hub, API or the internet, or a new listener);
- **new unattended automation** (a cron job, hook, daemon or worker that acts without a person watching).

A change that does none of these does not need a matrix. If you are unsure, it does.

## Who decides what

| Step | Who |
|------|-----|
| Draft the matrix and score every risk and actor | the agent making the change |
| Check the scores, the actor split and the "introduced?" column | an independent reviewer agent (`fw reviewer judge`) |
| **Risk acceptance**: an INTRODUCED risk still at 6 or more after mitigation, or any risk at 15 or more | the operator, and only this |

The decision on a change rests on what it **introduces**, not on risks that exist anyway.
Do not argue 3 versus 4: the bands and the "introduced?" column carry the decision.

## Header

- **Change:** <one sentence: what is being changed>
- **Baseline:** <what it is compared with: the state today, or the alternative option>
- **Task:** T-XXXX

## Scales

| Value | Likelihood | Impact |
|------:|------------|--------|
| 1 | rare | negligible |
| 2 | unlikely | minor |
| 3 | possible | moderate (one job or result wrong) |
| 4 | likely | major (token stolen or data leaked, contained) |
| 5 | almost certain | severe (node or network compromised, accounts lost) |

**Score** = likelihood × impact, 1-25. **Bands:** low 1-5, medium 6-12, high 15-25.

## Summary

| # | Risk | Domain | How to detect the door is open | How to detect it happening | Impact | Likelihood | Exists anyway (baseline)? | Introduced by the change? | Key mitigation |
|---|------|--------|--------------------------------|----------------------------|-------:|-----------:|---------------------------|---------------------------|----------------|
| 1 | | | | | | | yes / no | no / NEW / PARTLY NEW (why) / reduced | |

## Actor split (one table per risk)

Actors (fixed list): `own-agent-unintentional`, `human-unintentional`, `outsider-intentional`, `provider-host`, `intruder`.

### Risk 1 — <name>

| # | Actor | How | L | I | Score | Mitigated L × I | Mitigated score |
|---|-------|-----|--:|--:|------:|-----------------|----------------:|
| 1.1 | own-agent-unintentional | | | | | | |
| 1.2 | human-unintentional | | | | | | |
| 1.3 | outsider-intentional | | | | | | |
| 1.4 | provider-host | | | | | | |
| 1.5 | intruder | | | | | | |

## Rule

Every risk with **any actor scoring 6 or more** gets a mitigation task in the standing arc
`risk` (`arc_id: risk`) and an entry in `.context/project/concerns.yaml`:

```yaml
- id: R-NNN
  type: risk
  title: <risk name>
  description: <one or two lines>
  status: watching            # resolved / closed / mitigated / accepted end the mitigation rule
  likelihood: 3               # worst actor, unmitigated
  impact: 4
  score: 12                   # must equal likelihood x impact
  ranking: medium             # low 1-5 / medium 6-12 / high 15-25
  actors:
  - actor: own-agent-unintentional
    how: <one line>
    likelihood: 3
    impact: 4
    mitigated_likelihood: 2
    mitigated_impact: 2
  introduced_by: T-XXXX       # the change, when it introduces the risk
  exists_anyway: false        # true when the baseline has it without the change
  mitigation_task: T-YYYY     # task in the standing arc "risk"
  created: YYYY-MM-DD
```

`fw audit` FAILs on out-of-range values, unknown actors or a wrong score, and WARNs on an
open assessed risk at 6 or more without a `mitigation_task`. Check by hand:
`python3 lib/risk_register.py` (consumer projects: `.agentic-framework/lib/risk_register.py`).

## Net

<What the change adds, what it reduces, and the controls it needs. Name each risk that needs
operator acceptance (introduced and still 6+ after mitigation, or 15+), or "none".>
