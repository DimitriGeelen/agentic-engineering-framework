I've read the report. Now let me verify the claims against the code.
Now let me verify the specific claims. I'll grep for `value-drivers` in the specific directories and read the key files.
`rg` isn't available; using grep instead.
Now let me read the key code sections to verify the design's claims. Starting with the estimator, bvp.sh, arc.sh caps, and the hook allowlist.
Key sections verified so far. Now let me check `lib/arc.sh` caps, `lib/bvp.sh` ranking surfaces, `arc_membership.py`, and the audit scorability scan.
audit.sh's scorability check delegates to `lib/bvp-scorability.sh` (covered), but the split-root lint at audit.sh:2566 is a potential trap. Now let me verify `lib/bvp.sh`, `arc_membership.py`, and the remaining §3 rows.
Now the remaining pieces: `compute_bvp`, `_find_driver_entry`, `arc_membership.py`, `resolver.py`, `bvp_judge.py`, and `arc_close_readiness.py`.
Nearly done. Let me verify the last claims: estimator callers, `cmd_detail`, arc.sh:2423, and whether `fw bvp rank` has JSON output (for WARNING visibility).
All claims verified. Here is my review.

---

# Independent review — T-4967 design (`docs/reports/T-4961-driver-sets.md` §Design)

**Verified correct first:** Point 3's "no change" claim is right — all four caps guard `scoped_drivers:` write paths only (`lib/arc.sh:1568,1624,1930,2423`); set weights never pass through them. Point 4's citations check out (`lib/bvp.sh:214-231,405-406,566-567,784-785,1415-1421,2074`), including the necessary catch that auto-promote's `max_possible` must go per-task. Audit's scorability check is not a missed reader — it delegates to `lib/bvp-scorability.sh` (`agents/audit/audit.sh:5037-5042`). The hooks line is an exact-name vendor-class list, not a commit allowlist, so set files are simply outside the vendor class (`agents/git/lib/hooks.sh:1418`) — the design's deferred check passes.

## Findings (most severe first)

1. **An unresolvable arc reference silently scores against the live set.** Rule 5 refuses a *parse error* because "no arc would silently mean live set" (report:64), but `_resolve_arc_data` also returns `None` for a typo'd `arc_id:` (no file, no id/slug match — `estimator.py:148-171`) and a stale `arc:` tag naming no arc. Those fall to rule 2 → live weights, exactly the silent wrong-set the design promises never to do (report:63). **Fix:** `arc_id:` present-but-unresolvable, or every `arc:` tag naming a nonexistent arc, is a refusal.

2. **check_a keeps the live-file alias table — the same hole the design closes in check_b.** check_a resolves scorability via `est._load_driver_aliases()` (`lib/arc-driver-review.sh:131` → `estimator.py:216-235`, live `POLICY_PATH`). A scoped driver aliased in the arc's set but not the live file passes/fails review opposite to how the set-aware estimator will dispatch it — recreating the silent-drop class point 2 exists to close. The claim "check_a needs no change" (report:92) is incomplete. Same latent hole in the scorability rail (`lib/bvp-scorability.sh:76`). **Fix:** after the loaders take a `policy` argument (report:84), check_a and the rail's `classify` must pass the arc's set.

3. **A skipped task can vanish from the resolver picker with only a terminal WARNING.** The refusal surface (report:78) doesn't say the WARNING's stream or its machine visibility. The picker ranks programmatically (`lib/resolver.py:1378-1395`) and is fail-open by design (`:1380-1383`); a set-refused task drops out of dispatch eligibility with a stderr line no agent reads. The audit check is a periodic backstop, not visibility. **Fix:** specify stderr + a machine signal — rank exits non-zero after printing when N>0 refused (or renders a `refused` row), and the picker records the refusal in its decision log.

4. **The T-2648 split-root lint will FAIL the new code.** The allowlist skips lines containing `value-drivers.yaml` (`agents/audit/audit.sh:2566`); any new `.py` under lib/ or web/ referencing `PROJECT_ROOT / "policy"` with a set filename (`value-drivers-product.yaml` does not contain that substring) is a violation (pattern at `:2556`; the exemption idiom is documented at `lib/resolver.py:1359-1361`). Worse, the "fix" a builder might reach for — FRAMEWORK_ROOT — would be wrong for per-project set files. **Fix:** extend the allowlist to `*value-drivers*.yaml*` with a stated reason, in slice 1.

5. **arc_id-vs-tag divergence and multi-arc roll-ups mix sets.** The ambiguity refusal covers two *tags* only (report:57); `arc_id:` wins over a conflicting tag silently (report:55). And `fw bvp arcs` unions memberships (`lib/bvp.sh:728-753`), so one task can roll up under two arcs computed under two different sets while its own score uses a third choice. **Fix:** refuse when `arc_id:` and tags resolve to different effective sets; define roll-up-vs-task-set semantics for multi-member tasks.

6. **Slice 2→3 window silently drops set-only drivers from ranking.** `compute_bvp` iterates the *weights* map, so a confirmed F-TRUST score contributes nothing until ranking is set-aware (`lib/bvp.sh:285-293`; same shape `lib/resolver.py:1405-1409`). Between slices 2 and 3, estimator proposals and ranking disagree. **Fix:** land 2 and 3 in one window, or reverse their order.

7. **validate_set under-enforces the contract the §3 "No" rows depend on.** §4 checks D1-D4 presence and id/name (report:131), but the judges read the live `note:` field (`lib/bvp_judge.py:214`, `lib/arc_driver_judge.py:316`) — their "No" is only true if notes cannot differ, and nothing checks that. Weight range is also unpinned. **Fix:** validate_set diffs whole D1-D4 entries, allowing only `weight`/`rubric` to differ, and enforces a numeric range.

8. **Minor:** `driver_set:` empty/None unspecified (refusal vs absent, report:59-60); a stray `policy/value-drivers-default.yaml` should WARN (reserved name, report:62); estimator `AGENT.md:13` still documents single-file loading.

**Verdict: sound with fixes** — the architecture, the point-2/3 judgments and the consumer table are accurate against the code, but findings 1-3 must be resolved before build: each is a path where a task silently scores, ranks or dispatches under the wrong set — the exact failure the narrow form exists to prevent.
