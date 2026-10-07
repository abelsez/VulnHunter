# Phase 3 — Service Discovery (low-rate active)

**Goal:** turn the scope-filtered asset list into a fingerprint of *live*
hosts, their open ports, and their technology stack. This is the first phase
that makes network requests — low rate, in-scope only.

## Steps

1. **Resolve in-scope only.** Filter `subdomains.txt` through `scope_check.py`
   again before any request. Never resolve an out-of-scope host.

2. **Live + fingerprint.** Run `scripts/tech_fingerprint.sh`:

   ```bash
   bash scripts/tech_fingerprint.sh \
     --in-scope "$VULNHUNT_RECON_DIR/in_scope.txt" \
     --out-of-scope "$VULNHUNT_RECON_DIR/out_of_scope.txt" \
     --hosts "$VULNHUNT_RECON_DIR/subdomains.txt" \
     --out "$VULNHUNT_RECON_DIR/live_hosts.txt"
   ```

   The script probes with `httpx` at a capped rate (default 25 req/s, tunable
   down), records status/title/tech/redirects, and optionally detects WAFs
   (`wafw00f`) and runs nuclei's `tech-detect` templates. Port scanning, when
   requested and authorized, uses `naabu` on the top-ports set only — never a
   full 65535 sweep by default.

3. **Port and service note.** If a port scan was authorized and run, record
   open ports per host in `03_services.md`. Treat open non-HTTP ports as
   "investigate in /vulnhunt", not as findings here.

4. **Prioritize.** Sort live hosts by: has a web app (HTTP 2xx/3xx) > has
   interesting tech (WAF, unusual server, API framework) > other. This ranking
   feeds Phase 4 and the final handoff.

5. **Write `03_services.md`:** live/total counts, tech breakdown, WAF list,
   open-port summary, and the prioritized host ordering.

## Output

- `live_hosts.txt` — in-scope, fingerprint-annotated live hosts
- `03_services.md` — service/tech summary + prioritization

## Guardrails

- Rate-limit everything; default 25 req/s max, lower on request.
- In-scope only. A host that fails the scope gate is dropped, not probed.
- No payloads, no vulnerability probing — fingerprinting only.
