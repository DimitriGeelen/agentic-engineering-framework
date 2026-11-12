# T-4239 Human AC#1 — reviewer claude-code (rung-5 panel), revision 8e4ed473c

## Checked
- `ss -ltnp`: Watchtower python3 listens on 0.0.0.0:3000 (all interfaces, so reachable from other LAN hosts).
- `curl http://192.168.10.107:3000/` -> HTTP 200 (fetched via the LAN address; not from a second physical machine).
- `.framework.yaml` line 37: `HOST: 0.0.0.0` (this repo's value).
- `curl http://192.168.10.107:3000/config`: row `<code>FW_HOST</code>`, current **0.0.0.0**, default `127.0.0.1`, source badge `env`.
  Description: "Watchtower bind address (env FW_HOST, read by web/config.py). Default 127.0.0.1: this machine only, because Watchtower has no login and can record Human decisions (T-4239). 0.0.0.0 or :: opens it to every interface (fw config set HOST 0.0.0.0); another specific address makes the shell side probe and advertise it (T-4041, GitHub #88)". Reads clearly.
- Screenshots: 01-root.png loads normally (no console errors recorded). 02-config.png and config@1024/1440/1920: FW_HOST row visible, unclipped, no overlap. Minor: the Default cell wraps `127.0.0.1` across two lines ("127.0.0" / ".1" at 1024/1280, "127.0.0." / "1" at 1920) — cosmetic, value still fully legible.

## Literal vs page
- Criterion says the `HOST` row; the page has no row named `HOST` — it is `FW_HOST`.
- Criterion says "this repo's value 0.0.0.0"; value is 0.0.0.0 but the Source badge reads `ENV` (the launcher passes the repo's HOST to the process as FW_HOST), not a project/.framework.yaml badge.
Substance met; literal row name out of date -> amber with restatement.
