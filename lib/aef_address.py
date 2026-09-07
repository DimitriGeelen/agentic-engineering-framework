"""T-3307 (arc-020 S1): V9 address grammar library.

Implements the address grammar ratified in
docs/reports/T-3287-identity-taxonomy-circuit-model.md (D3 + D6):

    address := "aef::" segment* leaf?
    segment := label "=" value "::"     label in {host, hub, project, session}
    leaf    := "@" agent-name "::"

    durable (correspondent):  aef::host=<fqdn>::hub=<H>::project=<path>::@<agent>::
    circuit  (actor):         ... ::session=<S-id>:: ...    (session= token present)

Key semantics carried here:
  - Correspondent/actor split (D2/D3): the durable name is the address WITHOUT
    the session= token; the circuit id is the same address WITH it.
  - hub= is optional (D6): a bare address resolves the hub via the host default
    (see AEFAddress.effective_hub).
  - IPv6 host literals are bracketed on the wire ([fe80::1]) and stored
    unbracketed in the parsed field.
  - The space-separated V4 form is the human-typed alias; it parses to the same
    tuple as V9.
  - Sparse/ladder token-drop: the ladder climbs by dropping the RIGHTMOST token
    (agent -> session -> project -> hub); a query may drop ANY token (labels are
    self-typing, so sparse stays unambiguous).
  - Project-path elision (first/.../last-two for paths >3 segments) is
    DISPLAY-ONLY. serialize() never emits the elided form and refuses a project
    value carrying the elision marker — a collided display string re-entering
    the wire would re-collapse two projects into one correspondent.
"""

from __future__ import annotations

from dataclasses import dataclass, replace

SCHEME = "aef::"
TERMINATOR = "::"
ELLIPSIS = "…"  # single-char ellipsis, NOT ".." (parent-dir collision)
LABELS = ("host", "hub", "project", "session")
# Ladder climb order: rightmost token first (level 5 down to level 2).
_CLIMB_ORDER = ("agent", "session", "project", "hub")


class AddressError(ValueError):
    """Raised when a wire or alias string does not match the V9/V4 grammar."""


@dataclass(frozen=True)
class AEFAddress:
    """Parsed V9 address. All fields optional (sparse addresses are legal)."""

    host: str | None = None
    hub: str | None = None
    project: str | None = None
    session: str | None = None
    agent: str | None = None

    # ── correspondent/actor split (D2/D3) ────────────────────────────────
    @property
    def is_circuit(self) -> bool:
        """True when the session= token is present (actor / circuit id)."""
        return self.session is not None

    def to_durable(self) -> "AEFAddress":
        """Drop the session= token: the correspondent (durable name)."""
        return replace(self, session=None)

    def to_circuit(self, session_id: str) -> "AEFAddress":
        """Bind a live session: durable name + session = circuit id."""
        if not session_id:
            raise AddressError("session_id must be non-empty")
        return replace(self, session=session_id)

    # ── hub default resolution (D6) ──────────────────────────────────────
    def effective_hub(self, host_default=None) -> str | None:
        """Resolve the hub: own hub= token if present, else the host default.

        host_default may be a plain hub id (str), a mapping host->hub id, or a
        callable host->hub id. Returns None when the hub cannot be resolved.
        """
        if self.hub is not None:
            return self.hub
        if host_default is None:
            return None
        if callable(host_default):
            return host_default(self.host)
        if hasattr(host_default, "get"):
            return host_default.get(self.host)
        return host_default

    # ── sparse/ladder token-drop ─────────────────────────────────────────
    def climb(self) -> "AEFAddress | None":
        """Drop the rightmost present token (one ladder rung up).

        Returns None when only host remains (or nothing is left to drop):
        host is the ladder's last rung, never dropped, and a climb never
        yields an empty (unaddressable) result.
        """
        for field in _CLIMB_ORDER:
            if getattr(self, field) is not None:
                rung = replace(self, **{field: None})
                if rung == AEFAddress():
                    return None
                return rung
        return None

    def ladder(self) -> list["AEFAddress"]:
        """The full descent: self, then each successive climb() rung."""
        rungs = [self]
        cur = self.climb()
        while cur is not None:
            rungs.append(cur)
            cur = cur.climb()
        return rungs

    # ── wire and display forms ───────────────────────────────────────────
    def serialize(self) -> str:
        return serialize(self)

    def display_format(self) -> str:
        """Human-facing rendering with the project path elided (display-ONLY).

        Lossy — never a wire value; the wire serializer never emits this form.
        """
        project = elide_path(self.project) if self.project else self.project
        return _assemble(replace(self, project=project), _allow_ellipsis=True)


# ── parsing ──────────────────────────────────────────────────────────────


def parse(text: str) -> AEFAddress:
    """Parse a V9 wire address or a V4 space-separated human alias."""
    text = text.strip()
    if not text:
        raise AddressError("empty address")
    if text.startswith(SCHEME):
        return parse_v9(text)
    return parse_v4(text)


def parse_v9(text: str) -> AEFAddress:
    """Parse the canonical wire form: aef::label=value::...::@name::"""
    text = text.strip()
    if not text.startswith(SCHEME):
        raise AddressError(f"V9 address must start with {SCHEME!r}: {text!r}")
    tokens = _tokenize_v9(text[len(SCHEME):])
    if not tokens:
        raise AddressError("address carries no tokens")
    return _build(tokens)


def parse_v4(text: str) -> AEFAddress:
    """Parse the human alias: space-separated label=value tokens + @name."""
    tokens = text.split()
    if not tokens:
        raise AddressError("empty address")
    return _build(tokens)


def _tokenize_v9(body: str) -> list[str]:
    """Split on '::' terminators, ignoring '::' inside [bracketed] values."""
    tokens: list[str] = []
    start = i = 0
    depth = 0
    n = len(body)
    while i < n:
        c = body[i]
        if c == "[":
            depth += 1
            i += 1
        elif c == "]":
            if depth == 0:
                raise AddressError(f"unbalanced ']' in {body!r}")
            depth -= 1
            i += 1
        elif depth == 0 and body.startswith(TERMINATOR, i):
            tokens.append(body[start:i])
            i += 2
            start = i
        else:
            i += 1
    if depth != 0:
        raise AddressError(f"unclosed '[' in {body!r}")
    if start != n:
        raise AddressError(
            f"unterminated token {body[start:]!r} — every token ends with '::'"
        )
    return tokens


def _build(tokens: list[str]) -> AEFAddress:
    fields: dict[str, str] = {}
    agent = None
    for tok in tokens:
        if agent is not None:
            raise AddressError(f"token {tok!r} after the @agent leaf")
        if not tok:
            raise AddressError("empty token")
        if tok.startswith("@"):
            name = tok[1:]
            if not name:
                raise AddressError("empty agent name in '@' leaf")
            agent = name
            continue
        label, sep, value = tok.partition("=")
        if not sep:
            raise AddressError(f"token {tok!r} is neither label=value nor @name")
        if label not in LABELS:
            raise AddressError(f"unknown label {label!r} (allowed: {LABELS})")
        if not value:
            raise AddressError(f"empty value for {label}=")
        if label in fields:
            raise AddressError(f"duplicate {label}= token")
        if label == "host":
            value = _unbracket_host(value)
        fields[label] = value
    return AEFAddress(agent=agent, **fields)


def _unbracket_host(value: str) -> str:
    """IPv6 literals are bracketed on the wire, stored unbracketed."""
    if value.startswith("[") and value.endswith("]"):
        inner = value[1:-1]
        if not inner:
            raise AddressError("empty bracketed host literal")
        return inner
    return value


# ── serialization ────────────────────────────────────────────────────────


def serialize(addr: AEFAddress) -> str:
    """Emit the canonical V9 wire form. Full project path only, never elided."""
    if addr.project and ELLIPSIS in addr.project:
        raise AddressError(
            "elided project path is display-only and must never reach the wire"
        )
    return _assemble(addr)


def _assemble(addr: AEFAddress, _allow_ellipsis: bool = False) -> str:
    parts: list[str] = []
    if addr.host is not None:
        parts.append("host=" + _bracket_host(addr.host))
    if addr.hub is not None:
        parts.append("hub=" + addr.hub)
    if addr.project is not None:
        parts.append("project=" + addr.project)
    if addr.session is not None:
        parts.append("session=" + addr.session)
    if addr.agent is not None:
        parts.append("@" + addr.agent)
    if not parts:
        raise AddressError("cannot serialize an empty address")
    return SCHEME + TERMINATOR.join(parts) + TERMINATOR


def _bracket_host(host: str) -> str:
    """IPv6 literals (contain ':') are bracketed on the wire."""
    if ":" in host and not host.startswith("["):
        return f"[{host}]"
    return host


# ── display-only path elision (D3 sub-rule) ──────────────────────────────


def elide_path(path: str) -> str:
    """Elide a filesystem path for display: first segment + ellipsis + last two.

    Applies only to paths with >3 segments; shorter paths render unchanged.
    Lossy by design — NEVER a wire/identity value.
    """
    leading = "/" if path.startswith("/") else ""
    segments = [s for s in path.split("/") if s]
    if len(segments) <= 3:
        return path
    return leading + "/".join([segments[0], ELLIPSIS, segments[-2], segments[-1]])
