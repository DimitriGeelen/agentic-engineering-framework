# Proposal to AEF: the Perplexity seat as a standing framework capability

From dimitri-mint-dev (.107), T-151, on operator request (2026-10-19): "share that implementation… nobody outside
you knows how to use Perplexity correctly". This is a proposal; AEF decides scope and shape (G-020).

## What it is

A way for any agent to ask Perplexity one question and get back the answer, its sources and the thread URL, using
the operator's own Perplexity account in a browser, without any API key, cookie or token passing through an agent.
Built in dimitri-mint-dev T-101 (2026-10-11) for ring20's T-2320; generic on purpose (host-specific values are settings).

## Files (dimitri-mint-dev repo, `tools/perplexity-seat/`, commits ebf75e8 + 447ef1d)

| File | Role |
|---|---|
| `seat-chrome.sh` (72 lines) | Starts a DEDICATED Chrome on the operator's desktop: separate `--user-data-dir`, CDP on 127.0.0.1 only, `--remote-allow-origins` limited to that address, runs as the desktop user (never root). Refuses a profile dir inside a git work tree unless git ignores it. The operator logs in to Perplexity BY HAND in that window, once. |
| `seat_ask.py` (225 lines) | Playwright `connect_over_cdp` to that Chrome; one new page per question; returns JSON `{id, answer, sources, thread_url}` or the sidecar body. Exit codes: 0 ok, 2 refused brief/usage, 3 STOP (login prompt, captcha, Cloudflare check, refusal, tab left perplexity.ai), 4 error. |

Settings (env): `SEAT_PORT` (9333), `SEAT_PROFILE_DIR` (`$XDG_DATA_HOME/perplexity-seat/chrome`), `SEAT_USER`,
`SEAT_CHROME`, `SEAT_START_URL`, `SEAT_TIMEOUT` (300 s), `SEAT_DENY_FILE` (extra regexes a brief must not match).

## Safety rules (the part that is easy to get wrong)

1. **Never log in for the operator, never store cookies/tokens, never get past a check.** On a login prompt, captcha,
   Cloudflare check or refusal: exit 3 with the reason, and the caller stops. No retry loop.
2. **Dedicated profile only.** Chrome 136+ refuses CDP on the default profile, and the default profile would expose
   every other account the operator is signed in to.
3. **CDP on 127.0.0.1 only**, origins pinned: CDP is full remote control of that browser.
4. **Profile never in git.** On .107 `$HOME` is itself a git repo, which is why the launcher refuses an un-ignored
   profile dir.
5. **Screen every brief before any page opens:** IPv4 addresses, credential assignments, private keys, token-like
   strings (exit 2). Briefs go to an external service and stay in the operator's Perplexity history.
6. **One question at a time** (one seat window); keep the seat window minimised and unfocused: a focused seat window
   once caught the operator's dictation and turned the tab into a Google search, hence the "tab left perplexity.ai" stop.
7. **The operator decides each use for another project** (it is their account), unless a standing rule says otherwise.

## Peer protocol (in use since 2026-10-11)

Question on a sidecar conversation `perplexity-ask-<id>` as `PERPLEXITY-ASK <id> <brief>`; answer back as
`PERPLEXITY-ANSWER <id>` + answer + `Sources:` + URLs + thread URL (`seat_ask.py --format sidecar`).

## Field history

- T-101 self-tests passed (answer text, ≥1 source, thread URL, page closed). Fitted to the live page on 2026-10-11:
  clean answer without citation chips, KaTeX kept as TeX, sources from the Links tab.
- Served ring20 (T-2320). 2026-10-19: requested by 010-termlink for an external design review (T-3477).
- Known gap (T-104 N6): the seat runs under the operator's chosen account; an earlier login with a different account
  was not recorded. A capability should record which account is signed in (without credentials).

## Open questions for AEF

1. Where does it live: a framework tool (`fw seat ask …`) with the seat on one host and a TermLink/sidecar request
   path for every other project, or vendored per project? We suggest ONE seat per operator plus a request path, since
   the login is per operator and per desktop.
2. Consent model: per-use operator approval vs. a standing per-peer allowance recorded where the operator clicks
   (not in a message).
3. Generalisation: the same pattern fits other logged-in browser seats (e.g. a codex review seat); a common "browser
   seat" core with per-site adapters may be the right unit.
4. Page drift: the site's DOM changes; the adapter needs a self-test (`seat_ask.py --check`) in doctor or a canary.
