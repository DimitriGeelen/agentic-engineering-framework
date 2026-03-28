# T-589: YAML/JSON Fuzz Testing — Security Fuzzing for Framework Parsing Surfaces

## Problem Statement

The framework processes YAML frontmatter from task files, component cards, config files, and skill files with zero fuzz coverage. An attacker (or a malicious agent) could craft YAML content that exploits parsing vulnerabilities. OpenClaw has 548 LOC of dedicated fuzz tests covering 6 attack vector categories.

## Parsing Surface Inventory

### Python YAML Parsing (53 files use `import yaml`)

**All use `yaml.safe_load()`** — the safe parser. This is the most important finding. `yaml.safe_load()` prevents:
- Arbitrary Python object instantiation (`!!python/object`)
- Code execution via constructors
- Most deserialization attacks

**Security-relevant Python parsing:**
- `web/blueprints/tasks.py` — parses task YAML frontmatter from user-visible files
- `web/blueprints/approvals.py` — parses approval YAML (agent-written)
- `web/shared.py` — common YAML parsing utilities
- `web/config.py` — framework configuration
- `agents/audit/audit.sh` (via embedded Python) — parses all YAML in `.context/`

### Bash YAML Parsing (10+ files)

Bash scripts use `grep`, `sed`, `awk` for YAML field extraction — NOT a YAML parser. This is inherently limited but also inherently safe against structured attacks.

**Pattern:** `grep '^status:' "$file" | head -1 | sed 's/status:[[:space:]]*//'`

**Vulnerable to:** Malformed frontmatter causing incorrect field extraction (e.g., YAML with duplicate keys, multiline values, anchors). NOT vulnerable to: code execution, object instantiation.

### JSON Parsing

Python `json.loads()` in budget-gate.sh (via embedded Python), Watchtower API endpoints. JSON parsing is well-understood and safe in Python's standard library.

## Attack Vector Analysis

### YAML-Specific Attacks

| Attack | Risk with safe_load | Risk with grep/sed |
|--------|---------------------|---------------------|
| Billion Laughs (entity expansion) | BLOCKED by safe_load | N/A (no YAML parser) |
| Arbitrary object instantiation | BLOCKED by safe_load | N/A |
| Merge key abuse (`<<:`) | Parsed but harmless | Ignored |
| Anchor/alias bombs | safe_load has recursion limits | N/A |
| Unicode normalization attacks | Possible data confusion | Possible data confusion |
| Duplicate key confusion | Last-value-wins (Python dict) | First-match-wins (grep) |
| YAML multiline injection | Possible field confusion | Possible field confusion |
| Newline in single-line value | Possible truncation | First-line-wins (grep) |

### Highest Risk: Duplicate Key Divergence

Python `yaml.safe_load()` and bash `grep` handle duplicate keys differently:
- Python: last value wins
- Bash grep: first match wins

If an attacker adds `status: started-work` ABOVE the real `status: captured` in frontmatter, bash scripts see "started-work" while Python sees "captured". This could bypass the task gate.

**Mitigation:** Framework convention puts frontmatter between `---` markers. Scripts extract from this bounded section. Real risk is LOW because task files are written by the framework, not user-supplied.

### Moderate Risk: Multiline Value Confusion

YAML multiline syntax (`>`, `|`, `>-`) can cause field values to span lines. Bash `grep '^field:'` gets only the first line; Python gets the full value.

**Mitigation:** Framework YAML uses simple `key: value` format by convention. Complex values are rare.

## Recommendation: NO-GO

**The attack surface is smaller than expected:**

1. All Python parsing uses `yaml.safe_load()` — the most critical defense is already in place
2. Bash parsing is grep-based — inherently immune to structured YAML attacks
3. Task files are framework-generated, not user-supplied — the primary input is trusted
4. The one real risk (duplicate key divergence) is theoretical and convention-mitigated

**Effort vs value:** Building a 500+ LOC fuzz test suite for a low-risk surface is not justified. The framework's YAML parsing is already defensively positioned.

**Better investment:** Add a single validation to task creation that rejects duplicate frontmatter keys. This addresses the one real risk for ~20 LOC.

## Dialogue Log

- Research conducted by scanning all YAML parsing surfaces in the codebase
- Compared against OpenClaw's 6 attack vector categories
- No human dialogue — agent-driven inception
