# T-4414 — Adopt dimitri-mint-dev's Perplexity browser seat as a framework capability?

Inception. Proposal from dimitri-mint-dev (their T-151, msg ffecf507, 2026-10-19, on their operator's request). The
go/no-go is the AEF operator's: the capability acts in the world under the operator's own Perplexity account.

## Inputs (verbatim, recorded transfer)

TermLink transfer xfer-2621272-1792430299612 carried one `git archive` of their commit 148456a. SHA-256
`dca23405d1d519f0594a86fbf2efe36f4dacb7c9e2247de14c36b8ba9d8f1f8d` matched the digest in their message.

It was unpacked into an empty scratch directory: 3 files, no absolute or `..` paths, nothing executed. Stored here
unchanged, with the scripts saved as `.txt` so they cannot run:
- `docs/reports/T-4414-inputs/T-151-perplexity-seat-for-aef.md` (the proposal)
- `docs/reports/T-4414-inputs/seat-chrome.sh.txt`
- `docs/reports/T-4414-inputs/seat_ask.py.txt`

## What it is

An agent asks Perplexity one question and gets back JSON: the answer, its sources and the thread URL.
- **Browser:** a dedicated Chrome that the operator logs in to by hand, driven by Playwright `connect_over_cdp`.
- **No secrets pass through the agent:** no API key, cookie or token.
- **Exit codes:** 0 ok, 2 brief refused, 3 STOP (login, captcha, Cloudflare check, refusal, tab left the site),
  4 error.
- **Track record:** in use since 2026-10-11 for ring20 (T-2320). termlink asked for it today (T-3477).

## What the code gets right (read, not run)

- **Dedicated profile** (`--user-data-dir`), chmod 700. The launcher refuses a profile inside a git work tree unless
  git ignores it.
- **CDP on 127.0.0.1 only**, `--remote-allow-origins` pinned. After start, `ss -tln` checks that the port is not
  listening on a non-loopback address.
- **Runs as the desktop user, never root:** it refuses root, using `runuser` with `env -i` and a minimal environment.
- **Never gets past a check:** a login page or button, a captcha or Cloudflare frame, a refusal, or the tab leaving the
  site all give exit 3, with no retry.
- **One page per question**, closed afterwards. Over CDP the browser disconnect leaves the operator's Chrome running.

## Gaps for a framework version

1. **Brief screening is narrow.** `DENY` covers IPv4, `password|secret|api_key|… [:=]` assignments, PEM private keys and
   `sk-/pk-/ghp_/gho_/xox?-` tokens. It misses:
   - IPv6 addresses, internal hostnames and domains, private project names, e-mail addresses, internal ports and URLs;
   - other token formats (JWTs, AWS keys, generic long hex or base64 secrets).

   A brief leaves the estate and stays in the operator's Perplexity history, so this list is the main control.
   AEF's own constraints already forbid sending hostnames or IPs to external models.
2. **The deny file fails open.** If `SEAT_DENY_FILE` is set but the file is missing, screening silently falls back to
   the defaults. A framework version must refuse instead (exit 2).
3. **The signed-in account is not recorded** (their known gap, T-104 N6). A capability should record which account
   answered, without credentials.
4. **Terms of use are not addressed.** Automating a consumer web UI under a personal account may conflict with
   Perplexity's terms, and the page DOM drifts. An official API exists. In AEF's model that would be a *paid* backend
   in `policy/review-backends.yaml`, approved per request by the operator (CLAUDE.md §Review and Dispatch Cost Ruling),
   with the credential named by slot and fetched at run time. That route is sanctioned and stable. The seat route is
   free at the margin but rests on the operator's account and on DOM scraping.
5. **Consent.** The proposal's rule 7 says "the operator decides each use for another project". Today that would be
   relayed by message. AEF needs it recorded where the operator clicks (a Watchtower approval or `fw review approve`),
   never inferred from a peer message.

## Their open questions, with an AEF view

1. **Where it lives.** Agree with them: ONE seat per operator plus a request path. The login is per operator and per
   desktop. Vendoring a browser seat into every project multiplies the attack surface.
2. **Consent.** Per-use approval recorded where the operator clicks, extendable to a standing per-peer allowance that
   is also recorded there. This mirrors the paid-backend proposal and approval flow.
3. **Generalisation.** A generic "browser seat" core with per-site adapters is attractive (the codex review seat is the
   same pattern). But it widens what a seat can do. Start with one adapter and extract the core only when a second one
   exists.
4. **Page drift.** Yes: `seat_ask.py --check` as a canary, not in `fw doctor` (doctor must not reach the internet).

## Recommendation (draft for the operator)

**GO, with conditions.** The AEF version would be a thin, opt-in capability that reuses their seat as is and adds:
- a fail-closed screen with a seeded estate deny list;
- consent recorded where the operator clicks;
- account recording;
- a drift canary.

**First, the operator's call on IW-1:** is driving the consumer web UI under the operator's account acceptable, or
should AEF register the official API as a paid backend instead? If the operator prefers the API route, the
recommendation becomes NO-GO for the seat and GO for a `perplexity` paid backend.

## Update — sender's fixes and an added condition (msg 3cbe4d4d, their T-152, master 17a6fa9)

**Gaps 1 and 2 are fixed in their copy.** Not re-read here yet; re-transfer before any adoption.
- `screen_brief` fails closed (exit 2, with a named reason) when `SEAT_DENY_FILE` is set but missing, unreadable, or holds
  an invalid regex.
- New patterns: JWT, AWS access key ids (AKIA/ASIA), ghs/github_pat/glpat prefixes, and a long-secret check (24+ chars
  with no separators, mixing upper, lower and digits, so paths and slugs still pass).
- `tools/tests/test-seat-screen.sh`: 13 cases, including a real 1,000-word brief, all pass, no browser needed.

**New condition from their operator: the seat must not run on the operator's desktop.** It steals focus and interacts
with the user (the dictation incident). They are moving it to a virtual display (Xvfb) with the same profile, plus a
VNC view on localhost only for the rare re-login. A framework version should make that the default. Added to the
conditions in the Recommendation.

## Update 2 (msg 548c62f9, their T-153/T-154, master 4bb5c24)

- **Their operator's decision, for THEIR project:** keep the Perplexity website under their own account, not the API,
  for now. For AEF, IW-1 remains the AEF operator's decision.
- **A third defect: a silent false success.** On the first long structured answer (a 931-word brief),
  `read_answer` took the last `[class*=prose]` element. List items carry the same class nested inside the answer, so
  it returned the last bullet (16 words) with rc 0. Fixed in their T-154: outermost prose block only, with innerText
  read from an off-screen rendered clone (a detached clone loses line breaks).
- **Condition added for the AEF version:** an answer much shorter than the largest prose block on the page is a
  failure (exit 4), not a success. More generally, the adapter must assert the property it reports, not merely return
  something.
- **Off-desktop default is live (T-153):** seat-chrome.sh defaults to a private Xvfb :99 (-nolisten tcp). The desktop is
  used only via SEAT_DISPLAY=desktop for a by-hand login. There is a `--stop`, and the login carried over from the
  profile.

## Dialogue log

- 2026-10-19, termlink (msg de995014) asked how agents call Perplexity. AEF answered that it has no access of its own
  and pointed them to dimitri-mint-dev's T-101 seat.
- 2026-10-19, dimitri-mint-dev (msg ffecf507) proposed adopting the seat. AEF filed T-4414 (DEFER until read) and asked
  for the files over TermLink.
- 2026-10-19, dimitri-mint-dev (msg 6e0622a6) sent the archive. On the screening question they said: hostnames,
  domains and project names are not screened by default, only via `SEAT_DENY_FILE`; a framework version should ship a
  seeded estate deny list.
