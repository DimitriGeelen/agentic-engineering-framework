# Field-test results — submitter confirmations

A GitHub issue's submitter confirming the fix is a positive field test of the linked task under T-4146.
`fw issues confirm-close` (and the sync that runs it) appends a row here; `fw issues release` reads this
table together with the release's own `field-test-<version>-results.md`. Written by lib/issues.py (T-4664);
keep the table last in the file, a line after it ends the table.

| Fix | Verdict | Version named in reply | Reply | Date |
|---|---|---|---|---|
| T-4040 | **WORKS** — GitHub #86 (submitter) | 1.8.13 | [`IC_kwDORdtOLc8AAAABeiYQ-g`](https://github.com/DimitriGeelen/agentic-engineering-framework/issues/86) | 2026-10-22 |
| T-3886 | **WORKS** — GitHub #87 (submitter) | 1.8.13 | [`IC_kwDORdtOLc8AAAABeke-_w`](https://github.com/DimitriGeelen/agentic-engineering-framework/issues/87) | 2026-10-22 |
| T-4041, T-4054 | **WORKS** — GitHub #88 (submitter) | 1.8.11 | [`IC_kwDORdtOLc8AAAABdNjW_g`](https://github.com/DimitriGeelen/agentic-engineering-framework/issues/88) | 2026-10-22 |
| T-4042 | **WORKS** — GitHub #89 (submitter) | 1.8.11 | [`IC_kwDORdtOLc8AAAABdNjlWw`](https://github.com/DimitriGeelen/agentic-engineering-framework/issues/89) | 2026-10-22 |
| T-4043 | **WORKS** — GitHub #90 (submitter) | 1.8.13 | [`IC_kwDORdtOLc8AAAABeiYktQ`](https://github.com/DimitriGeelen/agentic-engineering-framework/issues/90) | 2026-10-22 |
| T-4044 | **WORKS** — GitHub #91 (submitter) | 1.8.11 | [`IC_kwDORdtOLc8AAAABdNjyYg`](https://github.com/DimitriGeelen/agentic-engineering-framework/issues/91) | 2026-10-22 |
| T-4046 | **WORKS** — GitHub #93 (submitter) | 1.8.13 | [`IC_kwDORdtOLc8AAAABeiZKVQ`](https://github.com/DimitriGeelen/agentic-engineering-framework/issues/93) | 2026-10-22 |
| T-4047 | **WORKS** — GitHub #94 (submitter) | 1.8.13 | [`IC_kwDORdtOLc8AAAABeiZvDg`](https://github.com/DimitriGeelen/agentic-engineering-framework/issues/94) | 2026-10-22 |
