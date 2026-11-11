# T-4239 Human AC#1 — Watchtower still opens from your other machine
Reviewer: claude-code seat (rung-5-panel), dispatch judge-t-4239-r5-claude-code-d24cfe4c836c, revision b324d76c1

## Checks
- `ss -ltnp`: python3 (Watchtower) LISTEN on 0.0.0.0:3000, so all interfaces, not loopback-only.
- `curl http://192.168.10.107:3000/` → HTTP 200 (LAN address; run from this host, not from a second machine).
- Host firewall: ufw active, INPUT policy DROP; the nft ruleset has `ip saddr 192.168.10.0/24 tcp dport 3000 accept` (packet counter >0), so LAN clients can reach port 3000.
- .framework.yaml line 37: `HOST: 0.0.0.0`.
- /config HTML (fetched via 192.168.10.107:3000): row `FW_HOST` Current **0.0.0.0**, Default `127.0.0.1`, source env, description:
  "Watchtower bind address (env FW_HOST, read by web/config.py). Default 127.0.0.1: this machine only, because Watchtower has no login and can record Human decisions (T-4239). 0.0.0.0 or :: opens it to every interface (fw config set HOST 0.0.0.0); another specific address makes the shell side probe and advertise it (T-4041, GitHub #88)". It is clear: it gives the safe default, the reason for it, and how to open it up.
- Screenshots: 01-root (dashboard renders normally; the capture reported no console errors), 02-config, and config@1024/1440/1920. Each shows the FW_HOST row with 0.0.0.0 / 127.0.0.1 and the description, readable and unclipped, with no overlap at any width.

## Notes
- The row's label is `FW_HOST`, which is how this page names every key (env-var form of config key HOST). I read it as "the HOST row".
- I did not test from a second physical machine. Everything on the host side that decides LAN reachability (bind address, firewall rule, page served on the LAN IP) is verified. The only part not tested is the network path between machines, which this task does not touch.

Verdict: green
