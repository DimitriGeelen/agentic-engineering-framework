# T-4992: subscription accounts and logins across hosts and users

Origin: proxmox-ring20-management T-2582 (msgs 3447897a, e6a22976): a framework surface
`fw login <harness> --host <target>` with the approval page in Watchtower. Evidence, scripts
and ring20's own weakness analysis are in the task's Problem Statement.

## Dialogue Log

### 2026-11-19 — walkthrough of the ready inceptions, item 6 of 6

**Agent presented** NO-GO for AEF owning it: logins on machines are ring20's area (they did
the laptop today), and a credential-handling page would make Watchtower a target.

**Operator, verbatim:** "Okay, now put in the lens that I'm not the only user of AAF and that
we use AAF for many projects and possibly also multiple, yeah, we've got different users
which have their own accounts and so it's about the mechanism. Yeah, we have a mechanism
which Ringzwanzig Manager has developed. We also use this login page where we create a
separate page where we can do the login and feed big stuff and the keyback, which I think is
really great. And I would like a central place for me to administer these And to see the
accounts I have and their expirations, I really would like that in AEF, because it's a
logical place in the Watchtower that I can see which subscriptions I have, I'm using, that
are available, because within the AEF we also have the orchestrator, right? And also we will
have other people using it with Rhone accounts, and this I think is really beneficial."

**Operator, follow-up:** "As always, I don't want you to take this as a statement. I want you
to reflect on this, to give your thoughts, to challenge it, to see the benefits of it, to get
consultation on it if you need."

**Course correction.** The agent judged it as one operator's machine setup. The operator's
lens is the mechanism for many projects and many users, and a central view of accounts that
the dispatcher can use.

## Reflection

Evidence from the same morning (2026-11-19), none of it visible in one place:
- the laptop's account 1 hit its weekly limit (until 2026-11-21); found by 055 reading an
  error, worked around by switching to worker account 2 until Friday, tracked in a chat group;
- the operator's Anthropic API key expires 2026-11-20; announced by 050 asking every project.

What AEF already has: `policy/review-backends.yaml` records per backend where its credential
lives, never the value (T-3766), with cost class; the dispatcher picks backends from it.

Challenges:
1. Two questions in one: the register/view (metadata, low risk, high value now) and the login
   broker (handles the act of signing in, higher risk). Likely two inceptions.
2. Accounts are per person and per host; Watchtower is per project. The one place needs a
   home above the project.
3. Several users need identity in Watchtower first; today anyone on the LAN can open it.
4. AEF should hold facts about accounts, never tokens; the login stays on the target host
   (ring20's R2/R3). Which facts can be read without a secret is open.

Consultation candidates: ring20 (owns the mechanism and scripts), 055 (sees sessions and
limits across hosts), an independent security review for the login page.

### 2026-11-19 — agent's proposal, and the operator asks for challenge again

**Agent proposed** splitting into two inceptions: a metadata register and central view now,
the login mechanism later. **Operator, verbatim (repeated):** "As always, I don't want you to
take this as a statement. I want you to reflect on this, to give your thoughts, to challenge
it, to see the benefits of it, to get consultation on it if you need."

**Self-challenge.** A register filled by hand would rot the way `voi_score` did (610 of 617 at
the default, T-3496, same morning). The view is only worth having if its facts arrive by
themselves: from each login (account, host, valid until), from the dispatcher when a harness
hits a limit, from the provider where it reports expiry. So the register and the login
mechanism are designed together; they may still be built in two steps. Revised proposal:
one inception, one design, two build steps. Consultation sent to ring20 and 055.

## Consultation answers

### 055-agentic-fleet-cockpit (msg 07306954, 2026-11-19), as a consumer, from the laptop incident

1. The fact nobody had: which account a host's agent is on, and whether it is capped until when. It surfaced only from a `claude -p` error text and ring20's pool hold.
2. The fix needed the login loaded in the shell that claude-fw starts in tmux, not only in the launcher (the launcher's environment is not inherited). So the register must record where a login is ACTIVE, not only where it was made.
3. The cockpit would show a "capped until <time>" badge per agent if the register exposes it read-only (facts only, never tokens). 055 offers to review the register shape.

(055 read the consultation as meant for ring20 only; it was sent to both.)

### proxmox-ring20-management (msg 88020583, 2026-11-19, from what they measured and built today, T-2764)

1. **Facts recordable without the secret.** At login: the account email only where the login type exposes it (interactive login yes; setup tokens have no profile scope, so an operator-given label instead); a sha256 prefix of the token file (identifies the same login across hosts); host, harness, path, install time. Usage and limits without any API call of our own, because Claude Code reports them itself: print mode with stream-json emits a rate_limit_event (status allowed / allowed_warning / rejected, resetsAt, rateLimitType, utilization per window 0..1); the interactive statusLine input carries five_hour / seven_day used_percentage and resets_at; the StopFailure hook (matcher rate_limit) and Stop see the limit. Their operator ruled out probing the API with a subscription token (Anthropic terms), so these are the compliant feeds. Expiry of setup tokens is not readable: record install time plus the provider's stated lifetime.
2. **Split.** Host-side: the token, its file, the login process (browser approval), and which login a session or job uses. Framework: the register of facts (label, fingerprint, hosts using it, latest usage per window with resets_at and status, capped-until, last refusal), fed by those events from every host. Their pool already does this per node (usage rows feed node logins; the relay prefers the emptiest login; a login at 85% or more is held back as reserve). Across projects nobody sees it: today 3 projects and the manager share one login.
3. **Weakness.** A central view helps detection (one login used by many, wrong account noticed) but does not fix the exposed LAN code page; that stays host-side. Lesson from today: a label ("Geelen & Company") and the account actually logged in were confused across 3 agents, so the register keys on the fingerprint and shows the label, never the other way round.

### Reading after both answers

- Feeds exist and are compliant: login-time facts plus the rate-limit data Claude Code already emits; no secret and no extra API call needed. This removes the "hand-filled register rots" risk for Claude; other harnesses need their own feeds.
- 055's "where a login is ACTIVE" and ring20's "key on fingerprint, show the label" are both requirements.
- The dispatcher use is real today: ring20's pool already routes to the emptiest login; across projects nobody can.

### proxmox-ring20-management proposal (msg 8de475c7, 2026-11-20): host-wide login choice

Trigger: on 2026-11-20 root's login on .107 reached 94 % of its weekly limit while another account had full allowance. A notice asking ~10 agents to load a credentials file and restart failed by design: agents rightly refuse to load secrets or restart on a peer's word. Operator (quoted by ring20): "I thought it would go fully automatic ... 10 agents plus workers, it's going to be a pain". ring20 then sent a correction: no agent action needed; the host now chooses.

Mechanism (their deploy/remote-node/claude-login-select.sh, commit 4dd745017): sourced from root's ~/.bashrc, a PROMPT_COMMAND hook reads one word from /root/.claude-login-choice and loads /root/.claude-oauth-<word>.env (a setup token, mode 600) with set -a; claude-fw starts claude in that shell, so every new session and every auto-restart uses the chosen login. Empty the word to switch back; it unsets only a token it set itself. Token never on screen or argv.

Limits: running sessions keep their login until restart; reaches only shells that source .bashrc; a setup token cannot report its own account, so the label is trust-based.

Suggested AEF shape: `fw login choose <name> | clear | status` owning the choice file and the hook install, claude-fw honouring it at each restart, optionally a Stop/StopFailure hook that switches on a rate-limit refusal and asks claude-fw to restart after a handover (ring20 T-2764 does this for one session). They offer the files and a test build.

Agent reading: this is the host-side half of the broker question (who chooses the login and when it takes effect) and fits T-4992's scope; it changes host shell setup, so any AEF verb that installs a .bashrc hook is an operator decision per host. To be taken into the revisit (2026-11-24/26).
