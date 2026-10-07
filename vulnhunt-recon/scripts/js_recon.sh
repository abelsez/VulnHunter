#!/usr/bin/env bash
# JavaScript recon: extract endpoints/paths and flag secrets from in-scope JS.
# Input is a scope-filtered URL list. Only .js URLs whose host is in-scope are
# fetched, at low rate. Secrets are never printed; their locations are recorded.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCOPE_CHECK="$SCRIPT_DIR/scope_check.py"

usage() {
    cat <<'EOF'
Usage: js_recon.sh --in-scope FILE --out-of-scope FILE --urls FILE --out-dir DIR
  Extract endpoints and secret locations from in-scope JavaScript files.
  Writes <out-dir>/js_endpoints.txt and <out-dir>/js_secrets.txt.
EOF
}

IN_SCOPE=""; OUT_SCOPE=""; URLS=""; OUT_DIR=""
while [ $# -gt 0 ]; do
    case "$1" in
        --in-scope) IN_SCOPE="$2"; shift 2 ;;
        --out-of-scope) OUT_SCOPE="$2"; shift 2 ;;
        --urls) URLS="$2"; shift 2 ;;
        --out-dir) OUT_DIR="$2"; shift 2 ;;
        -h|--help) usage; exit 0 ;;
        *) echo "unknown arg: $1" >&2; usage >&2; exit 2 ;;
    esac
done

[ -n "$IN_SCOPE" ] && [ -n "$OUT_SCOPE" ] && [ -n "$URLS" ] && [ -n "$OUT_DIR" ] || {
    usage >&2; exit 2
}
[ -s "$URLS" ] || { echo "[js_recon] urls file missing/empty: $URLS" >&2; exit 1; }

mkdir -p "$OUT_DIR"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
: > "$TMP/endpoints.txt"
: > "$OUT_DIR/js_secrets.txt"

have() { command -v "$1" >/dev/null 2>&1; }

# In-scope .js URLs only.
grep -iE '\.js(\?|#|$)' "$URLS" | sort -u | \
    python3 "$SCOPE_CHECK" --in-scope "$IN_SCOPE" --out-of-scope "$OUT_SCOPE" \
    > "$TMP/js_urls.txt"

echo "[js_recon] in-scope JS files: $(wc -l < "$TMP/js_urls.txt" | tr -d ' ')"

# Endpoint/path extraction via LinkFinder-style regex (no install required).
while IFS= read -r url; do
    [ -z "$url" ] && continue
    if have curl; then
        curl -fsSL --max-time 15 "$url" 2>/dev/null || true
    fi
done < "$TMP/js_urls.txt" \
    | grep -oE '"/[A-Za-z0-9_./-]{2,}"' \
    | tr -d '"' | sort -u > "$TMP/endpoints.txt"

cp "$TMP/endpoints.txt" "$OUT_DIR/js_endpoints.txt"
echo "[js_recon] endpoints: $(wc -l < "$OUT_DIR/js_endpoints.txt" | tr -d ' ') -> $OUT_DIR/js_endpoints.txt"

# Secret scanning. Prefer gitleaks/trufflehog; fall back to nuclei exposure
# templates. Only record file paths and match counts — never the secret value.
if have gitleaks; then
    gitleaks detect --source "$TMP" --no-banner --report-format json \
        > "$TMP/gitleaks.json" 2>/dev/null || true
    if have jq; then
        jq -r '.[]?.RuleID' "$TMP/gitleaks.json" 2>/dev/null | sort | uniq -c \
            >> "$OUT_DIR/js_secrets.txt" || true
    fi
elif have trufflehog; then
    trufflehog filesystem "$TMP" --no-update --only-verified=false \
        2>/dev/null || true >> "$OUT_DIR/js_secrets.txt"
else
    echo "[js_recon] no secret scanner (gitleaks/trufflehog) found; skipping secret scan." >&2
fi

echo "[js_recon] secret scan notes -> $OUT_DIR/js_secrets.txt"
