# T-4239 Human AC#1 — independent review (rung-5-panel:claude-code)

Revision: 648be9fb7ff6683f90947e65295a890dcd0eebbf. Judged by the restated title (2026-11-12).

## Live checks (run on the Watchtower host, 2026-11-12)
- `curl http://192.168.10.107:3000/` returned HTTP 200.
- `ip -4 addr` shows that 192.168.10.107/24 is this host's LAN interface (enp7s0).
- `ss -ltnp` shows python3 listening on **0.0.0.0:3000**, so it accepts connections on every interface, not only loopback.
- `ufw status` shows `3000/tcp ALLOW 192.168.10.0/24 # T-149 LAN only`, so the firewall lets LAN clients in.
- `bin/fw config get HOST` returns `0.0.0.0`.
- `curl http://192.168.10.107:3000/config` contains the `FW_HOST` row: current **0.0.0.0**, default `127.0.0.1`, source badge `env`. Its description reads: "Watchtower bind address (env FW_HOST, read by web/config.py). Default 127.0.0.1: this machine only, because Watchtower has no login and can record Human decisions (T-4239). 0.0.0.0 or :: opens it to every interface (fw config set HOST 0.0.0.0); another specific address makes the shell side probe and advertise it (T-4041, GitHub #88)".

Limitation: I could not use a physically separate machine. Instead I checked each part of the path from another LAN machine: the 0.0.0.0 bind, the LAN-IP response and the UFW LAN allow rule for 3000/tcp. None of these blocks remote LAN access.

## Screenshots (all read)
- 01-root: the Watchtower dashboard renders (header, focus, arcs, tokens). The capture notes show no console errors. The page is 52k px tall, so only the top was captured.
- 02-config: the full /config page; the FW_HOST row is present with 0.0.0.0 / 127.0.0.1 / ENV and the description.
- config@1024/1440/1920 (captured through the LAN address 192.168.10.107): I cropped the FW_HOST row at each width. All cells are visible and readable, with no overlap or clipping of content. Cosmetic issue: at every width the narrow Default column wraps the default value as "127.0.0" / ".1". The value is still legible and complete.

## Verdict: green
The page loads through the LAN address, the FW_HOST row shows default 127.0.0.1 and current 0.0.0.0, and the description is clear (it says what the default means, why, and how to open it).
