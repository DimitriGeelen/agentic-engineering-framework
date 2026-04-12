# T-1139 — Add patch-delivery Type to Pickup Processor

## Problem

`fw pickup process` validates envelope types against a fixed allowlist:
`bug-report|learning|feature-proposal|pattern`. Cross-project patch deliveries
use type `patch-delivery` which is rejected.

## Evidence

- P-015 from 010-termlink (portable date helpers): REJECTED
- P-016 from 010-termlink (session concerns check): REJECTED
- Both contained legitimate patches manually incepted as T-1134 and T-1136

## Fix Design

1. Add `patch-delivery` to validation in lib/pickup.sh:
   - Line 71: add to case statement
   - Line 292: add to --type help text
   - Line 293: add to error message

2. Add processing logic for patch-delivery:
   - Create inception task (not build) with patch details in description
   - Task name: "Pickup: {summary} (from {source.project})"
   - Workflow type: inception (patches need code review)

## Code Locations

- `lib/pickup.sh:71` — validation case
- `lib/pickup.sh:292-293` — send validation
- `lib/pickup.sh:~200` — processing logic (add case for patch-delivery)
