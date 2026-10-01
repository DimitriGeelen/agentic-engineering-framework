# T-3582 live review runs (2026-10-01)

Fixture tasks only (`tests/manual/t3582_live_review.py`); nothing in this repository was judged.

## Rung-5 panel: claude + codex + opencode

```json
{
 "fixture": "/tmp/t3582-live/20261001T152044",
 "rung": 5,
 "degraded": "",
 "outcomes": {
  "1": "green"
 },
 "why": {},
 "error": null,
 "seats": [
  {
   "seat": "claude-code",
   "dispatch_id": "judge-t-9582-r5-claude-code-47cde7657f2e",
   "error": "",
   "kind": "claude",
   "vendor": "anthropic",
   "model": "",
   "wall_s": 28.4,
   "started": true,
   "completion_signed": true,
   "exit_code": 0,
   "rows": [
    {
     "outcome": "green",
     "id": "V-20261001-33380916"
    }
   ],
   "validated": [
    {
     "ac": 1,
     "outcome": "green",
     "source": "ledger",
     "printed": "unknown",
     "verdict_id": "V-20261001-33380916",
     "rung": "rung-5-panel:claude-code"
    }
   ]
  },
  {
   "seat": "codex",
   "dispatch_id": "judge-t-9582-r5-codex-3ea84633026a",
   "error": "",
   "kind": "codex",
   "vendor": "openai",
   "model": "gpt-6-astra",
   "wall_s": 23.1,
   "started": true,
   "completion_signed": true,
   "exit_code": 0,
   "rows": [
    {
     "outcome": "green",
     "id": "V-20261001-5d56b6ae"
    }
   ],
   "validated": [
    {
     "ac": 1,
     "outcome": "green",
     "source": "ledger",
     "printed": "unknown",
     "verdict_id": "V-20261001-5d56b6ae",
     "rung": "rung-5-panel:codex"
    }
   ]
  },
  {
   "seat": "opencode",
   "dispatch_id": "judge-t-9582-r5-opencode-0f0727d24715",
   "error": "",
   "kind": "opencode",
   "vendor": "zai",
   "model": "zai-coding-plan/glm-5.2",
   "wall_s": 18.5,
   "started": true,
   "completion_signed": true,
   "exit_code": 0,
   "rows": [
    {
     "outcome": "green",
     "id": "V-20261001-8c610477"
    }
   ],
   "validated": [
    {
     "ac": 1,
     "outcome": "green",
     "source": "ledger",
     "printed": "unknown",
     "verdict_id": "V-20261001-8c610477",
     "rung": "rung-5-panel:opencode"
    }
   ]
  }
 ]
}
```

## Antigravity, single seat (rung 1)

```json
{
 "fixture": "/tmp/t3582-live/20261001T152208",
 "rung": 1,
 "degraded": "",
 "outcomes": {
  "1": "green"
 },
 "why": {},
 "error": null,
 "seats": [
  {
   "seat": "antigravity",
   "dispatch_id": "judge-t-9582-r1-6d6645ef1fb0",
   "error": "",
   "kind": "antigravity",
   "vendor": "google",
   "model": "",
   "wall_s": 136.8,
   "started": true,
   "completion_signed": true,
   "exit_code": 0,
   "rows": [
    {
     "outcome": "green",
     "id": "V-20261001-1615c356"
    }
   ],
   "validated": [
    {
     "ac": 1,
     "outcome": "green",
     "source": "ledger",
     "printed": "unknown",
     "verdict_id": "V-20261001-1615c356",
     "rung": "rung-1-same-vendor-independent"
    }
   ]
  }
 ]
}
```
