#!/bin/bash
set -e

# HOME guard: dst (and its rm -rf) derive from HOME. An empty HOME turns
# "rm -rf $dst" into "rm -rf /.claude/skills/..." — refuse cleanly. The
# recursive remove already takes the bundled .venv with it.
if [ -z "${HOME:-}" ]; then
    echo "error: HOME unset — refusing to run uninstall.sh" >&2
    exit 1
fi

# Same resolution as install.sh: the directory you installed into.
if [ -z "${VULNHUNT_SKILLS_DIR:-${SKILLS_PARENT:-}}" ]; then
    echo "error: set VULNHUNT_SKILLS_DIR to the directory install.sh copied into." >&2
    exit 1
fi
SKILLS_PARENT="${VULNHUNT_SKILLS_DIR:-$SKILLS_PARENT}"

# Skill names to remove (must match the names install.sh writes).
SKILLS=(vulnhunt vulnhunt-fix-verify vulnhunter-fix vulnhunter-run)

removed_any=0
for name in "${SKILLS[@]}"; do
    dst="$SKILLS_PARENT/$name"
    if [ -L "$dst" ]; then
        rm "$dst"
        echo "Removed symlink $dst"
        removed_any=1
    elif [ -d "$dst" ]; then
        rm -rf "$dst"
        echo "Removed $dst"
        removed_any=1
    else
        echo "$name is not installed (no entry at $dst)"
    fi
done

if [ -n "${VULNHUNT_AGENTS_DIR:-}" ] && [ -f "$VULNHUNT_AGENTS_DIR/vulnhunter.md" ]; then
    rm -f "$VULNHUNT_AGENTS_DIR/vulnhunter.md"
    echo "Removed $VULNHUNT_AGENTS_DIR/vulnhunter.md"
    removed_any=1
fi

BIN_DIR="${VULNHUNT_BIN_DIR:-$HOME/.local/bin}"
if [ -f "$BIN_DIR/vh" ] && grep -q "vulnhunter-vh repo=$SCRIPT_DIR" "$BIN_DIR/vh"; then
    rm -f "$BIN_DIR/vh"
    echo "Removed $BIN_DIR/vh"
    removed_any=1
fi

echo ""
if [ "$removed_any" -eq 1 ]; then
    echo "Uninstalled VulnHunter skills."
else
    echo "Nothing to uninstall."
fi
