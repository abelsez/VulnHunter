---
name: vulnhunt-recon
description: >
  Reconnaissance for external bug bounty programs. Enumerates an authorized
  attack surface (subdomains, live hosts, services, technologies, endpoints,
  and parameters) passive-first, enforces program scope on every host and
  URL, and produces an evidence-backed recon report that hands off to
  /vulnhunt for deep hunting.
trigger:
  - /vulnhunt-recon
  - /recon
  - user asks to enumerate an attack surface
  - user asks to map a bug bounty target
  - user asks for subdomain, endpoint, or parameter discovery
  - user asks to run reconnaissance
---

# VulnHunter Recon Skill

External attack-surface reconnaissance for bug bounty programs. This is the
**front door** of the VulnHunter loop: it maps *where* to hunt before
`/vulnhunt` decides *how* to hunt. It is passive-first, low-rate, and
scope-gated at every step.

## MANDATORY FIRST ACTIONS

**Step 0 — Authorization gate.** External recon touches systems you do not
own. Before any enumeration, confirm the target is authorized:

1. The target must be a program you are explicitly allowed to test — a bug
   bounty program with published scope, a signed pentest engagement, or your
   own asset.
2. You must be able to load the program's in-scope and out-of-scope lists. If
   none exist, **refuse to proceed**: "No scope defined. Create
   `scopes/in_scope.txt` before running recon."
3. Every host and URL discovered in every phase MUST pass scope filtering
   before any probing. A host that is not in-scope is never touched — not
   even with a DNS or HTTP request.
4. If the user cannot demonstrate authorization, STOP and run no tool.

**Step 1 — Resolve scope and output dir.** Bind:

- `VULNHUNT_RECON_DIR` = `<target>/<basename>_RECON_<YYYY-MM-DD-HHMMSS>`
  (fresh `mkdir -p`, never reuse an existing dir).
- `SCOPE_DIR` = a directory containing `in_scope.txt` and `out_of_scope.txt`.
  If the invocation names a scope directory, use it; otherwise default to
  `scopes/` relative to the invocation directory. Confirm the resolved
  location in one line before proceeding.

Every phase writes into `VULNHUNT_RECON_DIR` and filters hosts/URLs through
`scripts/scope_check.py` before any active step.

**Step 2 — Tool presence.** The helpers under `scripts/` call external tools
(subfinder, assetfinder, httpx, nuclei, gau, waybackurls, katana, etc.).
Detect which are installed. Missing tools are **skipped, never a hard
failure** — the phase degrades to what is available. If nothing is installed,
run `scripts/install_recon_tools.sh` (passive tooling only) or list the
missing tools for the user to install.

---

## Operating Principles

1. **Scope is law.** An out-of-scope asset is not a finding — it is a mistake.
   `scope_check.py` is the single enforcement point. Never bypass it, and
   never hand-edit a result file to smuggle an out-of-scope host back in.
2. **Passive before active.** Subdomain/URL/JS discovery must be passive
   (public sources, archives, cert transparency). Active probing (HTTP
   requests, port scans, fingerprinting) is allowed only against hosts that
   already passed scope filtering, at low rate.
3. **Evidence, not volume.** Each phase records *what was run, against what,
   and what it produced*. A recon report without provenance is noise.
4. **No exploitation here.** Recon stops at enumeration and fingerprinting.
   Exploitability judgment belongs to `/vulnhunt`; remediation to
   `/vulnhunter-fix`. Do not fire payloads during recon.
5. **No destructive defaults.** No brute force, no credential stuffing, no
   DoS, no rate amplification, no evasion. Low and slow.

---

## Workflow

### When the user invokes /vulnhunt-recon (or asks for recon):

1. **Mandatory First Actions** (above): authorization gate, resolve
   `VULNHUNT_RECON_DIR` + `SCOPE_DIR`, tool presence. Do not proceed until
   scope is confirmed.

2. **Run phases 1–5 in order.** Read each phase file from
   `${PHASES_DIR}/`, execute its steps with this harness's tools, and write
   its output artifact into `${VULNHUNT_RECON_DIR}/`. Report token usage and
   the artifact path to the user after each phase.

   - **Phase 1 — Scope & program intake** → `phase1_scope.md` → `01_scope.md`
   - **Phase 2 — Asset discovery** → `phase2_assets.md` → `02_assets.md`
   - **Phase 3 — Service discovery** → `phase3_services.md` → `03_services.md`
   - **Phase 4 — Endpoint & parameter discovery** → `phase4_endpoints.md` →
     `04_endpoints.md`
   - **Phase 5 — Recon report & handoff** → `phase5_report.md` →
     `05_report.md`

   Each phase file is a self-contained prompt; read it completely before
   executing. If a phase's required input is empty (e.g., no live hosts),
   record that emptiness honestly and continue — do not invent assets.

3. **Handoff.** The recon report (`05_report.md`) ends with a prioritized
   attack-surface summary and the exact command to hand the surfaced surface
   to `/vulnhunt`. Recon never runs the hunt itself.

### Stopping rules

- **No scope → no recon.** If `in_scope.txt` is empty or missing, stop at
  Phase 1 and ask for scope.
- **Zero assets is a valid outcome.** A small program may legitimately yield
  few subdomains or endpoints. Report the empty result honestly.
- **Out-of-scope leakage.** If a later phase surfaces an out-of-scope host
  inside a result file, stop that phase, remove the entry via
  `scope_check.py`, and note the exclusion in the report. Do not test it.

---

## Phase Loading Instructions

Phase files live in the `phases/` directory inside the directory containing
this SKILL.md. Use that directory as `PHASES_DIR`.

**If a Read call for any phase file returns "file not found", STOP and tell
the user:** "Phase file not found at [path]. The vulnhunt-recon skill is not
installed correctly. Run install.sh from the VulnHunter repository root."
Do not improvise the phase methodology.

**Context management:**
- Read phase files one at a time, only the phase you are executing.
- Keep the recon report and result files out of context except for the
  summary tables you are writing.
- Do not bulk-read raw `urls.txt` / `subdomains.txt` into context; operate on
  them with the scripts.

**Phase file reference:**
- `phase1_scope.md` — program intake, scope normalization, authorization record
- `phase2_assets.md` — passive subdomain/certificate/ASN asset discovery
- `phase3_services.md` — live-host, port, and technology fingerprinting
- `phase4_endpoints.md` — URL, JavaScript, and parameter discovery
- `phase5_report.md` — recon report format and /vulnhunt handoff

**Helper scripts** (`scripts/`):
- `scope_check.py` — the scope enforcement gate (single source of truth)
- `install_recon_tools.sh` — installs passive recon tooling
- `subdomain_enum.sh` — passive subdomain enumeration, scope-filtered
- `endpoint_discovery.sh` — passive URL/parameter collection, scope-filtered
- `tech_fingerprint.sh` — low-rate HTTP fingerprint + WAF detection
- `js_recon.sh` — JavaScript endpoint/secret extraction
