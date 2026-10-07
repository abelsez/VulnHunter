#!/usr/bin/env bash
# Passive URL and parameter collection, scope-gated.
# Sources: gau, waybackurls, katana (passive crawl only). Missing tools are
# skipped silently; every URL passes through scope_check.py before output.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCOPE_CHECK="$SCRIPT_DIR/scope_check.py"

usage() {
    cat <<'EOF'
Usage: endpoint_discovery.sh --in-scope FILE --out-of-scope FILE --roots FILE --out FILE
  Passive URL/parameter collection, filtered by scope. Writes urls to --out and
  params to <out dir>/params.txt.
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
[ -s "$ROOTS" ] || { echo "[endpoint_discovery] roots file missing/empty: $ROOTS" >&2; exit 1; }

OUT_DIR="$(dirname "$OUT")"
mkdir -p "$OUT_DIR"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
: > "$TMP/urls.raw.txt"

have() { command -v "$1" >/dev/null 2>&1; }

while IFS= read -r root; do
    [ -z "$root" ] && continue
    root="${root#\*.}"; root="${root%%/*}"

    if have gau; then
        gau --subs "$root" 2>/dev/null || true
    fi
    if have waybackurls; then
        echo "$root" | waybackurls 2>/dev/null || true
    fi
    if have katana; then
        # Passive sources only for recon; no active crawling here.
        katana -u "https://$root" -passive -silent 2>/dev/null || true
    fi
done < "$ROOTS" \
    | grep -vE '^\s*$' \
    | grep -E '^https?://' \
    | sort -u > "$TMP/urls.raw.txt"

echo "[endpoint_discovery] raw URLs: $(wc -l < "$TMP/urls.raw.txt" | tr -d ' ')"

# Scope gate on URL hosts.
python3 "$SCOPE_CHECK" \
    --in-scope "$IN_SCOPE" --out-of-scope "$OUT_SCOPE" \
    < "$TMP/urls.raw.txt" | sort -u > "$OUT"

echo "[endpoint_discovery] in-scope URLs: $(wc -l < "$OUT" | tr -d ' ') -> $OUT"

# Extract parameter names (no value leakage).
if have unfurl; then
    unfurl -u keys < "$OUT" 2>/dev/null | sort -u > "$OUT_DIR/params.txt" || true
else
    grep -oE '[?&][A-Za-z0-9_%.-]+=' "$OUT" 2>/dev/null \
        | sed -E 's/^[?&]//; s/=$//' | sort -u > "$OUT_DIR/params.txt" || true
fi
echo "[endpoint_discovery] parameters: $(wc -l < "$OUT_DIR/params.txt" | tr -d ' ') -> $OUT_DIR/params.txt"
