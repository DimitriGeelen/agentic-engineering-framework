# Field test of bleeding-edge ed683536a (1.8.9+227) — results

Collected from peer reports (T-4020 rule: only field-verified fixes reach master). A peer's "works" is a claim;
where they quoted a probe or ledger count it is noted. Sources: sidecar conversation `field-test-ed683536a`.

| # | Change | 832-Workflow-designer | dimitri-mint-dev | ring20-dashboard |
|---|---|---|---|---|
| 1 | T-4081 decision revert scan + decide path | PARTIAL: scan 0 reverted / 60 d (also pre-push audit); decide path not exercised | — | verified live (earlier round) |
| 2 | T-4070 Human-tick provenance | not exercised | WORKS: tick on T-094 → ledger row by=watchtower; push passed the Human-tick check | verified live (earlier round) |
| 3 | T-4061 search via POST | WORKS for /search (probe absent from log); Ask/Cmd-K not exercised | — | — |
| 4 | T-4062 secret key 0600 | WORKS (doctor OK) | — | — |
| 5 | T-4052 no auto-redirect | WORKS (30 s on /tasks/T-081) | — | verified live (earlier round) |
| 6 | T-4053/T-4045 review queue split | WORKS (CLI 16/55 = page) | — | — |
| 7 | T-4043/44/46/47 doc title, /file links, AC checkboxes, verbatim Verification | WORKS | PARTIAL (doc title twice → T-4116) | — |
| 8 | T-4041 no localhost:3000 links | WORKS (new code) | — | — |
| 9 | T-4042 MESSAGING_TOOLKIT set once | WORKS | — | — |
| 10 | T-4055 version string | WORKS | issue → T-4107 | — |
| 11 | T-4051/T-4056 hook portability | WORKS | — | — |
| 12 | T-4067 | not exercised | not exercised | — |
| 13 | T-3814 commit allowance | not exercised; flagged over-broad (fixed after ed683536a by T-4108/T-4125) | WORKS | — |
| 14 | T-4058 | not exercised | not exercised | — |
| 15 | T-4059 no HTTP 400 refusals | WORKS (passive) | — | — |
| 16 | T-4069 stale claude-fw WARN | WORKS on a real case | — | — |
| 17 | T-3886 | not exercised | — | — |
| 18 | T-4040 | not exercised | not exercised | — |
| 19 | T-4050 | not exercised | not exercised | — |

832 totals (their correction): WORKS 11, PARTIAL 1, NOT EXERCISED 7, BROKEN 0.

## Findings outside the list

- 832 A: Watchtower currency check blind in vendored consumers → T-4132.
- 832: two consumer tests went stale against intended changes → `docs/releases/v1.8.11-upgrade-notes.md`.
- 832: task pages log 5 "preloaded but not used" font warnings per load; `/favicon.ico` 404 on /search (minor, not filed yet).
- dimitri-mint-dev: Complete on a gate refusal returns HTTP 500 → T-4130.
- ring20-dashboard: claude-fw tmux wrap on a raw console (UTF-8 lines, copy, no lossless detach) → T-4128.

## Live re-check of T-4127 for hotfix v1.8.10 (ring20-dashboard, 2026-10-13, on 650f14b12)

PASS on all three points (their T-2520/T-2521): the operator recorded a NO-GO in Watchtower with an unrelated file
deliberately staged. (1) Watchtower's two commits (264d804c3 decision, be1168e6b decide-chain) contain only the
task file and its episodic — the staged file is in neither. (2) The staged file was still staged afterwards.
(3) An ordinary commit right after (38c301484) carried exactly that file, and the decision stayed at HEAD;
`watchtower_decision_revert.py` → 0. Their verdict: "Fine to ship T-4127 in v1.8.10 from our side."
Note: 650f14b12 includes the T-4127 follow-up (d77e21fe3) that hotfix tip 704c9988f also carries.
