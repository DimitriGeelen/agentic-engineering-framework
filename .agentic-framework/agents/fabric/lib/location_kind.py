#!/usr/bin/env python3
"""Is a fabric card's `location:` a file path? (T-4654)

Two checks ask "is this card's file still there": `fw fabric drift`
(agents/fabric/lib/drift.sh) and the daily audit orphan count
(agents/audit/audit.sh). Both call this one predicate, so the CLI and the audit
cannot report different orphan counts for one corpus.

A location is a path unless it plainly is something else. A card for a hosted
service, a host or a network has no file to be missing, so the question is
declined rather than answered "no":
  - a URL, `scheme://...` (T-3049; a malformed `http:/x` is still a path)
  - an IPv4 address, optionally with a /CIDR prefix or :port
  - a bracketed IPv6 address, optionally with :port
  - host:port (no slash)
  - anything containing whitespace (descriptive text, "proxmox node pve1")
  - the empty string
A bare word ("Makefile", "pve1") is indistinguishable from a file name and stays
a path, so a deleted file is never silenced by looking like a hostname.

CLI:
  location_kind.py --is-path LOC   exit 0 if LOC is a path, 1 if not
  location_kind.py --non-path      read locations on stdin, print the non-path ones
"""
import re
import sys

_URL = re.compile(r'^[A-Za-z][A-Za-z0-9+.-]*://')
_IPV4 = re.compile(r'^\d{1,3}(\.\d{1,3}){3}(/\d{1,2}|:\d{1,5})?$')
_IPV6 = re.compile(r'^\[[0-9A-Fa-f:.]+\](:\d{1,5})?$')
_HOST_PORT = re.compile(r'^[A-Za-z0-9][A-Za-z0-9.-]*:\d{1,5}$')


def is_path_location(loc):
    """True when `loc` should be checked as a file path."""
    if not isinstance(loc, str) or not loc.strip():
        return False
    if any(c.isspace() for c in loc):
        return False
    return not (_URL.match(loc) or _IPV4.match(loc) or _IPV6.match(loc)
                or _HOST_PORT.match(loc))


def main(argv):
    if len(argv) == 3 and argv[1] == '--is-path':
        return 0 if is_path_location(argv[2]) else 1
    if len(argv) == 2 and argv[1] == '--non-path':
        for line in sys.stdin:
            loc = line.rstrip('\n')
            if loc and not is_path_location(loc):
                print(loc)
        return 0
    sys.stderr.write(__doc__)
    return 2


if __name__ == '__main__':
    sys.exit(main(sys.argv))
