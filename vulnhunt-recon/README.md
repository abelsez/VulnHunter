# vulnhunt-recon

External attack-surface reconnaissance for bug bounty programs. This skill is
the front door of the VulnHunter loop: it enumerates an *authorized* target's
subdomains, live hosts, services, technologies, endpoints, and parameters —
passive-first and scope-gated at every step — and produces a recon report that
hands off to `/vulnhunt`.

## What it is

A prompt-only skill (like `vulnhunt`), plus a small set of shell/Python helper
scripts. The skill supplies the methodology and orchestration; the scripts do
the mechanical enumeration and enforce scope.

## What it is not

- **Not a scanner.** It does not fire payloads or judge exploitability. That is
  `/vulnhunt`'s job.
- **Not a bypass.** It refuses to run without a defined scope, and it filters
  every host/URL through `scope_check.py`.
- **Not a default-to-active tool.** Enumeration is passive; active probing is
  low-rate and only against in-scope hosts.

## Layout

```text
vulnhunt-recon/
  SKILL.md                 methodology + orchestration
  README.md                this file
  phases/                  per-phase prompts (read one at a time)
    phase1_scope.md
    phase2_assets.md
    phase3_services.md
    phase4_endpoints.md
    phase5_report.md
  scripts/                 helper tooling
    scope_check.py         scope enforcement gate (single source of truth)
    install_recon_tools.sh passive tool installer
    subdomain_enum.sh      passive subdomain enumeration
    endpoint_discovery.sh  passive URL/parameter collection
    tech_fingerprint.sh    low-rate HTTP fingerprint + WAF detection
    js_recon.sh            JavaScript endpoint/secret extraction
```

## Scope files

`scope_check.py` reads `in_scope.txt` and `out_of_scope.txt` from a scope
directory. Supported patterns:

- `example.com` — exact host (or the host part of any URL)
- `*.example.com` — any subdomain of `example.com`, but not the apex itself

Lines starting with `#` are comments. Put the scope directory wherever you
like and point the skill's `SCOPE_DIR` at it (default: `scopes/`).

## External tools

The helper scripts call standard recon tools when present, and skip them
silently when absent. Install them with `scripts/install_recon_tools.sh` or
your package manager:

- subdomain: `subfinder`, `assetfinder`, `crt.sh` (curl), `amass`
- URL/archive: `gau`, `waybackurls`, `katana`
- fingerprint: `httpx`, `wafw00f`, `nuclei` (tech-detect templates)
- params/parse: `unfurl`, `jq`

## Authorized use

Recon targets systems you do not own. Use only against programs that
explicitly authorize you (published bug bounty scope, a signed engagement, or
your own assets). The skill refuses to run without a scope file, and every
host/URL is scope-gated before probing. No exceptions.
