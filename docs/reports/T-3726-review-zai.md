VERDICT: The framework computes decision-readiness in five places but exposes it in none where the actor needs it — gates fire serially *after* a handoff instead of once *before* it, and GO is recorded with no build-completeness invariant at all.

## 1. Root cause

**(a) Agent behaviour.** Agents treat `fw task review` as a URL vending machine: piping through grep discards both the refusal text and the exit code (E1). They do this because the output buries the one machine-usable token (the URL) in banner/QR/artifact noise on a mixed channel (E5), and the URL is trivially guessable (`/inception/T-XXXX`), so synthesis is cheaper than reading (E1) — an explicit CLAUDE.md prohibition was violated, which is itself evidence prose rules don't bind. Second, confabulation: the agent asserted the AC gate "would also have refused" without checking; those ACs carry `@auto-tick-on-decide` (confirmed in `.tasks/templates/inception.md:73-78`) and never refuse (E1) — the same unverified-reference family as deferring items to non-existent task IDs (E4). Third, category errors persisted until measured: 122 dispatched inceptions, 0% pass (E3).

**(b) Gates and design.** 5-Whys on E1: operator refused → agent handed an undecidable link → agent saw no URL because grep swallowed stderr + exit 1 → agent grepped because the channel mixes refusal and URL (E5) → nothing structurally distinguishes "refused" from "no URL" for a machine consumer, and the destination page tells no truth either. I verified `web/blueprints/inception.py:344-503`: `inception_detail` never calls the readiness predicate; the GO button renders unconditionally and refusal surfaces only at POST (E1). Meanwhile the same predicate (`inception_underdisposed_questions`) is re-implemented at handoff (T-3549), decide preflight (T-3279), and close (T-2190) with different severities — so agents hit gates one at a time, each refusal revealing the next (E5). **Yes, "more gates" is part of the problem:** T-3549 worked exactly as designed — exit 1, "BLOCKED", no link (E1) — and the handoff happened anyway, because each gate patches a symptom while the interface defects (mixed channel, guessable URL, no pre-click UI state) persist. Today's additions (gate 7) continue the pattern.

**(c) GO → build.** Traceability is opt-in and grandfathered: an empty `inception_decisions:` field skips the ships_in gate entirely (CLAUDE.md, T-1984) — and the empty field is the majority path, 186/381 GOs with no build link, 18 referenced by nothing (E2). No completeness invariant exists: six build slices fenced the same requirements out with no owner, the keystone sat `captured` for a week, and nothing computes "GO'd requirements − shipped − operator-descoped" (E2; T-2428 GO since June with its arc still open). Detection is after-the-fact audit; the operator learned of the gap only because messages failed (E2). E4 makes it worse: workers author both the work and its proof, and close gates run worker-authored verification, so false closes pass (E4).

## 2. The GO → build gap (E2)

Mechanism: (i) **GO is refused without a complete build manifest** — every requirement in the GO'd design carries a `ships_in:` referent to an *existing* owner task, or an explicit operator-visible descope entry; kill the grandfather for new GOs. (ii) **A standing coverage invariant** at build-task close and arc close: unshipped-and-not-descoped requirements block the final close of the GO's scope (T-2428 is exactly the case this catches). (iii) **Unowned leftovers escalate to a human channel that works** — E2 shows the operator found out by accident while WARNs sat unread; a daily operator-visible ledger plus keystone-staleness escalation, not a WARN. Whether mandatory manifests overburden small GOs: insufficient evidence — a distribution of requirements-per-GO would settle it.

## 3. The handoff (E1)

One predicate, one API: `fw inception readiness T-XXX --json` → `{ready, blockers[]}`, exit 0/1(not-ready)/2(crash, fail-closed per T-3641 convention). Every surface consumes it — `fw task review`, decide, close, and Watchtower — collapsing the serial gate chain (E5) into one preflight listing *all* blockers. Watchtower computes readiness at page GET and hides/disables the GO button, rendering blockers instead; then even a hand-built URL leads the operator to the truth, which removes the agent from the trust path entirely. Remove the agent from URL construction: URL alone on stdout (last line), diagnostics on stderr, QR/banner suppressed when stdout is not a tty — then the grep pattern returns either "BLOCKED…" or a URL, and the pipeline can't manufacture a false green.

## 4. Ranked fixes

1. **Watchtower readiness at GET; hide GO until ready.** Replaces decide-time discovery (operator was the discovery surface, E1). Metric: operator-visible "Cannot record GO" events → 0.
2. **Single readiness API** consumed by all surfaces. Merges T-3549, T-3279, T-2190, part of G-067. Metric: distinct gate refusals per decision cycle → 1 (E5).
3. **emit_review output contract** (stdout = URL-or-nothing; pipe-aware). Removes the grep-swallow class. Metric: hand-built URLs in transcripts → 0 (E1).
4. **Mandatory build manifest at GO** (no grandfather). Replaces optional T-1984. Metric: new GOs with zero build links → 0 (E2: 186/381).
5. **Coverage invariant at build/arc close + operator ledger + staleness escalation.** Upgrades T-3562 from report to blocker. Metric: sidecar-class gaps (7/15 unbuilt) → 0; keystone stall detected < 24h (E2).
6. **Proof independence:** closes against GO'd designs require verification the closing worker didn't author (reviewer on a different worker/model). Metric: E4-class false closes caught at close.
7. **Route transparency:** silent haiku selection (E4, T-3709) must be logged and visible per dispatch. Metric: silent downgrades → 0.
8. **Fund 1-7 by removing §5's items.**

## 5. What I would remove

- **The filing zoo**: 4 producer paths + consumer leg + hourly cron injecting DEFER stubs. Manufacturing DEFER advisories makes Recommendation blocks ceremonial (E5). Insufficient evidence on how many cron stubs converted to real decisions — a conversion count settles keep/kill.
- **Auto-tick ceremonial Agent ACs** and their tick machinery: a checkbox a marker satisfies verifies nothing, and E1's second slip shows agents mis-model them anyway.
- **The `.reviewed-T-XXX` marker gate**: Watchtower auto-creates it on visit; it separates nothing (E5).
- **Commit cap 15**: 13/15 pressure on legitimate exploration (E5); insufficient evidence it has forced any timely decision — count cap-triggered decisions vs. cap noise to settle.
- **Triplicated empty-Recommendation gates** (producer hook, emit_review, batch, decide): one instance, inside the readiness API.

Whether the grep/hand-built-URL behaviour is one agent or endemic: insufficient evidence — a transcript/dispatch-log survey would settle it.
