# Phase 4 — Endpoint & Parameter Discovery (passive-first)

**Goal:** collect URLs, JavaScript files, and parameters from public archives
and in-scope live hosts, then extract the interesting surface (auth endpoints,
API routes, upload handlers, admin paths, parameters) for handoff.

## Steps

1. **Passive URL collection.** Run `scripts/endpoint_discovery.sh`:

   ```bash
   bash scripts/endpoint_discovery.sh \
     --in-scope "$VULNHUNT_RECON_DIR/in_scope.txt" \
     --out-of-scope "$VULNHUNT_RECON_DIR/out_of_scope.txt" \
     --roots "$VULNHUNT_RECON_DIR/roots.txt" \
     --out "$VULNHUNT_RECON_DIR/urls.txt"
   ```

   This pulls URLs from `gau`, `waybackurls`, and (passive) `katana`, filters
   by scope, dedupes, and extracts parameter names to `params.txt`.

2. **JavaScript extraction (only from in-scope URLs).** Run `scripts/js_recon.sh`
   over `urls.txt` to download JS from in-scope hosts, extract endpoints/paths
   (LinkFinder-style regex) and flag secrets (gitleaks/trufflehog/nuclei if
   present). Results to `js_endpoints.txt` and `js_secrets.txt`.

3. **Classify the surface.** Bucket the collected endpoints by interest for
   hunting: auth/login/logout, API (`/api/`, `/graphql`, `/v1/`), file
   upload, admin/internal, redirect/callback, and everything else. Focus
   handoff on the first four buckets.

4. **Parameter inventory.** From `params.txt`, list parameter names and the
   hosts they appear on. Flag parameters that look security-relevant (`id`,
   `user`, `redirect`, `url`, `file`, `path`, `token`, `key`, `callback`).

5. **Write `04_endpoints.md`:** URL/param/JS counts, endpoint buckets with
   examples, interesting parameters, and any JS-discovered endpoints or
   secrets (redacted — never paste a live secret; note its location and move
   it to a separate, git-ignored evidence file).

## Output

- `urls.txt`, `params.txt`
- `js_endpoints.txt`, `js_secrets.txt` (secrets file git-ignored)
- `04_endpoints.md` — endpoint/parameter summary and classification

## Guardrails

- Archives are passive; the only active requests are fetching JS from
  *in-scope* hosts at low rate.
- A discovered secret is evidence, not a target: record and move on. Do not
  use it to authenticate or pivot during recon.
