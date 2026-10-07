#!/usr/bin/env bash
# Installs passive-first recon tooling used by the vulnhunt-recon helper
# scripts. Skips tools that are already present or whose installer is absent.
# Go-based tools need a working Go toolchain (or prebuilt binaries on PATH).
set -euo pipefail

have() { command -v "$1" >/dev/null 2>&1; }

# Package-manager install for apt/pkg (Debian/Ubuntu, Kali, Termux).
pkg_install() {
    if have apt-get; then
        sudo apt-get update -y && sudo apt-get install -y "$@"
    elif have pkg; then
        pkg install -y "$@"
    else
        echo "[install] no apt-get/pkg; install manually: $*" >&2
    fi
}

# go install wrapper (go1.16+). Binaries land in GOBIN or ~/go/bin.
go_install() {
    if ! have go; then
        echo "[install] go not found; skipping: $1" >&2
        return 1
    fi
    go install "$1@latest" || echo "[install] failed: $1" >&2
}

echo "[install] passive recon tooling for vulnhunt-recon"

# Passive subdomain enumeration.
have subfinder  || pkg_install subfinder
have assetfinder || go_install github.com/tomnomnom/assetfinder
have amass      || pkg_install amass

# Passive URL/archive collection.
have gau        || go_install github.com/lc/gau/v2/cmd/gau
have waybackurls|| go_install github.com/tomnomnom/waybackurls
have katana     || pkg_install katana

# Fingerprinting.
have httpx      || go_install github.com/projectdiscovery/httpx/cmd/httpx
have nuclei     || go_install github.com/projectdiscovery/nuclei/v3/cmd/nuclei
have wafw00f    || pip install wafw00f 2>/dev/null || true

# Parameter/URL parsing.
have unfurl     || go_install github.com/tomnomnom/unfurl

# Secret scanning (optional; records locations only).
have gitleaks   || go_install github.com/gitleaks/gitleaks/v8

echo "[install] done. Run: bash scripts/subdomain_enum.sh --help"
