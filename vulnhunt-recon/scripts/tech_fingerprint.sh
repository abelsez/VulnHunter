#!/usr/bin/env bash
# Low-rate, scope-gated live-host and technology fingerprinting.
# Uses httpx (title/tech/status/redirects), optional wafw00f and nuclei
# tech-detect. Every host is scope-filtered before any request is made.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCOPE_CHECK="$SCRIPT_DIR/scope_check.py"

usage() {
    cat <<'EOF'
Usage: tech_fingerprint.sh --in-scope FILE --out-of-scope FILE --hosts FILE --out FILE [--rate N]
  Low-rate HTTP fingerprint of in-scope hosts.
EOF
}

IN_SCOPE=""; OUT_SCOPE=""; HOSTS=""; OUT=""; RATE=25
while [ $# -gt 0 ]; do
    case "$1" in
        --in-scope) IN_SCOPE="$2"; shift 2 ;;
        --out-of-scope) OUT_SCOPE="$2"; shift 2 ;;
        --hosts) HOSTS="$2"; shift 2 ;;
        --out) OUT="$2"; shift 2 ;;
        --rate) RATE="$2"; shift 2 ;;
        -h|--help) usage; exit 0 ;;
        *) echo "unknown arg: $1" >&2; usage >&2; exit 2 ;;
    esac
done

[ -n "$IN_SCOPE" ] && [ -n "$OUT_SCOPE" ] && [ -n "$HOSTS" ] && [ -n "$OUT" ] || {
    usage >&2; exit 2
}
[ -s "$HOSTS" ] || { echo "[tech_fingerprint] hosts file missing/empty: $HOSTS" >&2; exit 1; }

have() { command -v "$1" >/dev/null 2>&1; }

# Scope gate before any network request.
SCOPED="$(mktemp)"
trap 'rm -f "$SCOPED"' EXIT
python3 "$SCOPE_CHECK" \
    --in-scope "$IN_SCOPE" --out-of-scope "$OUT_SCOPE" --hosts-only \
    < "$HOSTS" | sort -u > "$SCOPED"

echo "[tech_fingerprint] in-scope hosts to probe: $(wc -l < "$SCOPED" | tr -d ' ')"

: > "$OUT"
if have httpx; then
    httpx -silent -l "$SCOPED" \
        -title -tech-detect -status-code -content-length -location \
        -rate-limit "$RATE" -retries 1 \
        -o "$OUT" || true
else
    echo "[tech_fingerprint] httpx not found; skipping HTTP fingerprint." >&2
fi

if have wafw00f; then
    while IFS= read -r host; do
        [ -z "$host" ] && continue
        wafw00f -a "https://$host" 2>/dev/null || true
    done < "$SCOPED" >> "${OUT}.waf" || true
fi

if have nuclei; then
    nuclei -l "$SCOPED" -t technologies/ -silent -rate-limit "$RATE" 2>/dev/null \
        >> "${OUT}.tech" || true
fi

echo "[tech_fingerprint] results: $(wc -l < "$OUT" | tr -d ' ') -> $OUT"
