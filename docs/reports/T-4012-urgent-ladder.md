# T-4012 — Urgent message ladder (inception)

## Problem

T-3434 (operator ruling D-600) built ONE retry/escalation schedule for every framework message:
2×1 min, 2×5 min, 2×15 min, 2×1 h, 2×4 h, 2×1 d, 2×1 w, 2×1 mo (~76 days), driven by the
`sidecar-sweep-5m` cron. A message that never reached the hub is re-posted; one the hub holds but
nobody read is escalated: recipient project-inbox nudge from the 15-min rung, operator from the
1-day rung, dead-letter after the last rung.

D-600 also ruled that URGENT *compresses* that ladder, and left the design to "a separate
conversation" (`lib/retry_ladder.py` raises NotImplementedError for `urgent=True`;
`docs/reports/T-3434-retry-ladder.md` §6). That conversation never happened; no task existed.

## Evidence — the first real case (2026-10-09)

- ~07:03Z: AEF sent an operator-requested urgent alarm (OneDev unreachable) to
  proxmox-ring20-management with `fw sidecar send --urgent`. Cross-host, so the sidecar could only
  post to ring20's hub: state HUB_ACCEPTED (held, not read). On the normal ladder the first nudge
  would have come at +15 min and the operator surface at +1 day.
- The operator asked for it to be made urgent. The agent bridged by hand: found ring20's manager
  session on its TermLink hub (`termlink remote list ring20-management` → `tl-nl7at4z4`,
  role=manager) and injected the alarm into its PTY (`termlink remote inject … --enter`).
- ring20 answered within minutes on the alarm conversation (cause: DNS on AEF's own host).
- L-477 already warns: a cross-repo inject without a delivery-verify poll-back is a silent failure.
- So the working urgent path today is manual, and needs knowledge (hub profile, session tag
  role=manager) that the sidecar already has or could have.

## Open questions (IW-1..IW-7 in the task)

1. **Timing.** How fast are the urgent rungs? (Strawman: re-check at 1, 2, 5, 10, 30 min, then join
   the normal ladder at the 1-h rung.)
2. **Direct delivery.** May an urgent message go straight to the recipient's live session (TermLink
   PTY inject / the T-4003 resolution) instead of waiting in the hub inbox? Immediately, or only
   after N minutes unread? What if someone is typing there (055's input-state signal)?
3. **Operator first?** Does urgent escalate to *our* operator early (e.g. after 15 min unread)
   rather than after a day? Through which channel (ntfy push, Watchtower, the session)?
4. **Who may mark urgent.** Only operator-requested messages, or may an agent decide a message is
   urgent itself (alarms, security, blocked work)? Noise guard?
5. **Recipient side.** Should a receiving agent treat urgent as interrupting its current work
   (answer within N min), or just read it first?
6. **Dead-letter.** Does urgent give up sooner, or keep escalating until a human acknowledges?
7. **Inbound.** Same rules for urgent mail *to* AEF — e.g. surface immediately to the operator?

## Dialogue Log

### 2026-10-09 — operator states both ladders (verbatim intent)

Operator: "normal is two times two [1 min]. Two times five. Two times fifteen. Two times one hour.
Two times four hours. Two times one day. Two times one week. Two times one month. Two times one
quarter … two times one year. And urgent is one, two, three, four, five, ten, fifteen, thirty,
forty-five, one hour. Two hours, three hours, four hours. Eight hours, twelve hours, sixteen hours.
Twenty hours, one day. Two days, three days, four days, five days, six days, seven days. Two weeks,
three weeks, four weeks. Two months, three months. Two quarters, three quarters, four quarters.
Second year. This is documented."

As schedules:

- **Normal:** 2×1 min, 2×5 min, 2×15 min, 2×1 h, 2×4 h, 2×1 d, 2×1 w, 2×1 mo, **2×1 quarter, 2×1 year**.
  Differs from the implemented T-3434 ladder, which stops after 2×1 mo (~76 days): the quarter and
  year rungs are missing.
- **Urgent** (attempt times from the first send): 1, 2, 3, 4, 5, 10, 15, 30, 45 min; 1, 2, 3, 4, 8,
  12, 16, 20 h; 1, 2, 3, 4, 5, 6, 7 d; 2, 3, 4 w; 2, 3 mo; 2, 3, 4 quarters; 2nd year.
  (Open in the transcription: whether "one" in the minute row is a 1-minute rung after the
  first send, and whether "second year" means 2 years after the first send.)

Operator: "You should have gotten this information from TermLink … via a pick up request on the
sidecar." — Searched: D-600 (decisions.yaml) records only the normal ladder up to 2×1 mo and says
URGENT is "designed in a separate conversation"; no copy of the urgent schedule in .context/inbox.yaml,
pickups, sidecar logs or the T-3433/T-3434 records. Asked 010-termlink to re-send the original
(conversation aef-retry-ladder-resend, 2026-10-09).

Implication: both the quarter/year extension of the normal ladder and the whole urgent ladder are
specified by the operator; what is still open is behaviour per rung (IW-2..IW-7: direct inject,
operator-first, who may mark urgent, recipient behaviour, dead-letter, inbound).

## Recommendation

DEFER until the dialogue above has taken place (evidence gap: the design is operator dialogue).
