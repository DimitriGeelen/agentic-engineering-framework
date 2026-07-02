#!/usr/bin/env python3
"""
Escalation-scan auto-tuning: rule lifecycle management cron job.

Manages exclusion rule lifecycle:
- Activates dry-run rules after 7 days (when activates timestamp passes)
- Checks reconfirmation: ≥3 new FPs matching pattern extend expires by 30d
- Expires active rules after 30 days (or longer if reconfirmed)
- Sends ntfy notifications on activation

Usage:
    python3 tools/escalation-rule-lifecycle.py [--dry-run]

Designed to run daily via cron.

Origin: T-2496 (escalation-scan auto-tuning feedback loop, T-1687 grilling session)
"""

import argparse
import sys
import yaml
from pathlib import Path
from datetime import datetime, timedelta, timezone
import subprocess

ROOT = Path(__file__).resolve().parent.parent
RULES_FILE = ROOT / ".context" / "working" / "escalation-exclusion-rules.yaml"
VERDICTS_FILE = ROOT / ".context" / "working" / "escalation-drift-LATEST-v0.5.yaml"

# Reconfirmation threshold: ≥3 new FPs extend expiry
RECONFIRM_THRESHOLD = 3
# Expiry extension: 30 days
EXPIRY_EXTENSION_DAYS = 30


def load_rules():
    """Load exclusion rules from YAML."""
    if not RULES_FILE.exists():
        return None

    with RULES_FILE.open() as f:
        data = yaml.safe_load(f)
    return data


def load_verdicts():
    """Load recent verdicts for reconfirmation check."""
    if not VERDICTS_FILE.exists():
        return []

    with VERDICTS_FILE.open() as f:
        data = yaml.safe_load(f)
    return data.get('candidates', [])


def check_reconfirmation(rule, verdicts):
    """
    Check if rule has ≥3 new false_positive verdicts matching its pattern.

    Returns: number of matching FPs found
    """
    pattern_attrs = rule.get('attributes', {})
    last_check = rule.get('last_reconfirm_check')

    # Parse last check timestamp
    if last_check:
        try:
            last_check_dt = datetime.fromisoformat(last_check.replace('Z', '+00:00'))
        except:
            last_check_dt = None
    else:
        last_check_dt = None

    # Count FPs that match this rule's pattern
    matches = 0
    for verdict in verdicts:
        if verdict.get('verdict') != 'false_positive':
            continue

        # Check timestamp - only count verdicts after last check
        if last_check_dt:
            try:
                verdict_ts = datetime.fromisoformat(verdict.get('ts', '').replace('Z', '+00:00'))
                if verdict_ts <= last_check_dt:
                    continue
            except:
                continue

        # Check if verdict matches rule pattern
        name = verdict.get('name', '')
        rationale = verdict.get('rationale', '')

        matches_pattern = True
        for attr_name, attr_value in pattern_attrs.items():
            if attr_name == 'title':
                if attr_value.lower() not in name.lower():
                    matches_pattern = False
                    break
            elif attr_name == 'body':
                # Check rationale for body patterns
                if attr_value == 'no-code-changes' and 'no code changes' not in rationale.lower():
                    matches_pattern = False
                    break
                elif attr_value == 'doc-edit' and 'doc edit' not in rationale.lower():
                    matches_pattern = False
                    break
                elif attr_value == 'existing-rca' and 'existing rca' not in rationale.lower():
                    matches_pattern = False
                    break
                elif attr_value == 'refactor' and 'refactor' not in rationale.lower():
                    matches_pattern = False
                    break

        if matches_pattern:
            matches += 1

    return matches


def process_rules(data, verdicts, dry_run=False):
    """
    Process rule lifecycle transitions.

    Returns: dict with actions taken
    """
    now = datetime.now(timezone.utc)
    actions = {
        'activated': [],
        'reconfirmed': [],
        'expired': [],
    }

    rules = data.get('rules', [])
    for rule in rules:
        status = rule.get('status')
        pattern = rule.get('pattern', 'unknown')

        # Activation: dry-run → active when activates timestamp passes
        if status == 'dry-run':
            activates_str = rule.get('activates')
            if activates_str:
                try:
                    activates = datetime.fromisoformat(activates_str.replace('Z', '+00:00'))
                    if now >= activates:
                        if not dry_run:
                            rule['status'] = 'active'
                            # Set initial expires = now + 30 days
                            rule['expires'] = (now + timedelta(days=30)).isoformat()
                        actions['activated'].append(pattern)
                except:
                    pass

        # Reconfirmation: check for new FPs matching pattern
        elif status == 'active':
            reconfirm_count = check_reconfirmation(rule, verdicts)
            if reconfirm_count >= RECONFIRM_THRESHOLD:
                if not dry_run:
                    # Extend expiry by 30 days
                    current_expires = rule.get('expires')
                    if current_expires:
                        try:
                            expires_dt = datetime.fromisoformat(current_expires.replace('Z', '+00:00'))
                        except:
                            expires_dt = now
                    else:
                        expires_dt = now

                    new_expires = expires_dt + timedelta(days=EXPIRY_EXTENSION_DAYS)
                    rule['expires'] = new_expires.isoformat()
                    rule['last_reconfirm_check'] = now.isoformat()
                actions['reconfirmed'].append((pattern, reconfirm_count))

            # Expiry: active → expired when expires timestamp passes
            expires_str = rule.get('expires')
            if expires_str:
                try:
                    expires = datetime.fromisoformat(expires_str.replace('Z', '+00:00'))
                    if now >= expires:
                        if not dry_run:
                            rule['status'] = 'expired'
                        actions['expired'].append(pattern)
                except:
                    pass

    return actions


def send_notification(message):
    """Send ntfy notification via fw notify."""
    try:
        subprocess.run(
            ['bin/fw', 'notify', '--message', message, '--category', 'framework'],
            cwd=ROOT,
            check=False,
            capture_output=True
        )
    except:
        pass  # Notification failure should not fail the job


def save_rules(data):
    """Save updated rules back to YAML."""
    with RULES_FILE.open('w') as f:
        yaml.dump(data, f, default_flow_style=False, sort_keys=False)


def main():
    parser = argparse.ArgumentParser(
        description='Escalation-scan rule lifecycle management'
    )
    parser.add_argument(
        '--dry-run',
        action='store_true',
        help='Show what would change without modifying files'
    )

    args = parser.parse_args()

    # Load rules and verdicts
    data = load_rules()
    if not data:
        print("No rules file found - nothing to do")
        return 0

    verdicts = load_verdicts()

    # Process lifecycle transitions
    actions = process_rules(data, verdicts, dry_run=args.dry_run)

    # Report actions
    if actions['activated']:
        print(f"Activated {len(actions['activated'])} rule(s):")
        for pattern in actions['activated']:
            print(f"  - {pattern}")
        if not args.dry_run:
            send_notification(f"Escalation rules activated: {len(actions['activated'])} patterns")

    if actions['reconfirmed']:
        print(f"Reconfirmed {len(actions['reconfirmed'])} rule(s):")
        for pattern, count in actions['reconfirmed']:
            print(f"  - {pattern} ({count} new FPs)")

    if actions['expired']:
        print(f"Expired {len(actions['expired'])} rule(s):")
        for pattern in actions['expired']:
            print(f"  - {pattern}")

    if not any(actions.values()):
        print("No lifecycle transitions")

    # Save updated rules
    if not args.dry_run and any(actions.values()):
        save_rules(data)
        print(f"\nRules updated: {RULES_FILE}")

    return 0


if __name__ == '__main__':
    sys.exit(main())
