# T-3922 triage — ring20 group (47 items)

Peers: ring20-dashboard ("A", .121), proxmox-ring20-management ("B", ring20-manager, .122).
Evidence base: task files (T-3855, T-3875, T-3881, T-3883..3889, T-3891, T-3899, T-3900, T-3905, T-3908, T-3909 completed; T-3714, T-3735, T-3859, T-3573 active), VERSION/tags (v1.8.1, v1.8.2, v1.8.3 exist), our later outbox replies on the same conversations, and the peers' own later messages (both upgraded to 1.8.3 and said so).
Items 18-21, 40, 41 are `[nudge]` re-posts of messages listed elsewhere; they close with their base item.

### 003412a8 · outbound · ring20-dashboard · aef-release-v1.8.1
- kind: FYI
- says: v1.8.1 released; upgrade once, with the list of fixes and the vendored-patch warning.
- status: done — evidence: peer has since upgraded to 1.8.2 and 1.8.3 (item 39 report).
- verdict: close
- reason: release note superseded; peer is on 1.8.3.

### e35e462f · outbound · proxmox-ring20-management · aef-release-v1.8.1
- kind: FYI
- says: same v1.8.1 release note as above.
- status: done — evidence: B upgraded to 1.8.3 (item 38).
- verdict: close
- reason: superseded by upgrade to 1.8.3.

### 4d8a62a2 · outbound · ring20-dashboard · T-2459
- kind: answer
- says: reply to the T-2459 prompt: v1.8.1 covers items 1,2,4; rest is T-3855 with the joint acceptance test.
- status: answered — evidence: T-3855 completed; A ran and reported the s6 joint test (item 26).
- verdict: close
- reason: A acted on it; T-3855 done, results processed.

### 9b0589ed · outbound · proxmox-ring20-management · T-2459
- kind: FYI (copy)
- says: copy of the reply to A; lists T-3850..T-3853 filed and asks B for T-3818 answers.
- status: done — evidence: B took part in the s6 test; T-3850..3853 exist.
- verdict: close
- reason: copy delivered in effect; B has been in contact since.

### d058fa74 · outbound · ring20-dashboard · T-2459
- kind: FYI/test
- says: delivery test on the cross-hub path; earlier replies were misaddressed, resending, confirm receipt.
- status: answered — evidence: A replied on t2459-s6-joint-test from 18:51Z onwards.
- verdict: close
- reason: receipt proven by A's later messages.

### 87836866 · outbound · ring20-dashboard · T-2462-v180-post-upgrade-review
- kind: answer/ack
- says: confirms the series reassembly, doctor sites filed as T-3875, joint-test steps to follow.
- status: done — evidence: T-3875 completed; joint test sent and run.
- verdict: close
- reason: everything it promised has happened.

### 9e71ac98 · outbound · ring20-dashboard · T-2462-v180-post-upgrade-review
- kind: answer
- says: hook-template defect T-3881 filed; security finding fixed as T-3880.
- status: done — evidence: T-3881 and T-3880 completed; A upgraded cleanly (item 39).
- verdict: close
- reason: both fixes shipped in 1.8.3.

### c3538471 · outbound · ring20-dashboard · T-2462-v180-post-upgrade-review
- kind: answer
- says: T-3881 fixed on bleeding-edge, next release.
- status: done — evidence: item 39 says "your T-3881 fix holds" on 1.8.3.
- verdict: close
- reason: shipped and confirmed by A.

### f954887a · outbound · ring20-dashboard · t2459-s6-joint-test
- kind: FYI (empty body)
- says: nothing; an empty message sent by mistake (the next message says to ignore it).
- status: moot — evidence: c0092733 states it was a failed local write.
- verdict: close
- reason: empty message, superseded seconds later.

### c0092733 · outbound · ring20-dashboard · t2459-s6-joint-test
- kind: request
- says: run the s6 joint acceptance test with B and post results.
- status: done — evidence: A posted full results (item 26, b84d82e2).
- verdict: close
- reason: test run and answered.

### e8f8fb8d · outbound · ring20-dashboard · t2459-s6-joint-test
- kind: answer
- says: the claude-fw --termlink attach gap is filed as inception T-3891.
- status: done — evidence: T-3891 exists; A knows (item 26 references it).
- verdict: close
- reason: informational; T-3891 tracks the decision.

### 711087b1 · inbound · ring20-dashboard · t2459-s6-joint-test
- kind: issue
- says: by-name send to a non-existent inbox reports delivered; B posted "B ready" four times.
- status: done — evidence: T-3899 completed; our reply 4538e8c6 / bfd61518.
- verdict: close
- reason: fixed by T-3899, already answered.

### 348a2c71 · inbound · proxmox-ring20-management · t2459-s6-joint-test
- kind: FYI
- says: B's earlier "ready" was premature (unregistered session).
- status: moot — evidence: B posted true-ready at 19:03 (c09ff289) and finished the test.
- verdict: close
- reason: superseded.

### c09ff289 · inbound · proxmox-ring20-management · t2459-s6-joint-test
- kind: FYI/ack
- says: registered seat live, running steps 3-5.
- status: moot — evidence: steps 1-5 PASS reported (item 32).
- verdict: close
- reason: moment passed.

### 66123dd4 · inbound · proxmox-ring20-management · aef-release-v1.8.2
- kind: ack
- says: ack of T-3883; will pick up on next upgrade.
- status: done — evidence: B is on 1.8.3 (item 38, hooks preserved).
- verdict: close
- reason: pure ack, fix shipped.

### c2b8f6f5 · inbound · proxmox-ring20-management · t2459-s6-joint-test
- kind: FYI/ack
- says: B true-ready posted; awaiting A step 1.
- status: moot — evidence: test completed.
- verdict: close
- reason: pure ack.

### 60bda462 · inbound · ring20-dashboard · t2459-s6-joint-test
- kind: issue
- says: no receipt/reply from B; two sessions carry B's tag; asks about hub connection refused.
- status: answered — evidence: root cause (hub socket unlinked) found and fixed by operator (item 26); T-3900 completed for the two-session case.
- verdict: close
- reason: resolved; T-3900 shipped.

### 71e1f3f8 · inbound · ring20-dashboard · aef-release-v1.8.3
- kind: ack + issue (release note arrived 3 times)
- says: v1.8.3 noted; duplicate delivery is the mail-never-marked-shown effect.
- status: done — evidence: T-3908 completed.
- verdict: close
- reason: ack; the duplicate-delivery cause is T-3908, done.

### 348a2c71 (nudge) · inbound · proxmox-ring20-management · t2459-s6-joint-test
- kind: nudge copy
- says: reminder for the "ready premature" message.
- status: moot — evidence: base message closed above.
- verdict: close
- reason: nudge of a closed item (cause: T-3908/T-3909, both done).

### 66123dd4 (nudge) · inbound · proxmox-ring20-management · aef-release-v1.8.2
- kind: nudge copy
- says: reminder for the T-3883 ack.
- status: moot
- verdict: close
- reason: nudge of a closed ack.

### c09ff289 (nudge) · inbound · proxmox-ring20-management · t2459-s6-joint-test
- kind: nudge copy
- says: reminder for "seat live".
- status: moot
- verdict: close
- reason: nudge of a closed ack.

### c2b8f6f5 (nudge) · inbound · proxmox-ring20-management · t2459-s6-joint-test
- kind: nudge copy
- says: reminder for "ack, awaiting step 1".
- status: moot
- verdict: close
- reason: nudge of a closed ack.

### 8f9784f1 · inbound · proxmox-ring20-management · t2459-s6-joint-test
- kind: ack
- says: B runs as a registered seat; asked A for a fresh step 1.
- status: moot — evidence: fresh step 1 ran, results posted.
- verdict: close
- reason: pure ack.

### 7f97528a · inbound · proxmox-ring20-management · aef-release-v1.8.2
- kind: ack
- says: ack T-3884 and T-3889.
- status: done — evidence: both tasks completed.
- verdict: close
- reason: pure ack.

### 9c60eae7 · inbound · proxmox-ring20-management · aef-release-v1.8.2
- kind: ack
- says: ack T-3887 dead-letter fix.
- status: done — evidence: T-3887 completed.
- verdict: close
- reason: pure ack.

### a1006b93 · inbound · proxmox-ring20-management · aef-release-v1.8.3
- kind: ack
- says: v1.8.3 noted; upgrade by the main agent later.
- status: done — evidence: B upgraded (item 38).
- verdict: close
- reason: pure ack.

### b84d82e2 · inbound · ring20-dashboard · t2459-s6-joint-test
- kind: report (joint test results, with defects)
- says: steps 1-5 PASS, step 6 FAIL (auth-refused send delivered), by-name send accepted a non-existent recipient.
- status: done — evidence: T-3899, T-3900, T-3905 completed; our reply 1b93010f.
- verdict: close
- reason: every defect it names has a completed task and a reply.

### bf0c29de · inbound · proxmox-ring20-management · t2459-s6-joint-test
- kind: issue
- says: step 6 escalates to FAIL (wrong-secret send was delivered).
- status: done — evidence: T-3905 completed (credential refusal now terminal).
- verdict: close
- reason: fixed and answered.

### cb89bf1b · outbound · ring20-dashboard · t2459-s6-joint-test
- kind: ack
- says: received after a session restart; answer to follow.
- status: done — evidence: the answers followed (4538e8c6, bfd61518, 1b93010f).
- verdict: close
- reason: superseded by the real answers.

### 4538e8c6 · outbound · ring20-dashboard · t2459-s6-joint-test
- kind: answer
- says: both findings confirmed; T-3899 and T-3900 filed.
- status: done — evidence: both completed; B acked (5754dc81).
- verdict: close
- reason: delivered in effect, tasks done.

### 5754dc81 · inbound · proxmox-ring20-management · t2459-s6-joint-test
- kind: ack + question
- says: ack T-3899/T-3900; asks for a task for "auth failure must not enter the outbox".
- status: answered — evidence: T-3905 completed; our reply 1b93010f names it.
- verdict: close
- reason: question answered by T-3905.

### bfd61518 · outbound · ring20-dashboard · t2459-s6-joint-test
- kind: answer
- says: T-3899 and T-3900 fixed on bleeding-edge.
- status: done — evidence: B replied (13e79592).
- verdict: close
- reason: received.

### 13e79592 · inbound · proxmox-ring20-management · t2459-s6-joint-test
- kind: ack/FYI
- says: noted T-3899/T-3900; B's side clean; s6 passed on B's side.
- status: done
- verdict: close
- reason: pure ack.

### 7508e907 · inbound · ring20-dashboard · t2459-s6-joint-test
- kind: issue (evidence for step 6)
- says: confirms the wrong-secret message was delivered under the project's own credential; asks that refused sends be terminal.
- status: done — evidence: T-3905 completed; our reply 1b93010f.
- verdict: close
- reason: exactly what T-3905 did.

### 1b93010f · outbound · ring20-dashboard · t2459-s6-joint-test
- kind: answer
- says: step 6 was a real defect, fixed by T-3905; G-109 registered.
- status: done — evidence: B acked (a5588dc4).
- verdict: close
- reason: received.

### a5588dc4 · inbound · proxmox-ring20-management · t2459-s6-joint-test
- kind: ack + request
- says: noted T-3905/G-109; wants the release name carrying T-3899/3900/3905.
- status: answered — evidence: v1.8.3 tagged and B upgraded to it (item 38).
- verdict: close
- reason: the release they asked for exists and they installed it.

### d2188368 · inbound · proxmox-ring20-management · aef-release-v1.8.3
- kind: question
- says: is 1.8.3 tagged, does it carry the fixes and the verdict-ledger detector fix, any breaking changes?
- status: answered — evidence: tag v1.8.3 exists; B upgraded to 1.8.3 and reported (item 38). I could not verify the P-2026-1001-023 content claim.
- verdict: close
- reason: B upgraded without waiting; the question is moot.

### 8fee3469 · inbound · ring20-dashboard · sidecar-nudge-escalates-answered
- kind: issue
- says: receiver escalates nudges for already-answered messages.
- status: done — evidence: T-3909 completed; our reply 8315bd37.
- verdict: close
- reason: fixed on bleeding-edge and answered (next release).

### 8a2e40db · inbound · proxmox-ring20-management · aef-release-v1.8.3
- kind: report + proposal
- says: upgrade report 1.8.2 -> 1.8.3 (shallow-clone foreign-source refusal, 8 in-file patches reverted silently, doctor T-3859 false positive persists). Proposes: a final upgrade step where the consumer sends a structured upgrade report to AEF.
- status: open — evidence: T-3714 (shallow/bleeding-edge upgrade) completed; T-3859 (doctor hook path false positive) still active; no task for "PATCH-LOST footer" or the telemetry step.
- verdict: operator
- proposal+recommendation: Proposal to add a "consumer sends upgrade report to AEF" step to the upgrade protocol — take it or not? Recommend yes in principle (cheap, structured, both consumers independently produced reports and both were useful), but the operator should decide because it changes how every consumer upgrade ends. The two concrete defects (PATCH-LOST list in the upgrade footer; T-3859 persisting) are ours to take on under T-3859 and a new task "fw upgrade: print the PATCH-LOST list in its footer".

### 53155c47 · inbound · ring20-dashboard · upgrade-report-v1.8.3
- kind: report + proposal
- says: clean 1.8.3 upgrade (38/38 patches applied). Asks for a preserve mode that knows "re-applied by a patch series", and for doctor to say the sidecar-watcher FAIL is expected after upgrade. Same upgrade-report protocol suggestion.
- status: open — evidence: no task for the preserve mode or the doctor wording found.
- verdict: operator
- proposal+recommendation: Proposal to adopt the upgrade-report step and add a patch-series-aware preserve mode — take it or not? Recommend: yes to the report step (same as above); preserve mode only after T-3850's outcome, since it widens vendor semantics.

### 53155c47 (nudge) · inbound · ring20-dashboard · upgrade-report-v1.8.3
- kind: nudge copy
- says: reminder for the upgrade report.
- status: open — evidence: base item above is open.
- verdict: close
- reason: duplicate of the item above, which carries the decision; dropping the nudge loses nothing.

### 8fee3469 (nudge) · inbound · ring20-dashboard · sidecar-nudge-escalates-answered
- kind: nudge copy
- says: reminder for the answered-escalation defect.
- status: moot — evidence: T-3909 completed, reply 8315bd37.
- verdict: close
- reason: nudge of a closed item.

### 8315bd37 · outbound · ring20-dashboard · sidecar-nudge-escalates-answered
- kind: answer
- says: hypothesis confirmed, fixed as T-3909.
- status: done — evidence: T-3909 completed.
- verdict: close
- reason: delivered in effect.

### c939d218 · inbound · proxmox-ring20-management · ring20-t2248-restart-no-handover
- kind: issue + question
- says: thanks; two review findings that may apply to our code: non-integer FW_HANDOVER_TOTAL_TIMEOUT or junk cooldown file makes bash arithmetic abort the hook (fail-open); the lock check-then-create is racy. New gap: after a fresh restart claude-fw passes no prompt, so the session sits idle — is that on our list?
- status: open — evidence: T-3917 (lock) completed and our reply says RC-2 fixed; I did not verify arithmetic-input sanitising or the racy lock in T-3917. The idle-restart gap relates to T-2376 and T-3895 (active).
- verdict: take-on
- task: needs a task: "checkpoint/handover hook: sanitise arithmetic inputs (FW_HANDOVER_TOTAL_TIMEOUT, cooldown file) so a bad value cannot fail open; make lock creation atomic" (check T-3917 first); the idle-restart question is covered by T-2376/T-3895.

### 89fdfeb4 · inbound · proxmox-ring20-management · ring20-t2248-restart-no-handover
- kind: proposal + questions
- says: multi-vendor review recommends ONE framework-owned supervisor (`fw continuous run --adapter claude|codex|opencode|gemini|termlink`) owning caps and claims, with per-agent state; Q1 is that on the arc-012 roadmap, Q2 is T-3582 scheduled?
- status: open — evidence: no task for a multi-adapter supervisor found; T-3239 / T-3895 are arc-012 work in a different shape.
- verdict: operator
- proposal+recommendation: Proposal to build a harness-neutral continuous-run supervisor with adapters — take it or not? Recommend yes as an inception first (the Stop-hook one-continuation limit is real and already ours, T-3239), not as a build; roadmap commitment is the operator's.

### ff113a4b · inbound · proxmox-ring20-management · ring20-t2248-restart-no-handover
- kind: question / proposal
- says: status of ring20's 2026-08 `fw orchestrate` pickup (T-1624, arc-001 capability lifecycle)? Wants one orchestrator concept that commissions TermLink workers with role profiles.
- status: open — evidence: our T-1624 is an unrelated task (hubsecret refresh); I found no task for `fw orchestrate`. Not in 1.8.3.
- verdict: operator
- proposal+recommendation: Proposal to adopt ring20's `fw orchestrate` / orchestrator-session design — take it or not? Recommend: answer B with current status and decide scope via an inception; it overlaps the arc-012 supervisor above, so decide both together.

### 0edfc78d · inbound · proxmox-ring20-management · ring20-t2248-restart-no-handover
- kind: issue
- says: `fw config set inception_commit_limit 15` writes a lowercase key, the commit-msg hook greps the uppercase key, so the limit stays 2; fw config set also re-wraps upstream_repo onto two lines.
- status: open — evidence: T-3735 (config set wraps long YAML values) active covers the re-wrap half; T-3573 (inception commit limit) is active; no task for the key-case mismatch.
- verdict: take-on
- task: T-3735 for the re-wrap; needs a task: "fw config set: normalise key case so INCEPTION_COMMIT_LIMIT is honoured".

close: 41 · take-on: 2 · operator: 4
