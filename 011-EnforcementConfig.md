# Task Enforcement Configuration
# See docs/TASK_SYSTEM.md for full specification

# Tier 0: Actions that ALWAYS require task context, no bypass possible
unconditional_enforcement:
  description: "Consequential actions — no bypass regardless of authority level"
  action_patterns:
    - "deploy-to-production"
    - "delete-*"
    - "destroy-*"
    - "modify-firewall-*"
    - "modify-secrets-*"
    - "database-migrate"
  behavior: |
    If human attempts bypass, offer quick task creation.
    Never proceed without task context.

# Tier 1: Default — all actions require task context
default_enforcement:
  enabled: true
  on_violation: block_and_offer
  offer_options:
    - create_new_task
    - attach_to_existing_task
    - request_human_bypass

# Tier 2: Situational bypass — configured at runtime by human
situational_bypass:
  enabled: true
  scope: single_use          # Each bypass applies to one action only
  logging: mandatory          # Always log: who, when, why, what
  retroactive_task: true      # Create placeholder task for documentation debt
  agent_can_request: true     # Agent may request bypass, human decides

# Tier 3: Pre-approved exceptions (ITIL Standard Change equivalent)
pre_approved_categories:
  - name: read-only-diagnostics
    description: "Non-mutating system inspection commands"
    commands:
      - system-health-check
      - docker-ps
      - git-status
      - git-log
      - env-info
      - disk-usage
      - network-status
    rationale: "No state change, no traceability risk"
    approved_by: "human"
    approved_date: 2026-02-13
    review_date: 2026-05-13

  - name: context-queries
    description: "Querying the framework's own state"
    commands:
      - task-list
      - task-status
      - context-show
      - skill-list
    rationale: "Meta-operations about the framework itself"
    approved_by: "human"
    approved_date: 2026-02-13
    review_date: 2026-05-13
