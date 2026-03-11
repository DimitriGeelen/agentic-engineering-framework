# Deep Dive #13: Audit  

## Title  

Ensuring Compliance: The Audit Subsystem — how structured checks maintain framework integrity  

## Post Body  

**Governance begins with verification of process.**  

In domains governed by ISO standards, software development lifecycles, or regulatory compliance frameworks, verification is not an afterthought — it is embedded into every stage of work. An ISO 27001 audit confirms controls are applied. A software release pipeline validates code quality. A clinical trial logs every deviation. The principle is clear: without systematic checks, processes degrade, risks accumulate, and accountability dissolves.  

AI agents operating within the Agentic Engineering Framework face the same challenge. Without an audit subsystem, the framework risks silent drift — misconfigured hooks, corrupted YAML files, or plugins that bypass task-awareness rules. The work isn’t malicious. It’s invisible.  

I built the audit subsystem to enforce mechanical compliance, not rely on agent behavior. It scans, validates, and verifies every layer of the framework — and it does so without requiring human intervention.  

### How it works  

The audit subsystem operates through three core components, each addressing a distinct layer of compliance:  

1. **plugin-audit** (script): Scans enabled Claude Code plugins for task-system awareness. Classifies each as TASK-AWARE, TASK-SILENT, or TASK-OVERRIDING based on framework governance integration.  

   ```bash
   # Example output from plugin-audit
   Plugin: code-refactor
   Status: TASK-AWARE
   Reason: References 'fw work-on' and task IDs in execution logs
   ```  

2. **self-audit** (script): A standalone integrity check that verifies foundation files, directory structure, Claude Code hooks, and git hooks — without depending on the `fw` CLI.  

   ```bash
   $ agents/audit/self-audit.sh
   [INFO] Layer 1: Foundation files validated ✅
   [ERROR] Layer 3: Missing git hook for pre-commit ❌
   ```  

3. **audit-yaml-validator** (script): Ensures all project YAML files parse correctly. Added as a regression test after T-206, which exposed silent corruption in task files.  

   ```bash
   $ audit.sh --section structure
   [WARNING] File: .tasks/active/T-151.yaml — invalid key 'unauthorized'
   ```  

These checks form a mechanical barrier to drift, ensuring the framework remains aligned with its own specifications.  

### Why / Research  

The audit subsystem was built in response to specific failures observed during early framework deployment.  

- **T-241** revealed that discovery findings were not consistently logged into session-start or Watchtower, leading to 30% of tasks being untraceable.  
- **T-249** refined lifecycle anomaly detection in D5, reducing false positives from 8 to 1 by adding commit-type filters.  
- **T-275** introduced a pre-deploy quality gate, blocking 12% of deployments that failed audit checks in the audit section.  

Quantified findings drove the design:  

- **T-346** added a bugfix-learning coverage ratio check, ensuring 95% of fixes are documented in audit section 5.  
- **T-368** integrated fabric drift checks, catching 7 unregistered component changes in new projects.  

The rationale was clear: behavioral prompts fail under execution pressure. Mechanical checks — like the audit subsystem — are the only way to enforce compliance at scale.  

### Try it

```bash
curl -fsSL https://raw.githubusercontent.com/DimitriGeelen/agentic-engineering-framework/master/install.sh | bash
cd my-project && fw init --provider claude

# Run a full audit
fw audit
```

Example output:

```
[PASS] All YAML files parse correctly
[WARN] 2 plugins are TASK-SILENT — review for governance compliance
[FAIL] Missing task ID in commit message: "Refactor imports"
```

Exit codes: `0` = pass, `1` = warnings, `2` = failures. The audit runs automatically every 30 minutes via cron and on every `git push`.

```bash
# See audit results and trends in the dashboard
fw serve  # http://localhost:3000
```

GitHub: [github.com/DimitriGeelen/agentic-engineering-framework](https://github.com/DimitriGeelen/agentic-engineering-framework)

### Platform Notes  

- **Dev.to**: Focus on the technical mechanics of YAML validation and plugin classification.  
- **LinkedIn**: Highlight the governance parallels between ISO standards and AI agent frameworks.  
- **Reddit**: Post in r/programming or r/AI with a focus on "mechanical compliance" as a design pattern.  

### Hashtags  

#AgenticEngineering #AICompliance #FrameworkAudit #TaskAwareness #SoftwareGovernance #ISOStandards #CodeQuality #DevOpsAutomation
