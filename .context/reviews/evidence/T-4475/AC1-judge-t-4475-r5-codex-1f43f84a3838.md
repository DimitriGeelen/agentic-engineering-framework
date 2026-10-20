# Reviewer evidence — T-4475 AC#1

- dispatch: `judge-t-4475-r5-codex-1f43f84a3838`
- worker kind: `codex` (vendor `openai`, model `gpt-6-astra`)
- seat: `codex`
- reviewed revision: `dec4a8888ad5755b81874d047ce1af5fa468772b`
- recorded by: the dispatch runtime on the worker's behalf (T-3582)
- result.jsonl sha256: `4b3caa3113c2b237b17a280b96215e4f337704cbbc70f1ca8d5d912ed4e9d19b`
- result.md sha256: `0cf9920dc60095c6f6ddedbc05065e67786e6a0618af43d94afc24a1738b9cc2`

## The worker's verdict block

```
1. [AC] EMBED_WORKERS row reads clearly beside its neighbours
VERDICT: not-evaluated
WHY: Screenshot capture failed with net::ERR_CONNECTION_REFUSED at http://192.168.10.107:3000/config. All three listed screenshots are absent from this export. I have not seen the rendered page and cannot verify its text, default, or layout.
GUIDANCE: Restore access to /config and provide screenshots at 1024, 1440, and 1920 pixels. A reviewer must inspect the row’s default, description, and layout at each width. Missing evidence: --evidence .context/visual/T-4475/config@1024.png --evidence .context/visual/T-4475/config@1440.png --evidence .context/visual/T-4475/config@1920.png

Summary: 0 green, 0 amber, 0 red, 0 escalate, 1 not-evaluated
```

## The worker's full output (result.md)

```
1. [AC] EMBED_WORKERS row reads clearly beside its neighbours
VERDICT: not-evaluated
WHY: Screenshot capture failed with `net::ERR_CONNECTION_REFUSED` at `http://192.168.10.107:3000/config`. All three listed screenshots are absent from this export. I have not seen the rendered page and cannot verify its text, default, or layout.
GUIDANCE: Restore access to `/config` and provide screenshots at 1024, 1440, and 1920 pixels. A reviewer must inspect the row’s default, description, and layout at each width. Missing evidence: --evidence .context/visual/T-4475/config@1024.png --evidence .context/visual/T-4475/config@1440.png --evidence .context/visual/T-4475/config@1920.png

Summary: 0 green, 0 amber, 0 red, 0 escalate, 1 not-evaluated
```
