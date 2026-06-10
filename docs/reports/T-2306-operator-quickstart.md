# T-2306 Operator Quickstart — Implementing the Three BVP Drivers

**Why this doc exists:** T-2305 §8 ("CLI commands to execute") was authored against the assumption that `fw bvp recompute --scope global` would ship as a CLI verb. T-2245 IW-3 later deferred the loader verbs (`recompute` / `suggest` / `create` / `edit` / `retire`); sharpening happens manually today, and the loader contract is stable for the eventual handoff. The T-2305 corrigendum at the top of the artifact acknowledged the uncertainty about `fw bvp recompute`, but §8 itself was never amended.

This quickstart documents the **actually-shipped path** at filing time (2026-06-10), verified against `bin/fw bvp --help` and `bash agents/termlink/bvp-estimator/bvp-estimator.sh --help`. Use this when running T-2306; treat T-2305 §8 as the design contract that informed it.

The execution path has three legs: **(1) add the three drivers**, **(2) recompute scores against the new dimensions**, **(3) confirm new scores per task**. Each leg is Sovereign or §ACD-gated — you (the operator) drive them; the agent has staged the prerequisites.

---

## Pre-checks (run once, before §1)

```
cd /opt/999-Agentic-Engineering-Framework && bin/fw bvp driver --init 2>&1 | tail -3 && echo "---" && test -f policy/value-drivers.yaml && grep -c "^  - id:" policy/value-drivers.yaml
```

Expected: `--init` reports "already initialised" (or initialises), and the grep shows 6 driver entries (4 protected D1-D4 + 2 free F-RECALL, F-ORCH). The free-driver pool currently has 2 of 5 slots used — exact fit for the three this batch adds.

---

## §1 — Add the three drivers (Sovereign — operator only)

`fw bvp driver --add` refuses under `$CLAUDECODE=1` per D8 policy-edit sovereignty. Run these from a non-CLAUDECODE shell, OR with `--i-am-human` from within an agent session if you (the human) are typing them yourself, OR via Watchtower's `/bvp` add-driver form once T-1964 is shipped.

Single-line per `fw` command per T-609 / T-1257 / [[feedback_handoff_docs_verify_cli_verbs]]:

```
cd /opt/999-Agentic-Engineering-Framework && bin/fw bvp driver --add "V_PROMPT_QUALITY" --weight 7 --rationale "Discriminates LLM prompt-quality work from work on other aspects. Core to AEF's value as an agentic framework. Source: docs/reports/T-2305-bvp-drivers-batch-2026-06-10.md"
```

```
cd /opt/999-Agentic-Engineering-Framework && bin/fw bvp driver --add "V_CONTEXT_FABRIC" --weight 7 --rationale "Discriminates memory-layer work (Context Fabric: working/project/episodic memory, semantic search) from work elsewhere. Load-bearing for cross-session continuity. Source: docs/reports/T-2305-bvp-drivers-batch-2026-06-10.md"
```

```
cd /opt/999-Agentic-Engineering-Framework && bin/fw bvp driver --add "V_COMPONENT_FABRIC" --weight 6 --rationale "Discriminates topology-layer work (Component Fabric: dependency mapping, blast-radius, drift detection) from work elsewhere. Load-bearing for BVP cost composite and audit. Source: docs/reports/T-2305-bvp-drivers-batch-2026-06-10.md"
```

After each add, the policy file's `free_drivers:` list grows by one entry, and a weight-history row writes to `.context/bvp-weight-history.yaml`.

**Verify after §1:**

```
cd /opt/999-Agentic-Engineering-Framework && grep -cE "^  - id: V_" policy/value-drivers.yaml
```

Expected: `3`.

---

## §2 — Bulk re-estimate against the new drivers (NOT Sovereign — agent or operator)

T-2305 §8 originally said `fw bvp recompute --scope global --trigger "batch-driver-add" --rationale "..."` — that verb is **deferred** per T-2245 IW-3. The actually-shipped equivalent is the estimator's `all` mode:

```
cd /opt/999-Agentic-Engineering-Framework && bash agents/termlink/bvp-estimator/bvp-estimator.sh all --dry-run 2>&1 | tail -20
```

Preview: how many task files would write `bvp_scores_proposed:` entries against the new free-driver dimensions. The estimator scores every task in `active/` + `completed/` (no `--statuses` filter passes them all).

Then apply:

```
cd /opt/999-Agentic-Engineering-Framework && bash agents/termlink/bvp-estimator/bvp-estimator.sh all 2>&1 | tail -10
```

This writes one `bvp_scores_proposed:` timestamped entry per task to each `.tasks/{active,completed}/T-*.md`. The new V_PROMPT_QUALITY / V_CONTEXT_FABRIC / V_COMPONENT_FABRIC entries land alongside D1-D4 + F-RECALL + F-ORCH in each row. Existing `bvp_scores:` (operator-confirmed) are untouched.

**Optional pre-scope with `--limit`:**

```
cd /opt/999-Agentic-Engineering-Framework && bash agents/termlink/bvp-estimator/bvp-estimator.sh all --limit 50
```

For a faster spot-check before the full sweep. The full sweep over ~200 active + N completed tasks takes O(seconds).

---

## §3 — Confirm per task (Sovereign — operator only)

`fw bvp confirm T-XXX` is Sovereign-gated under `$CLAUDECODE=1` per the M6 §ACD rail. Confirming a task moves `bvp_scores_proposed:` → `bvp_scores:` on that task, stamping `confirmed_by` and `confirmed_at`, and clears the proposed entry so the next estimator sweep can re-propose if scores drift past the M3 v2-delta threshold.

```
cd /opt/999-Agentic-Engineering-Framework && bin/fw bvp confirm T-XXX --i-am-human
```

You don't have to confirm every task — `fw bvp` rank only shows tasks with confirmed `bvp_scores:`. The estimator's proposed entries surface in `fw bvp --include-proposed` for the advisory view. Confirm the tasks whose ranking signal you want surfaced in the default HV-LC sweep.

**Recommended first-batch confirms** (the tasks you've engaged with most recently, where you have the strongest signal):

```
cd /opt/999-Agentic-Engineering-Framework && for t in T-2303 T-2306 T-2323 T-2324; do bin/fw bvp confirm $t --i-am-human 2>&1 | tail -1; done
```

This gives `fw bvp` rank a baseline of 4 confirmed entries to start surfacing meaningful HV-LC nominations.

---

## §4 — Verify state end-to-end

```
cd /opt/999-Agentic-Engineering-Framework && bin/fw audit --section structure 2>&1 | grep -E "free driver|WARN|FAIL" | head -5
```

Expected: `[WARN] free driver F-ORCH: retire_when condition appears met` (pre-existing, see T-2320 advisory brief) + the cards-no-edges floor WARN, both unrelated to driver-add. No new FAILs.

```
cd /opt/999-Agentic-Engineering-Framework && bin/fw bvp 2>&1 | head -15
```

Expected: ranked list of confirmed tasks now visible (was empty before §3 confirms).

```
cd /opt/999-Agentic-Engineering-Framework && bin/fw doctor 2>&1 | grep -E "WARN|FAIL" | head -5
```

Expected: no new failures.

---

## §5 — T-2306 close path

After §1 + §2 + §3, the Agent ACs on T-2306 are mechanically satisfiable. The Human AC "Global BVP recompute confirmation" maps to the §2 above. Once you've run §2 + a representative §3 batch:

```
cd /opt/999-Agentic-Engineering-Framework && bin/fw task review T-2306
```

Opens Watchtower `/review/T-2306` — review the Recommendation block, tick the Human AC, and click Complete. The task moves to `completed/`.

---

## Cross-references

- **Original §8 (design contract):** `docs/reports/T-2305-bvp-drivers-batch-2026-06-10.md` §8
- **Corrigendum at top of T-2305:** acknowledges `fw bvp recompute` verb status uncertainty (this quickstart resolves it)
- **OBS-070:** filed 2026-06-10 surfacing the §8 / shipped-state gap
- **L-NEW [[feedback_handoff_docs_verify_cli_verbs]]:** discipline rule for future §8 / pickup-prompt CLI snippets
- **T-2245 IW-3:** deferred the loader verbs (`recompute` etc.); contract stable for the eventual handoff
- **Sovereignty boundaries:** §1 + §3 are operator-only; §2 is agent-runnable (the estimator is not Sovereign)
- **`fw bvp confirm` contract:** lib/bvp.sh `cmd_confirm()` — refuses under `$CLAUDECODE=1` unless `--i-am-human` or `--from-watchtower`
