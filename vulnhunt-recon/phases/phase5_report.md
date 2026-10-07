# Phase 5 — Recon Report & Handoff

**Goal:** consolidate Phases 1–4 into one evidence-backed report and produce a
prioritized handoff for `/vulnhunt`.

## Report structure (`05_report.md`)

```markdown
# Recon Report — <target>

## 1. Authorization
- Target, program/platform, authorization basis, operator, date.

## 2. Scope
- In-scope roots (count + list).
- Out-of-scope rules (count + list).
- Normalized scope files: in_scope.txt, out_of_scope.txt.

## 3. Assets
- Subdomains discovered (count), top by source count, CT/ASN hints.

## 4. Services
- Live hosts (count), technology breakdown, WAFs, open ports.

## 5. Endpoints & parameters
- URLs (count), parameters (count), endpoint buckets, interesting params,
  JS-discovered endpoints, secrets found (redacted/relocated).

## 6. Prioritized attack surface
- Ordered list of (host, endpoint class) pairs worth hunting first, with a
  one-line reason each.

## 7. Handoff
- Command to start the hunt on the surfaced surface:
  /vulnhunt
  and a note of which in-scope hosts/endpoints to feed it.
```

## Rules

- Reference result files by path; do not inline raw lists.
- Counts in the report MUST match the result files. Re-count before writing.
- If a phase produced nothing, state it as "0 found" — do not invent data.
- A secret that surfaced in Phase 4 is reported as "1 secret in
  `js_secrets.txt` (redacted)" — never the value itself.

## Final gate

Before finishing, re-run the scope gate over the entire assembled asset list
one last time and confirm zero out-of-scope hosts made it into the report. If
any slipped through, remove them and note the correction.

## Output

- `05_report.md` — the recon report and /vulnhunt handoff.
