#!/usr/bin/env bash
# Passive subdomain enumeration, scope-gated.
# Sources: subfinder, assetfinder, crt.sh, amass (passive). Missing tools are
# skipped silently; every candidate passes through scope_check.py before output.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCOPE_CHECK="$SCRIPT_DIR/scope_check.py"

usage() {
    cat <<'EOF'
Usage: subdomain_enum.sh --in-scope FILE --out-of-scope FILE --roots FILE --out FILE
  Passive subdomain enumeration, filtered by scope.
EOF
}

IN_SCOPE=""; OUT_SCOPE=""; ROOTS=""; OUT=""
while [ $# -gt 0 ]; do
    case "$1" in
        --in-scope) IN_SCOPE="$2"; shift 2 ;;
        --out-of-scope) OUT_SCOPE="$2"; shift 2 ;;
        --roots) ROOTS="$2"; shift 2 ;;
        --out) OUT="$2"; shift 2 ;;
        -h|--help) usage; exit 0 ;;
        *) echo "unknown arg: $1" >&2; usage >&2; exit 2 ;;
    esac
done

[ -n "$IN_SCOPE" ] && [ -n "$OUT_SCOPE" ] && [ -n "$ROOTS" ] && [ -n "$OUT" ] || {
    usage >&2; exit 2
}
[ -s "$IN_SCOPE" ] || { echo "[subdomain_enum] in-scope file missing/empty: $IN_SCOPE" >&2; exit 1; }
[ -s "$ROOTS" ] || { echo "[subdomain_enum] roots file missing/empty: $ROOTS" >&2; exit 1; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
: > "$TMP/candidates.txt"

have() { command -v "$1" >/dev/null 2>&1; }

while IFS= read -r root; do
    [ -z "$root" ] && continue
    # Strip wildcard prefix and any path.
    root="${root#\*.}"; root="${root%%/*}"

    if have subfinder; then
        subfinder -silent -d "$root" 2>/dev/null || true
    fi
    if have assetfinder; then
        assetfinder --subs-only "$root" 2>/dev/null || true
    fi
    # crt.sh via curl (no API key required). Identity output is the cert JSON.
    if have curl; then
        curl -fsSL --max-time 20 "https://crt.sh/?q=%25.$root&output=json" 2>/dev/null \
            | if have jq; then jq -r '.[].name_value' 2>/dev/null; else sed -n 's/.*"name_value":"\([^"]*\)".*/\1/p'; fi \
            | tr 'A-Z' 'a-z' || true
    fi
    if have amass; then
        amass enum -passive -d "$root" -silent 2>/dev/null || true
    fi
done < "$ROOTS" \
    | grep -vE '^\s*$' \
    | sed -E 's/^\*\.//; s/^www\.//' \
    | tr 'A-Z' 'a-z' \
    | sort -u > "$TMP/candidates.txt"

echo "[subdomain_enum] raw candidates: $(wc -l < "$TMP/candidates.txt" | tr -d ' ')"

# Scope gate. A candidate host maps to itself; any subdomain not matching scope is dropped.
python3 "$SCOPE_CHECK" \
    --in-scope "$IN_SCOPE" --out-of-scope "$OUT_SCOPE" --hosts-only \
    < "$TMP/candidates.txt" | sort -u > "$OUT"

echo "[subdomain_enum] in-scope subdomains: $(wc -l < "$OUT" | tr -d ' ') -> $OUT"
