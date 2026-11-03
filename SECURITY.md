# Security Policy

## Reporting a vulnerability

Please do not report security problems in a public issue, pull request or discussion.

Use GitHub's private vulnerability reporting: open the repository's **Security** tab and choose **Report a vulnerability**. Only the maintainer, and the people the maintainer adds, can see the report.

Useful to include:
- what an attacker can do, and what they need to start with;
- the steps to reproduce, on the latest pre-release (`vX.Y.Z-be.N`) if you can;
- the framework version.

Leave out host names, IP addresses, paths, user names and tokens from your own environment.

## What happens next

The maintainer acknowledges the report, fixes it privately, and publishes an advisory together with the fix. An urgent security fix may skip the usual pre-release waiting period (see [CONTRIBUTING.md](CONTRIBUTING.md), "Branches and Release Channels").

## Supported versions

The latest stable release (`master`, tags `vX.Y.Z`) and the current pre-release receive security fixes.
