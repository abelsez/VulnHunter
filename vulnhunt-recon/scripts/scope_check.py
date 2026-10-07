#!/usr/bin/env python3
"""Scope gate for VulnHunter recon.

Reads domains/URLs/IPs/CIDRs from argv or stdin and prints only the assets that
are allowed by in_scope.txt and not excluded by out_of_scope.txt.

Supported scope patterns:
  example.com          exact host, or the host part of any URL
  *.example.com        subdomains of example.com, not example.com itself
  192.0.2.0/24         an IPv4 CIDR (also matches single IPs)
  192.0.2.7            a single IPv4 address (treated as /32)

This tool performs no network requests.
"""

from __future__ import annotations

import argparse
import ipaddress
import os
import re
import sys
from dataclasses import dataclass
from pathlib import Path
from urllib.parse import urlparse


def _default_scope_dir() -> Path:
    env = os.environ.get("VULNHUNT_SCOPE_DIR")
    if env:
        return Path(env)
    return Path("scopes")


@dataclass(frozen=True)
class Pattern:
    raw: str
    host: str | None = None
    wildcard: bool = False
    network: ipaddress.IPv4Network | ipaddress.IPv6Network | None = None

    @property
    def is_network(self) -> bool:
        return self.network is not None


def strip_comment(line: str) -> str:
    return line.split("#", 1)[0].strip()


def host_from_value(value: str) -> str:
    value = value.strip()
    if not value:
        return ""
    # urlparse needs a scheme to reliably treat a value as a netloc.
    candidate = value if re.match(r"^[a-zA-Z][a-zA-Z0-9+.-]*://", value) else f"//{value}"
    parsed = urlparse(candidate)
    host = parsed.hostname or value.split("/", 1)[0]
    return host.strip().lower().rstrip(".")


def _parse_network(raw: str) -> ipaddress.IPv4Network | ipaddress.IPv6Network | None:
    # CIDR, or a bare IP treated as /32 (or /128).
    try:
        return ipaddress.ip_network(raw, strict=False)
    except ValueError:
        return None


def parse_pattern(raw: str) -> Pattern | None:
    raw = raw.strip()
    if not raw:
        return None

    # Wildcard subdomain.
    if raw.startswith("*."):
        host = host_from_value(raw[2:])
        if host:
            return Pattern(raw=raw, host=host, wildcard=True)
        return None

    # CIDR or bare IP (contains only IP/CIDR chars and at least one digit).
    if re.fullmatch(r"[0-9a-fA-F:./]+", raw) and re.search(r"\d", raw):
        net = _parse_network(raw)
        if net is not None:
            return Pattern(raw=raw, network=net)
        return None

    host = host_from_value(raw)
    if host:
        return Pattern(raw=raw, host=host)
    return None


def load_patterns(path: Path) -> list[Pattern]:
    patterns: list[Pattern] = []
    if not path.exists():
        return patterns
    for line in path.read_text(encoding="utf-8").splitlines():
        pat = parse_pattern(strip_comment(line))
        if pat is not None:
            patterns.append(pat)
    return patterns


def _ip_matches(host: str, pattern: Pattern) -> bool:
    try:
        addr = ipaddress.ip_address(host)
    except ValueError:
        return False
    return pattern.network is not None and addr in pattern.network


def matches(host: str, pattern: Pattern) -> bool:
    host = host.lower().rstrip(".")
    if pattern.is_network:
        return _ip_matches(host, pattern)
    if pattern.wildcard:
        return host.endswith(f".{pattern.host}") and host != pattern.host
    return host == pattern.host


def classify(value: str, includes: list[Pattern], excludes: list[Pattern]) -> tuple[bool, str, str]:
    host = host_from_value(value)
    if not host:
        return False, "", "empty-or-invalid"

    include_match = next((p for p in includes if matches(host, p)), None)
    if include_match is None:
        return False, host, "not-in-scope"

    exclude_match = next((p for p in excludes if matches(host, p)), None)
    if exclude_match is not None:
        return False, host, f"excluded-by:{exclude_match.raw}"

    return True, host, f"included-by:{include_match.raw}"


def iter_inputs(args: list[str]) -> list[str]:
    values: list[str] = list(args)
    if not sys.stdin.isatty():
        values.extend(line.strip() for line in sys.stdin if line.strip())
    return values


def main() -> int:
    parser = argparse.ArgumentParser(description="Filter domains/URLs/IPs by bug bounty scope.")
    parser.add_argument("assets", nargs="*", help="Domains, URLs, or IPs to check. Also reads stdin.")
    parser.add_argument("--scope-dir", help="Directory containing in_scope.txt and out_of_scope.txt")
    parser.add_argument("--in-scope", help="Path to in-scope file (overrides --scope-dir)")
    parser.add_argument("--out-of-scope", help="Path to out-of-scope file (overrides --scope-dir)")
    parser.add_argument("--explain", action="store_true", help="Print decision and reason for every input")
    parser.add_argument("--hosts-only", action="store_true", help="Print normalized hosts instead of original values")
    ns = parser.parse_args()

    scope_dir = Path(ns.scope_dir) if ns.scope_dir else _default_scope_dir()
    in_scope = Path(ns.in_scope) if ns.in_scope else scope_dir / "in_scope.txt"
    out_scope = Path(ns.out_of_scope) if ns.out_of_scope else scope_dir / "out_of_scope.txt"

    includes = load_patterns(in_scope)
    excludes = load_patterns(out_scope)

    if not includes:
        print(f"[scope_check] no in-scope patterns loaded from {in_scope}", file=sys.stderr)
        return 2

    values = iter_inputs(ns.assets)
    if not values:
        print("[scope_check] provide assets as args or stdin", file=sys.stderr)
        return 2

    exit_code = 1
    seen: set[str] = set()

    for value in values:
        allowed, host, reason = classify(value, includes, excludes)
        printable = host if ns.hosts_only else value
        key = f"{allowed}:{printable}:{reason}"
        if key in seen:
            continue
        seen.add(key)

        if ns.explain:
            status = "ALLOW" if allowed else "DENY"
            print(f"{status}\t{printable}\t{reason}")
        elif allowed:
            print(printable)

        if allowed:
            exit_code = 0

    return exit_code


if __name__ == "__main__":
    raise SystemExit(main())
