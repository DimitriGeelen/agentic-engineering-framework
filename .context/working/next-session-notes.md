# Next session: carry-over

## FIRST (2026-11-11 ~10:40Z) — read this block first
- node1 run (T-5073) PAUSED on ring20's health alarm; resume ONLY after proxmox-ring20-management says green.
  Then: collect the 2 orphaned results (names in .context/scratch/node1-jobs/A2-uncollected-names.txt), send the
  192 left (.context/scratch/node1-jobs/listA3.txt) with the scratchpad driver pattern: entries aef2.bats/aef2.pytest,
  env aef-unit-2, bundle sha e2acf490... (590b7d0bf), names aef-t5073-*. The driver script lived in the session
  scratchpad and will be gone: rebuild it from spec section 8/9 (submit-cmd + wait, batches of 16, stop on a batch with
  no accepted submission or no unit.log; submit log OUTSIDE the job folder).
- Interim result in spec section 9 + docs/reports/T-5073-node1-compare-590b.tsv: 29 files fail ONLY on node1 (sandbox
  differences: read-only /, open-file limit, playwright missing, excluded handovers, no systemd/tmux/termlink, cron,
  2 timeouts); 13 still need their cause read. Then decide per class (local-only list / ask ring20 / fix test).
- GitHub issues (arc-021), operator said go: #104 DONE (T-4361 closed, released stage posted). Next: #102 T-4359,
  #103 T-4360, #98 T-4355 (re-run `fw issues release v1.8.15 --range v1.8.14..v1.8.15` after each closes; operator:
  "post what is ready"). Roadmap blockers for the operator: GitHub branch rules (1.2), T-5021 sign-off, T-5009 Q-3.
- Closed since the last block: T-5072 (receiver start limit, proven on node1), T-5074 (designer 0.41.0), T-4361.
  832: field-profile/field-suggestions not planned (T-4737). 010: told about Watchtower's secret form and its limits.

## Earlier FIRST (2026-11-10; latest be.45; node1 bulk run IN FLIGHT)
- node1 now runs AEF unit tests (operator yes 2026-11-09). Spec + contract + trial: docs/reports/T-5069-node1-unit-suite-spec.md
  (sections 1-8). Package: `bin/fw test bundle` (T-5070) -> .context/scratch/node1-bundles/ (the folder ring20's relay
  copies from). Client: /usr/local/bin/pool-client (root-owned, sha256 pinned in spec), POOL hub = ring20 relay :9100,
  state .context/scratch/node1-pool-state. Entries aef.bats / aef.pytest, env aef-unit-1, --ref repo.bundle=<sha>.
- T-5073 bulk run IN FLIGHT on bundle of 590b7d0bf (sha e2acf490..., carries T-5072): driver
  scratchpad node1_bulk.sh (one-off, NOT in repo): first .context/scratch/node1-jobs/listBC.txt (63, names aef-t5073r-*),
  then listA.txt (1,488, names aef-t5073-*); results .context/scratch/node1-results/run-590b-{BC,A}/summary.tsv(.part)
  + progress.log. 32 earlier successes in .../bulk-6a945030-r2 (old bundle). Job names are single-use keys.
  When done: compare (scratchpad node1_compare.sh: re-runs each node1 failure here), write spec section 9, tell ring20,
  close T-5073; then close T-5072 (its AC4: the 14 receiver files ran on node1 with the fix).
- Incidents: node1 isolation was NOT in place until 2026-11-10 16:17Z (PrivateNetwork ignored in the Incus container);
  ring20 fixed it with per-job netns, proven by effect. AEF exposure checked: bundle = git-tracked files of a public
  commit, no secrets. 44 jobs had "no result file" from ring20's first netns rollout (08:41Z), not our suite.
- Closed this stretch: T-5063, T-5061, T-5060, T-5064, T-5065, T-5062, T-5069, T-5070, T-5071; partial-complete
  (operator check, GO): T-5067 (27 pid-only temp names; lint at pre-push), T-5068 (worker timeout 600 -> 3600 s,
  measured; WARN on watchdog kill). T-5072 (receiver start wait FW_SIDECAR_RECEIVER_START_S, default 30 s) committed,
  open for its node1 AC.
- Waiting on operator: T-5066 inception (GO narrow), reviews T-5067 / T-5068 (links via bin/fw operator pending).
- Next after node1: link node1 results into the nightly unit-suite report (pre-push + audit read
  .context/audits/unit-suite/LATEST.yaml); result format is in spec section 7.

## Earlier FIRST (2026-11-08/09; latest be.44 = 9408fdc5b; shutdown CALLED OFF)
- Host shutdown called off by the operator ("not planning to reboot near time soon"); all 9 agents that replied
  were told. 1409's 913 commits are on OneDev (operator pushed via runme, --no-verify, after a NAS bundle).
- Closed: T-5063 (escalation-scan YAML quoting, unblocked pre-push), T-5061 (183 GB log: RCA, writer never
  localised; plus fw doctor CONTEXT_DIR abort fixed, be.41), T-5060 (claude-fw records signal-hup/term end reason,
  --help, FRAMEWORK.md Launch Modes, be.42; 055 will report after upgrade), T-5064 (issue #98 follow-up, be.43,
  reply posted on GitHub, awaiting submitter), T-5065 (designer 0.40.0 pinned and served; 832 T-1385), T-5062
  (mirror log bounded, 7.9 MB -> 0.3 MB; 90 differing OneDev tags = same commits, tag objects only, leave).
- OPEN for the operator: T-5066 inception (remote capacity / node1, recommendation GO narrow)
  http://192.168.10.107:3000/inception/T-5066 — after GO: build tasks for (a) pattern doc, (b) 24 pid-only temp
  names, (c) TERMLINK_WORKER_TIMEOUT 600 s. Tell 1409 the decision (conversation remote-nodes-node1-writeup).
  Keep IPs and the jump account masked in anything committed (1409 asked; operator: leave old history).
- Waiting on field reports: dimitri-mint-dev (be.41, T-5061), 055 (be.42, T-5060), issue #98 submitter (be.43).
- T-5054 stays parked: needs 010's revised adapter contract and an operator decision.
- No planned agent work left; operator queue: bin/fw operator pending (2 GO inceptions: T-4299, T-4371).

## Earlier FIRST (2026-11-07; HOST SHUTDOWN PREP; latest be.40 = 1571b30cd)
- The operator asked to prepare THIS host for shutdown. 14 local agents were asked (sidecar, conversation
  host-shutdown-2026-11-07, urgent) to commit, push, write handovers and reply 'READY <project>'. Check their
  replies first after restart; anything not pushed is in those replies.
- Shipped 2026-11-03..07: T-5052, T-5053, T-5050, T-5049, T-5015 (designer 0.38.0), T-5057 (0.39.0), T-5056,
  T-5055, T-5039, T-5059, T-5061 code (be.31..be.40). 050 confirmed T-5051/5052/5053 WORKS.
- T-5061 (G-130, 183 GB log on the Greenfield laptop): code done in be.40 (separate capture, caps, doctor/audit
  oversize check); task OPEN for the RCA: the unbounded writer was never localised (tail bounded on GNU and uutils,
  shape replay bounded on both). Close it with the RCA saying so, or with the cause if the laptop shows it again.
- T-5058 partial-complete: operator looks at designer Check, http://192.168.10.107:3000/review/T-5058
- T-5009: phase 3 built (fw testhost, stub); waits on operator Q-3 (hypervisor node). Design note section 8a: B.
- Next, in order: T-5060 (log why a wrapped session ended; wrap vs --termlink docs; 055 waits), issue #98
  follow-up (embed endpoint WARN with SEMANTIC_RECALL=0), T-5062 (.mirror-sync.log unbounded), T-5054 (backlog).
- Roadmap: first pre-release target 2026-11-10 is likely not provable (field proof thin beyond 050); propose a new
  date to the operator rather than cut unproven.

## Earlier FIRST, update (2026-11-03 ~14:00Z; latest be.30 = 3f3f5d9f1)
- Shipped since the noon handover: T-5051 (HANDOVER_PUSH=0 opt-out, be.29; 050 WORKS; partial-complete, operator
  review of the config row http://192.168.10.107:3000/review/T-5051), T-5048 (no colour codes in files/pipes/NO_COLOR,
  be.30, closed; ring20-dashboard told).
- Next, in order: T-5052 (handover says "committed locally" even when its commit failed; force-add the handover file
  under a gitignored .context/ — 050 waits), T-5049 (audit alarm 1.4), T-5009 (isolated test hosts), T-5015
  (designer: pin 0.38.0 directly; hashes in the task), T-5053 (Gaps Register KeyError on title-less concerns),
  T-5050 (upgrade backfill vs CTL-030 deadlock, 003 waits).

## FIRST (2026-11-03 ~12:00Z; latest be.28 = 8c677b8a0; GitHub IS NOW origin)
- **NOTHING LEAVES RING20** (operator, furious, 2026-11-02): never the Artifact tool / Claude Docs / any outside
  service for project content; PDF/Word = pandoc + soffice locally. Memory: feedback_nothing_leaves_ring20.md.
  Pronouns: Mehdi = they/them or by name (slipped repeatedly on 2026-11-02).
- **Remote switch done (T-5044):** `origin` = GitHub, `onedev` = mirror (fw mirror sync, now also bleeding-edge).
  OneDev's force-push job has no triggers. Open in T-5044: operator's GitHub branch rules (no force push/deletion on
  bleeding-edge and master) and other clones elsewhere.
- **Arc github-contributions (arc-027):** roadmap with status + dates `docs/reports/T-5006-roadmap.md`. Done today:
  T-5045 (GitHub PR checks green), T-5047 (CONTRIBUTING/PR template/SECURITY), tracking issue #114 (pinned, mentions
  @MikeEchoVoid). Next: T-5049 (audit alarm 1.4), then T-5009 (isolated test hosts; blocks Mehdi's code PRs).
- **Role chain:** step 1 (T-5021) done, 3 review rounds; awaits operator sign-off
  http://192.168.10.107:3000/review/T-5021 (sign-off list in requirements §14). Steps 2-8 = T-5022..T-5028.
  Role-chain inputs (ring20 protocol, 9 cards, driver) stored in docs/reports/T-5006-inputs/role-chain/.
  T-3935 = embed the chain as template arc (010 + ring20 + 1409 input recorded).
- **Shipped yesterday:** be.26 T-5008 (seat PID namespace; residual: seat user, open), be.27 T-5014 (main-session
  lease, live here; 010/ring20/050 confirmed). T-5014 open: SessionEnd release hook (operator wiring), upgrade hint.
- **New tasks from peers (2026-11-02/03):** T-5010..T-5013 Watchtower, T-5015 designer 0.37.0 re-pin, T-5016 Anchor
  (inception), T-5017..T-5020 sidecar receiver, T-5031..T-5034 access-grant self-grant (G-129 high), T-5035 ring20
  bvp patches (text in docs/reports/T-5035-inputs/), T-5036 space-in-path grants, T-5037 batch verification
  (inception), T-5038 orphan inbox fan-out, T-5039/T-5040 read-only allowlist + reviewer report path, T-5041 release
  channels (inception, operator set the model), T-5042 seats cannot render Mermaid, T-5043/T-5046 paid seat path,
  T-5048 bin/fw colour codes.

## EARLIER (2026-11-02 ~00:30Z, ~760K used, all work pushed; latest be.24 = be290e092)
- **Closed tonight:**
  - T-4977 (designer 0.35.0, be.16);
  - T-4976 (fixture leak plus lint);
  - T-4970 (no whoami fallback; 832 confirmed, G-125 resolved);
  - T-4979 (ledger audit states its exit contract);
  - T-4978 (page criteria keep blind seats out; seats run project code from a copy; voids name the changed files);
  - T-4983 (boundary: a variable assigning an outside path is refused; G-126 resolved);
  - T-4967 (driver-sets design, two reviews);
  - T-4988 + T-4989 (access grants, be.20; 050 field WORKS);
  - T-4984, T-4985 (driver sets slices 1-2);
  - T-4993 (fw runs without HOME, be.22);
  - T-4999 (review seats get PROJECT_ROOT = their export; G-127 high, mitigated; be.24).
- **Partial-complete, operator review:**
  - T-4986 (driver sets slice 3, /bvp) http://192.168.10.107:3000/review/T-4986;
  - T-4996 (REVIEW_PAID_BACKENDS=never; config page row) http://192.168.10.107:3000/review/T-4996.
- **Operator rulings tonight:**
  - T-4965 GO (reduced access-grants layer);
  - T-4371 IW-4: "If it's for the agent, if it's for the human, it's for the human." owner:human = the operator closes it; no hand-back from a recorded decision. 010 told.
- **Next work, in order:**
  1. T-4997 (antigravity seat: headless mode auto-denies 'command'). ring20's rung-5 page criteria need it or T-4980. Localising means reading agy's settings for the seat user (another account's home) and is probably a HOST change: hand the operator a runme.
  2. T-5004 (read-only sed -n/awk/for/python3 -c on .tasks/* treated as writes).
  3. T-5002, T-5003, T-5005 (gate friction from 010's closers).
  4. T-4995 (grant refusal names the rule).
  5. T-4994 (review.sh go|no-go|defer pipe).
  6. T-5001 (void a seat that wrote outside its export).
  7. T-4987 (driver-sets rails).
  8. T-4990 (grants Watchtower view).
- **Inceptions for the operator (DEFER):**
  - T-4991 (832 workflow-design vocabulary; SHACL);
  - T-4992 (ring20-management harness login broker; their wrong-account weakness recorded);
  - T-4998 (backlog triage: 055 and 010 pages, 010's 23% not-done-on-second-look, "no honest non-completed ending");
  - T-4982 (055 scoring findings);
  - T-5000 (claude review seat runs in the live project).
- **Waiting on field reports:**
  - 010 (driver sets be.21: product arcs);
  - ring20 (be.23 + be.24 upgrade; REVIEW_PAID_BACKENDS=never; T-878 dry run);
  - 050 (be.22 HOME fix).
  - Record each under T-4940 in docs/reports/field-test-v1.8.16-results.md.
- **Still open for the operator:** the green-button question (task title/description render as buttons since T-430).
- **After the handover:** T-4994 done (be.25: review hint placeholder is `DECISION`, no pipe; 050 told). `tests/integration/audit_blocks_review_and_decide.bats` "fw inception decide: blocks when placeholder present" fails with or without T-4994 (pre-existing; likely the CLAUDECODE agent refusal firing first). Worth a look.
- **Slips to remember:**
  - I typed the Tier 0 keyword inside a grep (refused; a stray approval card may exist). Use 'Tier 0' or the check-tier[0] glob.
  - I ran `fw inception decide` on a fake id to test its validation. It is operator-only: refused, and possibly a stray card. Prove by reading code instead.
  - I ran `git stash -- <path>` when the path had no changes. It stashed nothing, and the next `pop` tried an OLD unrelated stash (the pop aborted, nothing applied). Never stash a path without checking it has changes.
- **Lessons:**
  - (1) Test the probe environment too: the runtime's `--version` call runs a stub with the live env, and a gate-like TMPDIR exposed it.
  - (2) A grep-by-filename test sweep misses tree-scanning tests (the split-root ratchet broke silently).
  - (3) Review dispatched builds against field reality (a stale `arc:` tag unranked 4 tasks).

## EARLIER (2026-11-01 ~17:30Z, 762K used, all work pushed; be.15 = 0522186b9)
- **Closed this afternoon:** T-4947 (green), T-4952, T-4953 (read-only pipe: refused, no card; operator option 1 after codex/opencode consult), T-4958 (ux shots crop), T-4959, T-4960 (judge tall pages), T-4962, T-4963 (sidecar ladder, 055), T-4964 (t4920 test leaked a live card), T-4944 (vision-gated render greens), T-4966 (ledger lock; WORKS at ring20), T-4968, T-4969 (operator owner hand-over: one gate, three doors, 'claimed' log; external design review + code review), T-4971, T-4972, T-4974 (basename lint), T-4975 (links in role=button fields).
- **Waiting on the operator (runmes):** `t4973-fix-t4679-name` (escape T-4679's closed name; then close T-4973), `t4976-stop-leaked-fixtures` (51 leaked foreign_watchtower.py servers). Watch both logs; close T-4973 after.
- **Next work, in order:** T-4978 (LOCALISED with ring20's data: [REVIEW] criteria that describe what a page shows classify as taste/unclassified, so the judge captures no screenshots and the vision gate never fires; decide classifier vs "names a route → capture"; defect 2: opencode exit 1 = T-3986 tamper check tripped by `__pycache__`), T-4976 (fixture teardown), T-4977 (designer 0.35.0 re-pin, validator changed; tell 832), T-4970 (no whoami fallback), T-4979 (audit exit on void rows), T-4967 (driver-sets design read, TermLink), T-4965 (scoped grants design + external review; 050's decisions in the report).
- **Operator question open:** task title/description render as green buttons since T-430 (role=button) — plain text or keep? (T-4975 fixed only the links.)
- **Inceptions waiting on operator:** T-4371 now holds IW-4 (general ownership rule table; codex's question: does owner:human mean mandatory sign-off?). T-4965 DEFER until design + review.
- **Field record:** be.14 is commit b82af92fe (NOT 5aa42c6ec, that was the tag object; read tags with ^{commit}). Recorded: 055 be.14 WORKS, T-4962 WORKS; ring20 be.10, be.15 WORKS, T-4966 WORKS.
- **Lessons:** sweep for the fixture shape, not one assertion's wording (T-4971); `fw vendor self` withholds uncommitted files: commit source, then vendor; a bats `! cmd` that isn't last never fails (`|| false`).

## EARLIER (2026-11-01 ~10:50Z, session ending near Amber, all work pushed)
- **Push block cleared, no baseline re-arm needed.** 9 expired baseline reds fixed: T-4947 (/approvals raw stderr), T-4948 (atomic YAML writers), T-4949 (FW_ALLOW_EMPTY_RECOMMENDATION restored), T-4950 (split-root ratchet), T-4951 (SystemExit on missing BVP policy). Plus T-4954 (my T-4921 template change broke a T-2743 test), T-4955 (retire_when fixture), T-4956 (`regenerate` emptied the baseline from a one-tier report; fixed). Baseline now 25 entries; 16 of their 17 files pass directly (drop at their tier's next run); `doctor_hook_counters.bats` still 3 reds (T-3615). The re-arm runme `.context/runme/t4946-rearm-baseline` must NOT be run (operator told).
- **T-4947 open (partial):** code done, Watchtower restarted; its [REVIEW] render criterion came back not-evaluated: needs a Visual Verification table + `fw ux shots T-4947 <state>=<URL>` of the /approvals Arc Closure section (full page is 46k px tall), then `fw reviewer judge T-4947`.
- **T-4957 DONE:** designer 0.34.0 pinned and served (be.13, c5bb76f89); 832 told.
- **Closed today also:** T-4906 (green on all 8 pages after T-4943 removed the 6-page capture cap), T-4931/T-4941/T-4945 (AEF already had its own key; the host-shared WARN was a measurement bug), T-4942 (restatement marker in evidence). Be-tags: be.10, be.11 (T-4941). be.12 (8c4fdbc97) carries T-4943, T-4945, T-4947..T-4956; add it to the field report's tag table (T-4940).
- **Filed, open:** T-4944 (harness seats can't cite screenshots — ledger provenance decision first), T-4952 (pre-existing web test red), T-4953 (refused Tier 0 status read leaves a pending approval).
- **Operator still:** /review/T-4788 one click. Config done: continuous mode disarmed, SIDECAR_HOST_DM_TRANSITION=0.
- **Field record:** T-4940 open; 010-termlink be.4 and dimitri-mint-dev be.3 recorded today.
- **Lessons:** "not red" is not "green" when a report can be partial (T-4943 pages, T-4956 tiers); read a red's failure message before baselining it.

## FIRST (2026-10-31 ~21:30Z, session at Green, all work pushed)
- **T-4931 DONE (2026-11-01):** AEF already signed with its own key bdd184bd (since T-4454); the "host-shared" WARN was a measurement bug, fixed in T-4941 (`dm._host_fingerprint` now uses `termlink identity sign`, source host_default). G-125 mitigated; close it when a consumer on the next be-tag confirms the WARN is gone with its own key. T-4942 (restatement marker in evidence) is in be.10; T-4941 is in be.11 (3ba10f67e), TermLink told (msg c8d83510).
- **Lesson:** identify a process by full command line and parent before reading its env (a vendored-copy pid was mistaken for AEF's watcher, producing a false finding that had to be corrected in T-4931, T-4941 and G-125).
- **Be-tags this session:** be.7 (T-4935), be.8 (T-4930, T-4932, T-4933, T-4937), be.9 (T-4912, T-4939). Field record: `docs/reports/field-test-v1.8.16-results.md`, kept current under **T-4940** (open until the release; record each new report there with its message id).
- **Field so far:** ring20-dashboard be.3/be.5/be.6/be.8/be.9 WORKS (be.8 found the accept-title bug, fixed by T-4939, be.9 WORKS 10/10); 832 be.3 WORKS (T-4920 0 of 80000); 0506 be.4/be.5 WORKS. Rule b (3 clean upgrades) covers up to be.3 only. Owed: 055 (T-4937 at their next upgrade), 1409 (T-4870), dimitri-mint-dev (T-4913, T-4918, T-4912), TermLink (T-4892), ring20 (T-4893), 832 (T-4924), GitHub #104 submitter (T-4935).
- **Closed this session:** T-4935, T-4930, T-4932, T-4904 (D-626 green, owner -> agent), T-4933, T-4937, T-4938, T-4912, T-4939. Filed: T-4936 (Watchtower restatement buttons, later), T-4940.
- **Operator:** /review/T-4788 (one click), /review/T-4906 (all seats agree the Watchtower half is met; GitHub half cannot be checked from here; opencode suggests the GitHub mirror may not have synced), disarm the expired continuous-run arm (`bin/fw continuous disarm --reason "expired 2026-10-28"`).
- **Backlog needing the operator or design:** T-4925 (nested subprocess spec shape), T-4649 (inception), T-4923 (notes at release time).
- **Lessons (2026-10-31 evening):** (1) review-dispatch tests compare run.sh with termlink.sh AS COMMITTED: commit a termlink.sh change before judging that suite. (2) A verb that copies model output into an operator-owned record needs an operator edit path from day one (T-4939). (3) Bash cannot name the Tier 0 hook file; edit it with the Edit tool and search tests by the `check-tier` prefix.

## Earlier today (2026-10-31 ~14:45Z, session at Amber, all work pushed)
- **Be-tags since v1.8.15:** v1.8.16-be.1 … be.5 (be.3 = T-4920/T-4921 security; be.5 = T-4926/7/8 security). bleeding-edge is ahead of be.5 by T-4929 (classifier skips Evidence blocks). Field so far: ring20-dashboard be.3 WORKS (T-4871, T-4914, T-4916), 0506 be.4 WORKS. Waiting: 1409 (T-4870), 832 (be.2/be.3, designer 0.33.0 pin T-4924), dimitri-mint-dev (T-4913, T-4918), TermLink (T-4892), ring20 (050 acks, T-4893 WORKS pending), ring20-dashboard (be.5).
- **Waiting for the operator:** inception T-4917 (1409: dispatch time limit = evaluation trigger, not kill; recommend GO); whether to give AEF its own TermLink identity (T-4252; the new T-4892 alerts WARN fires for AEF itself); /review for T-4788, T-4792, T-4906, T-4904; dimitri-mint-dev's LAN embed/rerank/Whisper offer (msg 577f99b8).
- **Operator answers 2026-10-31 ~15:00Z:** (1) T-4917 GO — the operator still has to click http://192.168.10.107:3000/inception/T-4917 (agents cannot decide). (2) "yes" to AEF's own identity → T-4931 prepared; run it at the start of a session (a coordination event with peers). (3) "why not agent review?" → done: T-4792 closed on an independent green verdict (V-20261031-d22e4d25, first real D-626 close here). T-4906 and T-4904 came back not-evaluated: T-4906 needs the GitHub page, which the sandbox cannot fetch (stays human); T-4904 failed on T-4932 (the judge required the POST-only /api/task/create). Re-judge T-4904 after T-4932. T-4788 stays a one-click operator close: all criteria ticked, carve-out triggered by "change ownership" in its own last criterion.
- **0506 be.5 WORKS** (first field confirmation of the be.5 security fixes); ring20-dashboard has the six probe lines in its own tests (9/9 on be.5).
- **Backlog, ready:** T-4930 first (accept a PROPOSED RESTATEMENT: ring20-dashboard has 7 ambers waiting), T-4932 (judge page plan), T-4933 (opencode seat never completes), T-4925 (corpus_spec reads only a process's direct children: nested subprocess nodes dropped), T-4930 (no verb to accept a PROPOSED RESTATEMENT), T-4923 (v1.8.16 release-notes items: write them into the notes at release time), T-4912 (cosmetic -c in ps after a budget restart), T-4649 (project-local hook extension points: inception first).
- **Lesson to keep (2026-10-31):** when changing a gate file, run EVERY test that reads it, not only the ones named after it (T-4920 broke the T-4851 parser test; T-4921 broke the T-3000 template lint). And never split a gate keyword to get a command past it, even for a harmless test.

## Older (2026-10-29 ~21:25Z), all done 2026-10-30/31
- T-4870 finished and pushed; dimitri-mint-dev's v1.8.15 result recorded (T-4911, T-4915); glm-5.2 pin was their project copy (T-4913).

# Older carry-over (written 2026-10-28 ~12:00 UTC, session end at Amber)

## RELEASE FREEZE ACTIVE (operator ruling 2026-10-28, T-4869; CLAUDE.md §Release Freeze Phase)
No new development until v1.8.15 is released. Allowed: testing, fixing field-reported FAILS, test reliability, release work. New requests: task with --horizon later and tag post-freeze, need before solution, tell the requester.
Confirmation rule (operator answer b, 2026-10-28): a clean full upgrade by 3+ testers confirms changes without a specific verdict; a specific FAILS must be fixed and re-confirmed.
Exit: every active tester on be.48+ reported, no open failures, then release; only the operator lifts it.

## CONTINUOUS MODE ARMED (operator, 17:07Z) until 2026-10-28T19:07:50Z, 6 sessions, tier 1, max 6 tasks
Directive: freeze work only; stop and report when 1409 has sent its be.48+ upgrade report or the queue is empty. The operator armed it to watch the restart hand-off: say in the first message whether this session came from the wrapper's budget restart (S-2026-1028-1812 was the session before).

## Tester status (2026-10-28 evening) — see docs/reports/field-test-v1.8.15-results.md, T-4876
- Clean on be.48+: ring20-dashboard (be.49), ring20 (be.48), dimitri-mint-dev (be.48), 055 (be.49), 832 (be.48, A-H complete), TermLink (be.49). Rule b met.
- ONLY 1409's be.48+ upgrade report is missing for the freeze exit.
- be.49 (T-4874) carries T-4872, T-4873, T-4857..T-4859; T-4872 and T-4873 confirmed WORKS by their reporters.
- Still owed, not blocking: 055 G, dimitri-mint-dev G + T-4781 (after their relaunches).

## UPDATE 2026-10-28 ~19:30Z (later session)
- DONE: T-4879 (no repro), T-4880 (dm mail per addressee in fw sidecar alerts; TermLink told), T-4881 (config parity), T-4883 (reload-identity test flake). All older unanswered dm items handled (.context/sidecar/dm-handled); 0235 told P-001 = T-4046 (asked WORKS/FAILS + truncated Co-Authored-By refusal).
- be.50 CUT AND PUSHED (370b2688b): be.49 + T-4875, T-4880, T-4881, T-4883. `fw release` always releases HEAD (no cut-at-tag), so these 4 must be confirmed rather than released unconfirmed.
- Asked for be.50 upgrade reports: 1409 (conversation aef-v1815-freeze-exit, the freeze-exit gate), 010-termlink + 055 (conversation aef-v1815-be50). Three clean be.50 upgrades = rule b for the 4 new fixes.
- Operator review ticks open (they asked "what do I review"): T-4046, T-4846, T-4875, T-4854, T-4831, T-4832, links via `bin/fw task review-batch`.
- 832 T-1261: origin carrier advice given (option 1, x832 namespace, originalId=); they publish the namespace URI after their operator rules.
- OPERATOR 2026-10-28 ~19:45Z, answer "1": the release WAITS for 1409's be.50 report (earliest 2026-10-29, after their reviews, with their operator's go). TermLink and 055 also upgrade to be.50 when their operators say go. 1409 dropped T-4797 (they use clones now, K3).
- 1409 INTERIM 2026-10-28 21:33 (msg 8e456671): upgraded to be.50 cleanly (dry-run + upgrade exit 0, no PRESERVE file changed, 29 files, their commit 97362b0b7; 40 STALE review worktrees + claude-fw restart hint expected). Doctor on be.50 (~21:45, msg 3b77df39): 0 FAIL, 38 project WARN + 1 host WARN; no pre-upgrade doctor reading exists. Pre-upgrade baseline (5f66369d): 7 project tests red, data-dependent, theirs, not framework; they separate them out in the report. Still owed: full test suite after a machine restart.
- NEXT: when reports arrive, record them in docs/reports/field-test-v1.8.15-results.md (under a task), then release decision + dry-run to the operator.

## FIRST agent work for the next session (allowed under the freeze: reported breakage)
- T-4879: a consumer session that inherits another project's PROJECT_ROOT made fw write tasks/focus into that project (1023, on v1.6.15, report ~2026-10-15, forwarded 2026-10-28). Reproduce on current be.49 first; if it reproduces, fix so fw trusts its own bin/fw location + cwd .framework.yaml and refuses on mismatch. 1023 was answered directly (msg d8b7308d) with upgrade guidance.
- T-4878: sidecar message truncated at 832 (investigate if it repeats).
- T-4880: peer mail to this project sat unread for days (dm-stale judges by signing identity; auto-confirm receipts count as read). Root cause of the two late forwards on 2026-10-28. TermLink sent it (msg 80641d05; full text: bin/fw sidecar inbox --show 80641d05-a425-44dc-8664-de20ef2637db): rule in their commit 22782d588 (scripts/check-unacted-mail.sh, tests/unacted-mail-fixtures.sh 17 cases, 4 more in session-start-alerts-fixtures). Rule: per message, OPEN when nobody it was meant for (to_project, else anyone else) posted after it; within 72 h of the other side = an answer; receipts/notices/replies excluded; a "handled" file escapes mail answered on another rail. Reply to TermLink once T-4880 lands.
- Restart test result to record: session S-2026-1028-1812's successor reached the Stop band at ~17:37Z; check .context/working/.restart-requested and the claude-fw log for whether the budget restart fired.

## Release path
- T-4867 report: docs/reports/T-4867-release-cut-point.md. Under rule b: release up to the latest be-tag once all active testers are on it with no open FAILS (was be.46 at analysis time; now be.48/be.49).
- T-4868 inception (release-branch model) is open; research not started; lower value now (confirmed fixes sit on top of the unconfirmed bulk, cherry-picks would conflict).
- When the exit condition holds: release decision (T-4743 closed-record edit needs FW_ALLOW_CLOSED_RECORD_EDIT=1 by the operator), dry-run, then release; operator lifts the freeze.

## Operator decision walk (one question at a time, with context)
Done: Q1 designer reviews (T-4830/4836/4838/4845 closed on green verdicts; T-4831/T-4832 back to operator: look in the designer, then tick /review/T-4831 and /review/T-4832). Q2 release -> c (cut-point + inception). Q3 T-4649 -> deferred by the freeze. Freeze ruling. Q5a -> b.
Also done since: Q4 T-4802 -> a, Q2b -> b, Q f -> a (see below). Remaining (low urgency): T-4808, T-4785/T-4786 (design, after the freeze), T-4790 drop (operator), T-4829 wording, plus the operator review ticks listed under "Late 2026-10-28".

## Post-freeze backlog (horizon later, tag post-freeze)
FIRST after the release (operator 2b, answer b): T-4788 (python3 -c write idioms pass the task gate) and T-4792 (command substitution judged by outer command), with tests and a field round.
Then: T-4649, T-4855, T-4856, T-4864, T-4870 (upgrade drops consumer local block, 1409), T-4871 (runme double start, ring20-dashboard). Also consider moving T-4840's .audit-inflight marker out of .context/audits (832 heads-up; possible T-4866 flake source).

## Late 2026-10-28
- 832 COMPLETED its v1.8.15 A-H field test (T-4811 and G WORK, no open FAILS). It waits for the release notice, then sends designer 0.32.0 (re-pin = post-release work).
- TermLink upgraded to be.49 clean (T-4827, T-4828 WORK). 6 of 7 testers on be.48+; ONLY 1409's upgrade report is missing for the freeze exit.
- Q f -> a: T-4875 built (retry a first-time red file once; pass on retry = WARN suspected flaky + flakes.jsonl). Partial-complete: operator ticks /review/T-4875 after looking at UNIT_SUITE_FLAKE_RETRY_MAX on /config. Not yet in a be-tag (next tag or the release).
- Operator review ticks still open: T-4831, T-4832 (designer look), T-4846 (/config TMP_USE_WARN_PCT), T-4854 (restart), T-4875 (/config retry row).
- Remaining walk items (low urgency): a T-4808 and c T-4785/T-4786 (design, after the freeze), d T-4790 (operator drops the dead-lettered consult), e T-4829 wording.

## Decided in the walk since the last handover
- Q4 T-4802 -> a: dispatch_records.py supported for ring20 poold; B/C after the freeze (ring20 told, msg e9d39d8d).
- Q2b -> b: gate holes after the release.
- Testers on be.48+: ring20-dashboard (be.49), ring20, dimitri-mint-dev, 055 (be.49), 832, TermLink (be.49). Only 1409 left. T-4872 and T-4873 confirmed WORKS by their reporters.

## Watch
- opencode review seat gave no completion twice in today's designer reviews (832 reports it working on their side). If it repeats, investigate (allowed under the freeze).
- T-4866: first-time one-off suite reds (fw_pending_remind unexplained; t4041 once).
