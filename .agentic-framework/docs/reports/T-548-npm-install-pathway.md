# T-548: npm Install Pathway — Research Artifact

## Problem Statement

Should the framework offer `npm install -g @agentic/framework` (or `npx`) as an installation pathway alongside the existing `install.sh` and Homebrew tap?

**For whom:** Node.js/TypeScript developers who prefer npm for tool installation.
**Why now:** T-586 (Language strategy) decided GO on TypeScript adoption for new components. If the framework is gaining TS components, npm packaging becomes a natural question.

## Current Installation Methods

| Method | Command | Platform | Status |
|--------|---------|----------|--------|
| install.sh | `curl -sSL https://... \| bash` | Linux/macOS | Active |
| git clone | `git clone` + `./install.sh` | All | Active |
| Homebrew | `brew install DimitriGeelen/termlink/termlink` | macOS | TermLink only |
| fw upgrade | `fw upgrade` (within consumer projects) | All | Active |

## Analysis

### What npm Would Give Us

1. **Package versioning** — `package.json` declares version, npm handles semver
2. **Update mechanism** — `npm update -g @agentic/framework`
3. **Cross-platform bin** — `npx` resolves to correct binary on Windows/Linux/macOS
4. **Discovery** — npmjs.com search, README, badges

### What npm Would Cost

1. **Runtime dependency** — Framework is bash + Python. Adding npm requires Node.js runtime on every machine.
2. **Packaging complexity** — bash scripts don't naturally fit npm's module resolution. Would need `bin` entries pointing to shell scripts, `postinstall` hooks, platform-specific handling.
3. **Identity contradiction** — The framework's positioning is "anti-enterprise stack" (T-470). npm is the canonical enterprise JS packaging tool. The audience that resonates with "bash, YAML, and files" is not the audience that reaches for npm first.
4. **Maintenance burden** — npm publish workflow, CI for npmjs, version sync between git tags and npm versions, security advisories.
5. **Dual-path complexity** — Two installation paths means two upgrade paths, two bug surfaces, two sets of "works on my machine" issues.

### Evidence from Current Users

- Framework runs on Linux servers (`.107` Mac, LXC containers, Proxmox VMs)
- All known installations use `install.sh` or `git clone`
- No user has requested npm packaging
- Consumer projects are not Node.js projects (Bilderkarte is Python/Flask, TermLink is Rust, email-archive is Python)

### Comparison: npm CLI Packaging Patterns

Tools like `eslint`, `prettier`, `typescript` use npm because they ARE JavaScript. Tools like `gh` (GitHub CLI), `terraform`, `kubectl` distribute via platform-native packages (Homebrew, apt, binary download) because they're NOT JavaScript.

The framework falls squarely in the second category — it's bash + Python, not JavaScript. Packaging it in npm would be like packaging `terraform` via npm: technically possible, but the wrong distribution channel for the tool's identity.

## Recommendation: NO-GO

**Rationale:**
1. No evidence of demand (zero user requests, no Node.js consumer projects)
2. Contradicts positioning — the framework's value proposition is its anti-enterprise simplicity
3. Runtime dependency addition — requiring Node.js for a bash framework is architecturally incoherent
4. Maintenance cost exceeds value — dual-path installation complexity for an audience that doesn't exist yet
5. Existing alternatives work — `install.sh` is a one-liner, Homebrew tap exists for macOS

**If circumstances change:** Revisit if (a) the framework gains substantial TypeScript components (T-586 build), AND (b) users request npm installation, AND (c) the audience shifts toward Node.js developers. Until then, `install.sh` + Homebrew is sufficient.
