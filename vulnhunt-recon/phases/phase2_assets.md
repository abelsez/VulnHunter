# Phase 2 — Asset Discovery (passive)

**Goal:** enumerate subdomains and related assets for every in-scope root
using *passive* sources only. No direct DNS brute force, no port probing.

## Steps

1. **Extract roots.** Normalize in-scope entries to root domains (strip `*.`
   and any path). Write one root per line to `${VULNHUNT_RECON_DIR}/roots.txt`.

2. **Enumerate passively.** Run `scripts/subdomain_enum.sh` with the scope
   files and roots:

   ```bash
   bash scripts/subdomain_enum.sh \
     --in-scope "$VULNHUNT_RECON_DIR/in_scope.txt" \
     --out-of-scope "$VULNHUNT_RECON_DIR/out_of_scope.txt" \
     --roots "$VULNHUNT_RECON_DIR/roots.txt" \
     --out "$VULNHUNT_RECON_DIR/subdomains.txt"
   ```

   The script calls subfinder/assetfinder/crt.sh/amass in passive mode and
   pipes every candidate through `scope_check.py`, so only in-scope hosts are
   kept.

3. **Enrich with certificate transparency and ASN hints (if tools exist).**
   For each root, collect CT logs (crt.sh) and, where an ASN is known, its
   associated netblocks. Record these as *hints*, not as confirmed assets.
   Confirm nothing until it passes the scope gate and (in Phase 3) resolves
   and responds.

4. **Dedupe and rank.** Sort unique, lowercase, strip trailing dots. Mark each
   host with its discovery source(s). Order by source count (a host seen in
   several sources is more likely to be real).

5. **Write `02_assets.md`:** total counts, per-source counts, the top hosts by
   source count, and any CT/ASN hints that will feed Phase 3. Do not paste the
   full raw list into the report; reference the file.

## Output

- `roots.txt` — in-scope roots
- `subdomains.txt` — scope-filtered, deduped candidates (with sources)
- `02_assets.md` — asset summary

## Guardrails

- Passive sources only. If a tool's only mode is active (e.g., brute-force
  DNS), skip it and note that in `02_assets.md`.
- Every host, including CT/ASN hints, must pass `scope_check.py` before it
  appears in `subdomains.txt`.
