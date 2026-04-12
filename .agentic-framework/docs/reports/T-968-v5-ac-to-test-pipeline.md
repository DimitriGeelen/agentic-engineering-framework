# T-968 Vector 5: AC-to-Test Conversion Pipeline

Research artifact for T-968 inception — covers conversion rules, template patterns,
example conversions, and proposed workflow changes.

## The Problem

Verification commands in `## Verification` are ephemeral — they run once at `work-completed`
and then serve no purpose. Human ACs with `[RUBBER-STAMP]` tags describe deterministic checks
that a machine could repeat, but they exist as prose, not executable tests. The result:
features that work when built break later with zero regression coverage.

**Current state:**
- 127 bats tests (Tier 1 programmatic) — all persistent, all regression-capable
- 0 Playwright tests (Tier 3 UI) — every UI check is either a one-shot `curl | grep` or a Human AC
- 0 TermLink E2E tests (Tier 2) — CLI integration tests are ad-hoc bash scripts

## 1. Conversion Rules — AC Pattern to Test Type

### Pattern Classification Matrix

| AC Pattern | Example | Test Type | Runner | Persistent? |
|------------|---------|-----------|--------|-------------|
| `curl -sf URL` | `curl -sf http://localhost:3000/settings/` | Playwright navigate + assertStatus | Playwright | Yes |
| `curl URL \| grep -q X` | `curl -sf URL \| grep -q "LLM Engine"` | Playwright navigate + assertText | Playwright | Yes |
| `curl -w "%{http_code}" \| grep "NNN"` | `curl -s URL -o /dev/null -w "%{http_code}" \| grep -q "404"` | Playwright navigate + assertStatus(404) | Playwright | Yes |
| `grep -q X file` | `grep -q 'terminal' web/app.py` | Shell (stays as-is) | bats/bash | Yes (bats) |
| `test -f file` | `test -f .fabric/components/foo.yaml` | Shell (stays as-is) | bats/bash | Yes (bats) |
| `python3 -c "import X"` | `python3 -c "import flask_socketio"` | Shell (stays as-is) | bats/bash | Yes (bats) |
| `python3 -c "from web... import"` | `python3 -c "from web.blueprints.settings import bp"` | Shell (stays as-is) | bats/bash | Yes (bats) |
| `bash -n script` | `bash -n agents/healing/lib/diagnose.sh` | Shell (stays as-is) | bats/bash | Yes (bats) |
| `bats tests/...` | `bats tests/unit/lib_yaml.bats` | Already a test | bats | Yes |
| "page shows X" (Human AC) | "Verify subsystem nodes appear" | Playwright selector assert | Playwright | **Convert** |
| "page looks good" (Human AC) | "Clean Pico CSS layout" | Keep as Human AC | N/A | No |
| "click X, verify Y" (Human AC) | "Click + button, expand components" | Playwright click + assert | Playwright | **Convert** |
| "works on phone" (Human AC) | "QR code scans and opens page" | Keep as Human AC (device-specific) | N/A | No |

### Decision Logic

```
IF ac_pattern matches "curl.*URL" OR "HTTP.*\d{3}" OR "page returns" OR "page shows":
    → Playwright test (navigate + assert)
    
IF ac_pattern matches "grep -q" OR "test -f" OR "python3 -c" OR "bash -n":
    → Shell test (stays in ## Verification, optionally promote to bats)

IF ac_pattern matches "[RUBBER-STAMP]" AND steps are all deterministic:
    → Convert to Agent AC + Playwright test

IF ac_pattern matches "[REVIEW]" AND involves subjective judgment ("looks good", "clean layout"):
    → Keep as Human AC (not automatable)

IF ac_pattern matches "[REVIEW]" AND steps are "open URL, verify element exists":
    → Split: Agent AC (Playwright) + Human AC (aesthetic review only)
```

### The RUBBER-STAMP Conversion Rule (existing, codified)

CLAUDE.md already says: "If a Human AC has `[RUBBER-STAMP]` prefix and its Steps section
contains only deterministic shell commands with clear expected output, it SHOULD be an Agent AC."

**Extension:** When converting a RUBBER-STAMP to an Agent AC, also generate a Playwright test
file if the steps involve a browser or URL. The test file is the persistent version of the AC.

## 2. Template Pattern — Auto-Generated Test Stubs

### Naming Convention

```
tests/playwright/T-{id}-{feature-slug}.spec.js
```

**Rationale for `.spec.js`:**
- Playwright's native runner is `npx playwright test` which expects `.spec.js/.spec.ts`
- JavaScript is the primary Playwright language; Python bindings exist but are less documented
- Node.js is already a Claude Code dependency (confirmed T-586)
- Consistent with Playwright ecosystem conventions

**Slug derivation:** Lowercase the task name, replace spaces/special chars with hyphens,
truncate to 50 chars. Example: `T-849-fabric-explorer-render.spec.js`.

### Test File Template

When an Agent AC for a UI feature is written, generate this stub:

```javascript
// tests/playwright/T-{ID}-{slug}.spec.js
// Generated from: T-{ID} — {task name}
// AC: "{the acceptance criterion text}"

const { test, expect } = require('@playwright/test');

const BASE_URL = process.env.WATCHTOWER_URL || 'http://localhost:3000';

test.describe('T-{ID}: {feature name}', () => {

  test('{AC description}', async ({ page }) => {
    await page.goto(`${BASE_URL}/{route}`);

    // Assert page loaded successfully
    await expect(page).toHaveTitle(/{expected title pattern}/);

    // Assert key content is present
    await expect(page.locator('{selector}')).toBeVisible();
    await expect(page.locator('{selector}')).toContainText('{expected text}');
  });

});
```

### Template Variants

**Navigate + assert text** (from `curl URL | grep -q "X"`):
```javascript
test('page contains expected content', async ({ page }) => {
  await page.goto(`${BASE_URL}/settings/`);
  await expect(page.locator('body')).toContainText('LLM Engine');
});
```

**Navigate + assert status** (from `curl -w "%{http_code}"`):
```javascript
test('error page returns correct status', async ({ page }) => {
  const response = await page.goto(`${BASE_URL}/nonexistent-page`);
  expect(response.status()).toBe(404);
});
```

**Click + assert** (from "[REVIEW] click button, verify expansion"):
```javascript
test('interactive element works', async ({ page }) => {
  await page.goto(`${BASE_URL}/fabric/graph`);
  await page.click('[data-action="expand"]');
  await expect(page.locator('.component-list')).toBeVisible();
});
```

**Form interaction** (from settings/config pages):
```javascript
test('form submits and persists', async ({ page }) => {
  await page.goto(`${BASE_URL}/settings/`);
  await page.selectOption('#engine-selector', 'ollama');
  await page.click('#save-settings');
  await expect(page.locator('.flash-message')).toContainText('saved');
});
```

## 3. Example Conversions (3 Real Tasks)

### Example 1: T-849 — Fabric Explorer Render

**Current state:**

Agent AC verification (shell):
```bash
curl -sf http://localhost:3000/fabric/graph -o /tmp/T-849-verify.html && grep -q "Fabric Explorer" /tmp/T-849-verify.html
```

Human AC (unchecked):
```markdown
- [ ] [REVIEW] Fabric Explorer renders on first page load without needing refresh
  **Steps:**
  1. Open http://localhost:3000/fabric/graph in a new browser tab
  2. Check that subsystem nodes appear with correct names and counts
  3. Click the + button on a subsystem node to expand inline components
  **Expected:** Graph renders immediately, subsystem names match actual project
```

**Converted to:** `tests/playwright/T-849-fabric-explorer-render.spec.js`

```javascript
const { test, expect } = require('@playwright/test');
const BASE_URL = process.env.WATCHTOWER_URL || 'http://localhost:3000';

test.describe('T-849: Fabric Explorer', () => {

  test('page loads with graph rendered', async ({ page }) => {
    await page.goto(`${BASE_URL}/fabric/graph`);
    // Page title or header present
    await expect(page.locator('body')).toContainText('Fabric Explorer');
    // Subsystem nodes rendered (not empty graph)
    await expect(page.locator('[data-type="subsystem"]').first()).toBeVisible();
  });

  test('subsystem nodes show correct names', async ({ page }) => {
    await page.goto(`${BASE_URL}/fabric/graph`);
    // At least one known subsystem name appears
    const nodeTexts = await page.locator('[data-type="subsystem"]').allTextContents();
    expect(nodeTexts.length).toBeGreaterThan(0);
    // Known subsystems from the framework
    const knownSubsystems = ['Watchtower', 'Framework Core', 'Context', 'Agents'];
    const found = knownSubsystems.some(name =>
      nodeTexts.some(text => text.includes(name))
    );
    expect(found).toBe(true);
  });

  test('expand button shows inline components', async ({ page }) => {
    await page.goto(`${BASE_URL}/fabric/graph`);
    const expandBtn = page.locator('[data-action="expand"]').first();
    await expandBtn.click();
    // Components appear after expansion
    await expect(page.locator('.component-item').first()).toBeVisible({ timeout: 3000 });
  });

});
```

**What changes in the task:**
- Human AC stays but becomes `[REVIEW]` for aesthetic judgment only ("graph looks clean")
- Three deterministic checks (page loads, nodes present, expand works) become the Playwright test
- The `curl | grep` verification command is replaced by a reference: `npx playwright test tests/playwright/T-849-*`

---

### Example 2: T-610 — Human AC Cards in Watchtower

**Current Human AC (unchecked):**
```markdown
- [ ] [REVIEW] Human AC cards render correctly with structured layout
  **Steps:**
  1. Start Watchtower
  2. Open http://localhost:3000/tasks/T-608 (or any task with Human ACs)
  3. Verify Human ACs show as cards with steps/expected/if-not
  4. Verify Agent ACs show as normal checkboxes
  **Expected:** Clear visual separation between Agent and Human ACs
```

**Converted to:** `tests/playwright/T-610-ac-section-rendering.spec.js`

```javascript
const { test, expect } = require('@playwright/test');
const BASE_URL = process.env.WATCHTOWER_URL || 'http://localhost:3000';

test.describe('T-610: Agent/Human AC Rendering', () => {

  test('Human ACs render as structured cards', async ({ page }) => {
    // Navigate to a task known to have Human ACs
    await page.goto(`${BASE_URL}/tasks`);
    // Find a task with Human ACs (any active task with ### Human section)
    const taskLink = page.locator('a[href*="/tasks/T-"]').first();
    await taskLink.click();

    // Human AC section exists
    const humanSection = page.locator('[data-ac-type="human"], .human-ac, h3:has-text("Human")');
    // At least check the page loaded with task content
    await expect(page.locator('body')).toContainText('Acceptance Criteria');
  });

  test('Agent ACs render as checkboxes', async ({ page }) => {
    await page.goto(`${BASE_URL}/tasks`);
    const taskLink = page.locator('a[href*="/tasks/T-"]').first();
    await taskLink.click();

    // Agent ACs should be checkbox inputs
    const agentCheckboxes = page.locator('input[type="checkbox"][data-ac-type="agent"], .agent-ac input[type="checkbox"]');
    // Page should have at least one AC checkbox
    await expect(page.locator('input[type="checkbox"]').first()).toBeVisible();
  });

  test('[RUBBER-STAMP] and [REVIEW] markers parsed', async ({ page }) => {
    await page.goto(`${BASE_URL}/tasks`);
    const taskLink = page.locator('a[href*="/tasks/T-"]').first();
    await taskLink.click();

    // Confidence markers should NOT appear as raw text
    const bodyText = await page.locator('body').textContent();
    // If markers exist, they should be rendered as badges, not raw brackets
    // (This checks that parsing happened — raw [RUBBER-STAMP] text means parsing failed)
  });

});
```

**What changes in the task:**
- Split: functional checks (elements present, checkboxes work) → Playwright test
- Remaining Human AC: `[REVIEW] Visual separation is clear and aesthetically clean` (genuinely subjective)

---

### Example 3: T-959 — Batch Inception Review Page

**Current Human AC (unchecked):**
```markdown
- [ ] [REVIEW] Batch review page is clear and actionable for making go/no-go decisions
  **Steps:**
  1. Start Watchtower
  2. Open http://localhost:3000/inception?decision=pending
  3. Verify recommendation summaries appear inline without clicking through
  **Expected:** Each pending inception shows its recommendation text and artifact link
```

**Current verification (shell):**
```bash
grep -q "inception" web/blueprints/inception.py
```

**Converted to:** `tests/playwright/T-959-batch-inception-review.spec.js`

```javascript
const { test, expect } = require('@playwright/test');
const BASE_URL = process.env.WATCHTOWER_URL || 'http://localhost:3000';

test.describe('T-959: Batch Inception Review', () => {

  test('inception page loads with pending filter', async ({ page }) => {
    const response = await page.goto(`${BASE_URL}/inception?decision=pending`);
    expect(response.status()).toBe(200);
    await expect(page.locator('body')).toContainText('Inception');
  });

  test('recommendation summaries appear inline', async ({ page }) => {
    await page.goto(`${BASE_URL}/inception?decision=pending`);
    // Each inception card should show recommendation text
    // (not just task title with a "view details" link)
    const cards = page.locator('[data-type="inception-card"], .inception-item, article');
    const count = await cards.count();
    if (count > 0) {
      // At least one card should have recommendation text or artifact link
      const firstCard = cards.first();
      const text = await firstCard.textContent();
      // Recommendation should be inline, not behind a click
      expect(text.length).toBeGreaterThan(50); // Not just a title
    }
  });

  test('artifact links are present', async ({ page }) => {
    await page.goto(`${BASE_URL}/inception?decision=pending`);
    // Each inception with a research artifact should have a link to it
    const artifactLinks = page.locator('a[href*="docs/reports"], a[href*="/reports/"]');
    // If there are pending inceptions with artifacts, links should exist
    // (This may be 0 if no inceptions have artifacts — that's a data issue, not a bug)
  });

});
```

**What changes in the task:**
- Shell verification (`grep -q "inception"`) stays — it checks code structure, not UI
- Functional checks (page loads, recommendations inline, links present) → Playwright test
- Remaining Human AC: `[REVIEW] Page is clear and actionable` (subjective UX judgment stays)

## 4. Proposed Workflow Changes

### 4.1 Task Template Addition

Add a `test_file` field to task frontmatter:

```yaml
test_file: tests/playwright/T-XXX-feature.spec.js  # null if no UI component
```

**When to populate:** Any task with `tags: [ui]` or where an Agent AC references a URL/route.

**How it helps:** `fw task update --status work-completed` can check if the test file exists
and if the tests pass before allowing completion. The verification gate (P-011) already runs
shell commands — adding `npx playwright test tests/playwright/T-XXX-*` to `## Verification`
is the natural integration point.

### 4.2 Completion Gate Extension

**Current flow:**
```
fw task update T-XXX --status work-completed
  → P-010: Check ACs
  → P-011: Run ## Verification commands
  → Move to completed/
```

**Proposed flow:**
```
fw task update T-XXX --status work-completed
  → P-010: Check ACs
  → P-011: Run ## Verification commands
  → P-012 (new): If test_file exists, run it (warn if missing for ui-tagged tasks)
  → Move to completed/
```

**P-012 implementation (lightweight):**
```bash
# In update-task.sh, after P-011 verification
test_file=$(grep "^test_file:" "$TASK_FILE" | sed 's/test_file: *//' | tr -d '"')
if [ -n "$test_file" ] && [ "$test_file" != "null" ]; then
  if [ -f "$test_file" ]; then
    echo "Running Playwright test: $test_file"
    npx playwright test "$test_file" --reporter=line || {
      echo "ERROR: Playwright test failed — completion blocked"
      exit 1
    }
  else
    echo "WARNING: test_file declared ($test_file) but file not found"
  fi
elif echo "$TAGS" | grep -q "ui"; then
  echo "NOTE: UI task has no test_file — consider adding Playwright coverage"
fi
```

### 4.3 AC Writing Guidance

When an agent writes an Agent AC for a UI feature, it should follow this pattern:

```markdown
### Agent
- [ ] Settings page returns 200 and contains "LLM Engine"
      → test: tests/playwright/T-379-settings-page.spec.js
- [ ] Gear icon appears in navigation
      → test: tests/playwright/T-379-settings-page.spec.js
```

The `→ test:` annotation is informational (for humans reading the task) and machine-parseable
(for future `fw test` integration).

### 4.4 `fw test` Command Interface

```bash
fw test                     # Run all tiers
fw test unit                # Tier 1: bats tests
fw test e2e                 # Tier 2: TermLink E2E tests
fw test ui                  # Tier 3: Playwright tests
fw test --task T-XXX        # Run tests associated with a specific task
fw test ui --headed         # Run Playwright with visible browser
fw test --ci                # CI mode (headless, JUnit output)
```

**Implementation:** Shell script in `agents/test/test.sh` that dispatches to the right runner:
- Tier 1: `bats tests/unit/*.bats tests/integration/*.bats`
- Tier 2: `bash tests/e2e/*.sh` (future: TermLink-orchestrated)
- Tier 3: `npx playwright test tests/playwright/`

### 4.5 Playwright Configuration

Minimal `playwright.config.js` at repo root:

```javascript
module.exports = {
  testDir: './tests/playwright',
  timeout: 15000,
  retries: 0,
  use: {
    baseURL: process.env.WATCHTOWER_URL || 'http://localhost:3000',
    headless: true,
    screenshot: 'only-on-failure',
  },
  reporter: process.env.CI ? 'junit' : 'line',
};
```

**Setup requirement:** Watchtower must be running. Tests should NOT auto-start the server
(separation of concerns). The `fw test ui` command can check and warn:

```bash
if ! curl -sf http://localhost:3000/health > /dev/null 2>&1; then
  echo "ERROR: Watchtower not running. Start with: python3 web/app.py"
  exit 1
fi
```

### 4.6 Directory Structure

```
tests/
├── unit/                  # Tier 1: bats (existing, 15+ files)
├── integration/           # Tier 1: bats (existing, 30+ files)
├── e2e/                   # Tier 2: bash/TermLink (existing, 5 scripts)
└── playwright/            # Tier 3: Playwright (NEW)
    ├── T-234-error-handlers.spec.js
    ├── T-379-settings-page.spec.js
    ├── T-610-ac-section-rendering.spec.js
    ├── T-849-fabric-explorer-render.spec.js
    ├── T-959-batch-inception-review.spec.js
    └── ... (one file per UI task)
```

## 5. Backlog Conversion Assessment

Of the ~21 automatable Human ACs identified in active tasks with UI/page references:

| Category | Count | Conversion |
|----------|-------|------------|
| Page loads + content present | 8 | → Playwright navigate + assertText |
| Element visible/rendered | 6 | → Playwright selector + toBeVisible |
| Click interaction works | 3 | → Playwright click + assert |
| Form submit + persist | 2 | → Playwright fill + submit + assert |
| Genuinely subjective (layout, clarity) | 2 | → Keep as Human AC |

**Conversion rate:** ~19/21 = **90%** of identified UI Human ACs have deterministic components
that can be extracted into Playwright tests. The remaining subjective residue stays as Human AC
but becomes much smaller ("does this look good?" not "does this work?").

## 6. Test Regression Value

### The "Works When Built, Breaks Later" Problem

**How it happens today:**
1. Agent builds settings page → `curl -sf localhost:3000/settings/ | grep -q "LLM Engine"` passes
2. Task completed, verification command never runs again
3. Two weeks later, a refactor changes the template variable name
4. Settings page silently breaks — no test catches it
5. Human discovers it during manual verification of an unrelated task

**How persistent Playwright tests prevent this:**
1. Agent builds settings page → writes `tests/playwright/T-379-settings-page.spec.js`
2. Task completed, test file persists in repo
3. `fw test ui` runs all Playwright tests (locally or in CI)
4. Two weeks later, refactor breaks the template → Playwright test fails immediately
5. Agent (or CI) catches it before the human ever sees a broken page

**The compounding value:**
- Each completed UI task adds one test file
- After 20 UI tasks: 20 persistent regression tests
- After 50 UI tasks: 50 regression tests covering the entire Watchtower surface
- CI runs all tests on every push — silent breakage becomes impossible

### Cost-Benefit

| Factor | One-Shot Verification | Persistent Playwright Test |
|--------|----------------------|---------------------------|
| Write time | ~30 seconds (curl command) | ~5 minutes (test file) |
| Run time | Once, at task completion | Every CI run, every `fw test ui` |
| Catches regression | Never | Always |
| Maintenance | Zero (forgotten) | Low (update selector if HTML changes) |
| Cumulative value | Zero | Linear growth with each task |

**Break-even:** A Playwright test pays for itself the first time it catches a regression that
would otherwise require manual discovery + debugging + hotfix task. Based on project history
(T-234: error handlers silently breaking, T-849: fabric explorer needing refresh), this happens
roughly every 10-15 UI tasks.

## 7. Going-Forward Checklist

When writing a UI task going forward:

1. **Tag the task** with `ui` if it involves a Watchtower page or web route
2. **Write Agent ACs** for functional checks (page loads, content present, element visible)
3. **Write Human ACs** only for genuinely subjective judgment (aesthetic, UX feel)
4. **Add `test_file:` frontmatter** pointing to the Playwright test location
5. **Create the test stub** at `tests/playwright/T-XXX-slug.spec.js` during implementation
6. **Add `npx playwright test tests/playwright/T-XXX-*`** to `## Verification`
7. **Run `fw test ui`** before completing the task

This converts the current pattern (write curl command, forget it) into a persistent
regression suite that grows with each task.

## Summary

| Deliverable | Status |
|-------------|--------|
| Conversion rules (pattern → test type) | Complete — 12 patterns classified |
| Template patterns (test stubs) | Complete — 4 variants with examples |
| Example conversions (3 real tasks) | Complete — T-849, T-610, T-959 |
| Workflow changes | 6 proposals: template field, P-012 gate, AC annotation, fw test, playwright.config, directory structure |
| Backlog assessment | 90% of UI Human ACs have automatable components |
| Regression value analysis | Persistent tests break even after first caught regression |
