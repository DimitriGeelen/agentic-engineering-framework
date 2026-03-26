# T-629: Deep Consumer Health Audit

Generated: 2026-03-26T21:38:50Z

## Methodology
- Byte-for-byte diff of agents/context/*.sh against framework source
- Hook configuration validation (settings.json)
- .framework.yaml version + metadata check
- Git hook installation verification
- .context/ directory structure health
- Vendored fw syntax check (bash -n)
- Rogue file detection (unexpected modifications)

---

## 001-sprechloop

### 1. Context Agent Scripts
- Match: 12/16 | Missing: 0 | Diverged: 4

- DIVERGED: budget-gate.sh (13 lines differ)
- DIVERGED: check-active-task.sh (56 lines differ)
- DIVERGED: checkpoint.sh (13 lines differ)
- DIVERGED: check-tier0.sh (98 lines differ)
- ROGUE: loop-detect.sh (not in framework source)

### 2. Claude Settings Hooks
- All required hooks present, correct structure

### 3. Framework Config (.framework.yaml)
- version: 1.3.0 | last_upgrade:  | upgraded_from: 

### 4. Git Hooks
- commit-msg: installed, references framework
- post-commit: installed, references framework
- pre-push: installed, references framework

### 5. Context Directory Health
- working/: exists (12 files)
- project/: exists (8 files)
- episodic/: exists (70 files)
- handovers/: exists (77 files)

### 6. Vendored fw Syntax
- bin/fw: syntax OK

### 7. Rogue File Check
- 22 rogue/modified files detected:

- MODIFIED: lib/inception.sh (98% of framework size)
- MODIFIED: lib/bus.sh (79% of framework size)
- MODIFIED: lib/promote.sh (97% of framework size)
- MODIFIED: lib/preflight.sh (98% of framework size)
- MODIFIED: lib/validate-init.sh (58% of framework size)
- MODIFIED: lib/init.sh (96% of framework size)
- EXTRA: agents/telemetry/capture-on-compact.sh (no framework equivalent)
- MODIFIED: agents/audit/self-audit.sh (85% of framework size)
- MODIFIED: agents/audit/audit.sh (93% of framework size)
- MODIFIED: agents/git/lib/hooks.sh (90% of framework size)
- MODIFIED: agents/context/check-tier0.sh (129% of framework size)
- MODIFIED: agents/context/lib/focus.sh (118% of framework size)
- MODIFIED: agents/context/check-active-task.sh (118% of framework size)
- EXTRA: agents/context/loop-detect.sh (no framework equivalent)
- MODIFIED: agents/context/budget-gate.sh (100% of framework size)
- MODIFIED: agents/context/checkpoint.sh (100% of framework size)
- MODIFIED: agents/task-create/create-task.sh (84% of framework size)
- MODIFIED: agents/task-create/update-task.sh (90% of framework size)
- MODIFIED: agents/fabric/lib/register.sh (53% of framework size)
- MODIFIED: agents/fabric/lib/summary.sh (88% of framework size)
- MODIFIED: agents/healing/lib/diagnose.sh (98% of framework size)
- MODIFIED: bin/watchtower.sh (97% of framework size)

### Health Score: 20% (7/34 checks passed, 27 issues)

---

## 050-email-archive

### 1. Context Agent Scripts
- Match: 12/16 | Missing: 0 | Diverged: 4

- DIVERGED: budget-gate.sh (13 lines differ)
- DIVERGED: check-active-task.sh (56 lines differ)
- DIVERGED: checkpoint.sh (13 lines differ)
- DIVERGED: check-tier0.sh (98 lines differ)
- ROGUE: loop-detect.sh (not in framework source)

### 2. Claude Settings Hooks
- All required hooks present, correct structure

### 3. Framework Config (.framework.yaml)
- version: 1.3.0 | last_upgrade:  | upgraded_from: 

### 4. Git Hooks
- commit-msg: installed, references framework
- post-commit: installed, references framework
- pre-push: installed, references framework

### 5. Context Directory Health
- working/: exists (15 files)
- project/: exists (11 files)
- episodic/: exists (81 files)
- handovers/: exists (26 files)

### 6. Vendored fw Syntax
- bin/fw: syntax OK

### 7. Rogue File Check
- 16 rogue/modified files detected:

- MODIFIED: lib/inception.sh (98% of framework size)
- MODIFIED: lib/bus.sh (96% of framework size)
- MODIFIED: lib/init.sh (98% of framework size)
- MODIFIED: agents/termlink/termlink.sh (90% of framework size)
- MODIFIED: agents/audit/self-audit.sh (85% of framework size)
- MODIFIED: agents/audit/audit.sh (100% of framework size)
- MODIFIED: agents/git/lib/hooks.sh (97% of framework size)
- MODIFIED: agents/context/check-tier0.sh (129% of framework size)
- MODIFIED: agents/context/lib/focus.sh (118% of framework size)
- MODIFIED: agents/context/check-active-task.sh (118% of framework size)
- EXTRA: agents/context/loop-detect.sh (no framework equivalent)
- MODIFIED: agents/context/budget-gate.sh (100% of framework size)
- MODIFIED: agents/context/checkpoint.sh (100% of framework size)
- MODIFIED: agents/task-create/create-task.sh (84% of framework size)
- MODIFIED: agents/task-create/update-task.sh (94% of framework size)
- MODIFIED: agents/fabric/lib/register.sh (73% of framework size)

### Health Score: 38% (13/34 checks passed, 21 issues)

---

## 150-skills-manager

### 1. Context Agent Scripts
- Match: 12/16 | Missing: 0 | Diverged: 4

- DIVERGED: budget-gate.sh (13 lines differ)
- DIVERGED: check-active-task.sh (56 lines differ)
- DIVERGED: checkpoint.sh (37 lines differ)
- DIVERGED: check-tier0.sh (13 lines differ)
- ROGUE: loop-detect.sh (not in framework source)
- ROGUE: termlink-status.sh (not in framework source)

### 2. Claude Settings Hooks
- All required hooks present, correct structure

### 3. Framework Config (.framework.yaml)
- version: 1.3.0 | last_upgrade:  | upgraded_from: 

### 4. Git Hooks
- commit-msg: installed, references framework
- post-commit: installed, references framework
- pre-push: installed, references framework

### 5. Context Directory Health
- working/: exists (17 files)
- project/: exists (11 files)
- episodic/: exists (114 files)
- handovers/: exists (40 files)

### 6. Vendored fw Syntax
- bin/fw: syntax OK

### 7. Rogue File Check
- 20 rogue/modified files detected:

- MODIFIED: lib/inception.sh (98% of framework size)
- MODIFIED: lib/bus.sh (79% of framework size)
- MODIFIED: lib/preflight.sh (98% of framework size)
- MODIFIED: lib/init.sh (96% of framework size)
- EXTRA: agents/telemetry/capture-on-compact.sh (no framework equivalent)
- MODIFIED: agents/termlink/termlink.sh (131% of framework size)
- MODIFIED: agents/audit/self-audit.sh (85% of framework size)
- MODIFIED: agents/audit/audit.sh (102% of framework size)
- MODIFIED: agents/git/lib/hooks.sh (94% of framework size)
- MODIFIED: agents/context/check-tier0.sh (95% of framework size)
- MODIFIED: agents/context/lib/focus.sh (118% of framework size)
- MODIFIED: agents/context/check-active-task.sh (118% of framework size)
- EXTRA: agents/context/loop-detect.sh (no framework equivalent)
- MODIFIED: agents/context/budget-gate.sh (100% of framework size)
- EXTRA: agents/context/termlink-status.sh (no framework equivalent)
- MODIFIED: agents/context/checkpoint.sh (107% of framework size)
- MODIFIED: agents/task-create/create-task.sh (84% of framework size)
- MODIFIED: agents/task-create/update-task.sh (90% of framework size)
- MODIFIED: agents/fabric/lib/register.sh (73% of framework size)
- MODIFIED: agents/healing/lib/diagnose.sh (98% of framework size)

### Health Score: 23% (8/34 checks passed, 26 issues)

---

## 3021-Bilderkarte-tool-llm

### 1. Context Agent Scripts
- Match: 12/16 | Missing: 0 | Diverged: 4

- DIVERGED: budget-gate.sh (13 lines differ)
- DIVERGED: check-active-task.sh (56 lines differ)
- DIVERGED: checkpoint.sh (13 lines differ)
- DIVERGED: check-tier0.sh (13 lines differ)
- ROGUE: loop-detect.sh (not in framework source)

### 2. Claude Settings Hooks
- All required hooks present, correct structure

### 3. Framework Config (.framework.yaml)
- version: 1.3.0 | last_upgrade:  | upgraded_from: 

### 4. Git Hooks
- commit-msg: installed, references framework
- post-commit: installed, references framework
- pre-push: installed, references framework

### 5. Context Directory Health
- working/: exists (10 files)
- project/: exists (7 files)
- episodic/: exists (13 files)
- handovers/: exists (6 files)

### 6. Vendored fw Syntax
- bin/fw: syntax OK

### 7. Rogue File Check
- 22 rogue/modified files detected:

- MODIFIED: lib/inception.sh (98% of framework size)
- MODIFIED: lib/bus.sh (79% of framework size)
- MODIFIED: lib/promote.sh (97% of framework size)
- MODIFIED: lib/preflight.sh (98% of framework size)
- MODIFIED: lib/validate-init.sh (58% of framework size)
- MODIFIED: lib/init.sh (96% of framework size)
- EXTRA: agents/telemetry/capture-on-compact.sh (no framework equivalent)
- MODIFIED: agents/audit/self-audit.sh (85% of framework size)
- MODIFIED: agents/audit/audit.sh (93% of framework size)
- MODIFIED: agents/git/lib/hooks.sh (90% of framework size)
- MODIFIED: agents/context/check-tier0.sh (95% of framework size)
- MODIFIED: agents/context/lib/focus.sh (118% of framework size)
- MODIFIED: agents/context/check-active-task.sh (118% of framework size)
- EXTRA: agents/context/loop-detect.sh (no framework equivalent)
- MODIFIED: agents/context/budget-gate.sh (100% of framework size)
- MODIFIED: agents/context/checkpoint.sh (100% of framework size)
- MODIFIED: agents/task-create/create-task.sh (84% of framework size)
- MODIFIED: agents/task-create/update-task.sh (90% of framework size)
- MODIFIED: agents/fabric/lib/register.sh (53% of framework size)
- MODIFIED: agents/fabric/lib/summary.sh (88% of framework size)
- MODIFIED: agents/healing/lib/diagnose.sh (98% of framework size)
- MODIFIED: bin/watchtower.sh (97% of framework size)

### Health Score: 20% (7/34 checks passed, 27 issues)

---

## 995_2021-kosten

### 1. Context Agent Scripts
- Match: 12/16 | Missing: 0 | Diverged: 4

- DIVERGED: budget-gate.sh (13 lines differ)
- DIVERGED: check-active-task.sh (56 lines differ)
- DIVERGED: checkpoint.sh (13 lines differ)
- DIVERGED: check-tier0.sh (13 lines differ)
- ROGUE: loop-detect.sh (not in framework source)
- ROGUE: termlink-status.sh (not in framework source)

### 2. Claude Settings Hooks
- All required hooks present, correct structure

### 3. Framework Config (.framework.yaml)
- version: 1.3.0 | last_upgrade:  | upgraded_from: 

### 4. Git Hooks
- commit-msg: installed, references framework
- post-commit: installed, references framework
- pre-push: installed, references framework

### 5. Context Directory Health
- working/: exists (8 files)
- project/: exists (7 files)
- episodic/: exists (0 files)
- handovers/: exists (10 files)

### 6. Vendored fw Syntax
- bin/fw: syntax OK

### 7. Rogue File Check
- 20 rogue/modified files detected:

- MODIFIED: lib/inception.sh (98% of framework size)
- MODIFIED: lib/bus.sh (79% of framework size)
- MODIFIED: lib/preflight.sh (98% of framework size)
- MODIFIED: lib/init.sh (96% of framework size)
- EXTRA: agents/telemetry/capture-on-compact.sh (no framework equivalent)
- MODIFIED: agents/termlink/termlink.sh (96% of framework size)
- MODIFIED: agents/audit/self-audit.sh (85% of framework size)
- MODIFIED: agents/audit/audit.sh (93% of framework size)
- MODIFIED: agents/git/lib/hooks.sh (94% of framework size)
- MODIFIED: agents/context/check-tier0.sh (95% of framework size)
- MODIFIED: agents/context/lib/focus.sh (118% of framework size)
- MODIFIED: agents/context/check-active-task.sh (118% of framework size)
- EXTRA: agents/context/loop-detect.sh (no framework equivalent)
- MODIFIED: agents/context/budget-gate.sh (100% of framework size)
- EXTRA: agents/context/termlink-status.sh (no framework equivalent)
- MODIFIED: agents/context/checkpoint.sh (100% of framework size)
- MODIFIED: agents/task-create/create-task.sh (84% of framework size)
- MODIFIED: agents/task-create/update-task.sh (90% of framework size)
- MODIFIED: agents/fabric/lib/register.sh (73% of framework size)
- MODIFIED: agents/healing/lib/diagnose.sh (98% of framework size)

### Health Score: 23% (8/34 checks passed, 26 issues)

---

## openclaw-evaluation

### 1. Context Agent Scripts
- Match: 12/16 | Missing: 0 | Diverged: 4

- DIVERGED: budget-gate.sh (13 lines differ)
- DIVERGED: check-active-task.sh (56 lines differ)
- DIVERGED: checkpoint.sh (13 lines differ)
- DIVERGED: check-tier0.sh (13 lines differ)
- ROGUE: loop-detect.sh (not in framework source)

### 2. Claude Settings Hooks
- All required hooks present, correct structure

### 3. Framework Config (.framework.yaml)
- version: 1.3.0 | last_upgrade:  | upgraded_from: 

### 4. Git Hooks
- commit-msg: installed, references framework
- post-commit: installed, references framework
- pre-push: installed, references framework

### 5. Context Directory Health
- working/: exists (24 files)
- project/: exists (8 files)
- episodic/: exists (16 files)
- handovers/: exists (3 files)

### 6. Vendored fw Syntax
- bin/fw: syntax OK

### 7. Rogue File Check
- 17 rogue/modified files detected:

- MODIFIED: lib/inception.sh (98% of framework size)
- MODIFIED: lib/dispatch.sh (87% of framework size)
- MODIFIED: lib/bus.sh (96% of framework size)
- MODIFIED: lib/init.sh (97% of framework size)
- MODIFIED: agents/termlink/termlink.sh (89% of framework size)
- MODIFIED: agents/audit/self-audit.sh (85% of framework size)
- MODIFIED: agents/audit/audit.sh (93% of framework size)
- MODIFIED: agents/git/lib/hooks.sh (95% of framework size)
- MODIFIED: agents/context/check-tier0.sh (95% of framework size)
- MODIFIED: agents/context/lib/focus.sh (118% of framework size)
- MODIFIED: agents/context/check-active-task.sh (118% of framework size)
- EXTRA: agents/context/loop-detect.sh (no framework equivalent)
- MODIFIED: agents/context/budget-gate.sh (100% of framework size)
- MODIFIED: agents/context/checkpoint.sh (100% of framework size)
- MODIFIED: agents/task-create/create-task.sh (84% of framework size)
- MODIFIED: agents/task-create/update-task.sh (90% of framework size)
- MODIFIED: agents/fabric/lib/register.sh (75% of framework size)

### Health Score: 35% (12/34 checks passed, 22 issues)

---

## termlink

### 1. Context Agent Scripts
- Match: 12/16 | Missing: 0 | Diverged: 4

- DIVERGED: budget-gate.sh (13 lines differ)
- DIVERGED: check-active-task.sh (56 lines differ)
- DIVERGED: checkpoint.sh (13 lines differ)
- DIVERGED: check-tier0.sh (98 lines differ)
- ROGUE: loop-detect.sh (not in framework source)

### 2. Claude Settings Hooks
- All required hooks present, correct structure

### 3. Framework Config (.framework.yaml)
- version: 1.3.0 | last_upgrade:  | upgraded_from: 

### 4. Git Hooks
- commit-msg: installed, references framework
- post-commit: installed, references framework
- pre-push: installed, references framework

### 5. Context Directory Health
- working/: exists (9 files)
- project/: exists (9 files)
- episodic/: exists (269 files)
- handovers/: exists (69 files)

### 6. Vendored fw Syntax
- bin/fw: syntax OK

### 7. Rogue File Check
- No rogue files detected

### Health Score: 85% (29/34 checks passed, 5 issues)

---

## Summary

| Project | Score | Issues | Worst Finding |
|---------|-------|--------|---------------|
| 001-sprechloop | **20%** | 27 | 22 rogue/modified files, loop-detect.sh rogue |
| 050-email-archive | **38%** | 21 | 16 rogue/modified files |
| 150-skills-manager | **23%** | 26 | 20 rogue files + 2 rogue scripts (loop-detect, termlink-status) |
| 3021-Bilderkarte-tool-llm | **20%** | 27 | 22 rogue/modified, validate-init.sh at 58% (stub?) |
| 995_2021-kosten | **23%** | 26 | 20 rogue files + 0 episodic files + 2 rogue scripts |
| openclaw-evaluation | **35%** | 22 | 17 rogue/modified, dispatch.sh diverged (87%) |
| termlink | **85%** | 5 | 0 rogue files — only 4 context script divergences |

**Total projects:** 7 | **Total issues:** 154

## Key Findings

### Universal Issues (all 7 projects)
1. **4 context scripts diverge everywhere**: `budget-gate.sh`, `check-active-task.sh`, `checkpoint.sh`, `check-tier0.sh` — these are the governance-critical hooks
2. **`loop-detect.sh` exists in 7/7 consumers** but NOT in framework source — it was never upstreamed
3. **All on v1.3.0** with empty `last_upgrade`/`upgraded_from` — upgrade metadata never populated

### Critical Drift Patterns
- **`check-active-task.sh`**: 56 lines differ in ALL consumers (118% size = consumers have MORE code than source)
- **`check-tier0.sh`**: Two variants — 4 projects diverge by 13 lines, 2 projects by 98 lines
- **`validate-init.sh`**: 58% of source size in 2 projects — likely a stub overwrite
- **`fabric/lib/register.sh`**: 53-75% of source size across projects — partial implementation

### Healthiest vs Sickest
- **Best: termlink (85%)** — zero rogue .sh files, only the 4 universal context script divergences
- **Worst: 001-sprechloop & 3021-Bilderkarte (20%)** — 22+ rogue files each, including stubs

### Root Cause
The upgrade mechanism (`fw upgrade`) copies files but doesn't track which files changed locally vs upstream. Consumer-side agent sessions modify vendored scripts (adding features like loop-detect, termlink-status) and these never propagate back. The 4 universal context script divergences suggest the framework itself evolved after the last sync.
