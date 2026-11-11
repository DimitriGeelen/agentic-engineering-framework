# T-4239 Human AC#1: Watchtower still opens from your other machine (reviewer judge-t-4239-r5-claude-code-9f61031ab204, rung-5-panel:claude-code)

Revision reviewed: d3561d32708c6801f146fa1772f0d4f3d546d79b

## What I checked
- Bind: `ss -ltnp` shows python3 (pid 1600880, started 2026-11-11 22:07, after the T-4239 commit at 19:07) LISTEN on 0.0.0.0:3000. The process env has FW_HOST=0.0.0.0. .framework.yaml line 37 has `HOST: 0.0.0.0`.
- Host 192.168.10.107/24 is on enp7s0. `curl http://192.168.10.107:3000/` returns 200.
- Firewall: ufw is active with INPUT policy DROP. It has `ALLOW 3000/tcp from 192.168.10.0/24` (/etc/ufw/user.rules:93), so LAN peers are admitted.
- Limitation: I could not run a browser on a *different* machine. My curl to the LAN IP came from the host itself. Off-host reachability is inferred from three facts: the 0.0.0.0 bind, the LAN-scoped ufw ACCEPT for 3000 and the 200 on the LAN address.
- /config HOST row (live HTML from the LAN IP): the row is keyed `FW_HOST`, like every other row in the table, which uses the FW_ prefix. Current is **0.0.0.0** and Default is `127.0.0.1`. The Source badge is `env`. Description: "Watchtower bind address (env FW_HOST, read by web/config.py). Default 127.0.0.1: this machine only, because Watchtower has no login and can record Human decisions (T-4239). 0.0.0.0 or :: opens it to every interface (fw config set HOST 0.0.0.0); another specific address makes the shell side probe and advertise it (T-4041, GitHub #88)". It reads clearly: it says what the setting is, why the default is what it is, and how to change it.
- Screenshots: 01-root.png shows the dashboard loading normally. The capturer reported no console or page errors on / or /config. In 02-config.png and config@1024/1440/1920.png the FW_HOST row is visible at every width with Current 0.0.0.0, Default 127.0.0.1 and the ENV badge. At 1024 the default value wraps onto two lines ("127.0.0." / "1"). This is the same narrow-column wrapping the other long defaults get; it is cosmetic, readable and not clipped. Nothing overlaps.

## Verdict
green: the page loads as before, and the row shows default 127.0.0.1 and this repo's value 0.0.0.0 with a clear description.
