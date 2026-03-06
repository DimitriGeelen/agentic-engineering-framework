# T-329: Pending Article Corrections

From 5-agent qualitative review (`docs/reports/T-329-article-review.md`).

## Applied
- [x] #1: Frontmatter four→five mismatch
- [x] #16: Expand provider support — built with/tested against Claude Code

## Remaining

### Critical
- [ ] #3: "No session ends in an unrecoverable state" — absolute guarantee contradicts alpha caveat. Rewrite to describe mechanism, not guarantee.
- [ ] #4: Task count accuracy — verify actual completed count (article says 325)

### Tone
- [ ] #11: Copywriting staccato breaks (lines 34, 36, 171) — "Not guidelines. Not best practices. Enforcement." reads as landing page, not practitioner voice
- [ ] #12: "The framework learns from its own history" — anthropomorphizes. It stores and surfaces patterns; the human learns.
- [ ] #14: "96% commit traceability" — add methodology: "across the full task history" or specify denominator

### High-Value Improvements
- [ ] #5: Consider swapping sections — "How it works in practice" (concrete) before "The authority model" (abstract)
- [ ] #6: Opening buries the tool — Shell backstory before any mention of AI agents
- [ ] #7: "Context Fabric" / "Component Fabric" used before defined — add parenthetical on first table use
- [ ] #8: Enforcement asymmetry — article implies all agents get hook interception (only Claude Code does)
- [ ] #9: Add transition sentences between sections
- [ ] #10: Reorder "Where it stands" — evidence first, caveats second, invitation third

### Completeness (optional, ~150 words)
- [ ] #15: Team usage / CI/CD — article reads as solo-dev story
- [ ] #17: No prerequisites in install section — bash 4+, Python, what fw init creates
