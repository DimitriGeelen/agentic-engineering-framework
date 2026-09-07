"""arc-020 S5: environmental governor v1 — loadavg-based provisioning admission.

Spec: docs/reports/T-3287-identity-taxonomy-circuit-model.md (D5 bound 2).
Retrofits the load-62 incident: no host-resource-awareness existed, so work
piled onto an already-drowning host. This governor consults the host's own
1-minute loadavg, normalized per core, before admitting a provisioning step.

v1 is deliberately crude — loadavg only. The full mem/disk/cpu/net adaptive
governor is a separate slice (S5b); this module's decision vocabulary
(allow/defer/deny) and the seam adapter are the stable contract it grows into.

Decision bands (per-core normalized 1-min loadavg L, threshold T):
  - L <  T          -> ALLOW  (headroom exists; admit)
  - T <= L < 2T     -> DEFER  (backpressure: host is busy, try again later)
  - L >= 2T         -> DENY   (host is drowning; refuse outright — the
                               load-62 host at ~3.9/core lands here)

T defaults to DEFAULT_LOAD_MAX (0.8) and is configurable via
FW_PROVISION_LOAD_MAX (registered in lib/config.sh FW_CONFIG_REGISTRY).
DEFER and DENY are never silent — both emit a line to the log sink
(stderr by default) carrying the decision context.

Plugs into lib/aef_resolve.provision()'s admission seam via as_admission():
the seam is boolean, so DEFER and DENY both block the step there — the log
line carries the distinction the bool cannot.
"""

from __future__ import annotations

import os
import sys
from typing import Any, Callable

ALLOW = "allow"
DEFER = "defer"
DENY = "deny"

# Per-core normalized 1-min loadavg admission ceiling. 0.8 leaves real
# headroom before saturation (1.0/core); override via FW_PROVISION_LOAD_MAX.
DEFAULT_LOAD_MAX = 0.8

# At or beyond threshold * this multiplier the host is not merely busy but
# drowning: deny outright rather than defer.
DENY_MULTIPLIER = 2.0

ENV_KEY = "FW_PROVISION_LOAD_MAX"


def _log_stderr(line: str) -> None:
    print(line, file=sys.stderr)


def load_threshold(
    env: "os._Environ[str] | dict[str, str] | None" = None,
    log: Callable[[str], None] | None = None,
) -> float:
    """Resolve the admission threshold: FW_PROVISION_LOAD_MAX else default.

    An unparseable or non-positive value falls back to DEFAULT_LOAD_MAX —
    logged, not silent, because a typo'd threshold silently governing
    admission is the exact failure class D5 bound 4 forbids.
    """
    env = os.environ if env is None else env
    raw = env.get(ENV_KEY, "")
    if not raw:
        return DEFAULT_LOAD_MAX
    try:
        value = float(raw)
        if value <= 0:
            raise ValueError("threshold must be positive")
        return value
    except ValueError:
        (log or _log_stderr)(
            f"aef-governor: {ENV_KEY}={raw!r} is not a positive number; "
            f"using default {DEFAULT_LOAD_MAX}"
        )
        return DEFAULT_LOAD_MAX


def _host_load1() -> float:
    """1-minute loadavg from the live host (os.getloadavg reads /proc/loadavg
    on Linux). Tests inject load1= instead of ever reaching this."""
    return os.getloadavg()[0]


def admission_check(
    decision_context: Any,
    *,
    load1: float | Callable[[], float] | None = None,
    cpu_count: int | None = None,
    threshold: float | None = None,
    log: Callable[[str], None] | None = None,
) -> str:
    """Admit, defer, or deny a provisioning step based on host headroom.

    ``decision_context`` is whatever identifies the step being admitted
    (the S5 seam passes {"level": ..., "intended": ...}); it is carried
    verbatim into the DEFER/DENY log line for traceability (D5 bound 4).

    ``load1`` may be a float (a sample) or a callable returning one (fresh
    sample per check); default samples the live host. ``threshold`` defaults
    to FW_PROVISION_LOAD_MAX else DEFAULT_LOAD_MAX. Returns ALLOW, DEFER,
    or DENY; the two blocking decisions are logged, never silent.
    """
    sink = log or _log_stderr
    if threshold is None:
        threshold = load_threshold(log=sink)
    sample = load1() if callable(load1) else load1
    if sample is None:
        sample = _host_load1()
    cores = cpu_count or os.cpu_count() or 1
    normalized = sample / max(cores, 1)

    if normalized < threshold:
        return ALLOW
    decision = DENY if normalized >= threshold * DENY_MULTIPLIER else DEFER
    sink(
        f"aef-governor: {decision} provisioning — per-core load "
        f"{normalized:.2f} (load1={sample:.2f}, cores={cores}) "
        f">= threshold {threshold:.2f}"
        f"{' * ' + str(DENY_MULTIPLIER) if decision == DENY else ''} "
        f"context={decision_context!r}"
    )
    return decision


def as_admission(
    *,
    load1: float | Callable[[], float] | None = None,
    cpu_count: int | None = None,
    threshold: float | None = None,
    log: Callable[[str], None] | None = None,
) -> Callable[[str, Any], bool]:
    """Adapt the governor to aef_resolve.provision()'s admission seam.

    The seam is Callable[[level, intended_address], bool]; only ALLOW maps
    to True — DEFER and DENY both block the step, with the log line
    carrying which of the two it was.
    """

    def admission(level: str, intended: Any) -> bool:
        context = {"level": level, "intended": str(intended)}
        return (
            admission_check(
                context,
                load1=load1,
                cpu_count=cpu_count,
                threshold=threshold,
                log=log,
            )
            == ALLOW
        )

    return admission
