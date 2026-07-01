#!/usr/bin/env bash
set -euo pipefail

echo "======================================"
echo " VSCode / VSCodium Scoped Cleanup"
echo "======================================"

REMOTE_SERVERS_REGEX="\.vscodium-server|\.vscode-server"

is_descendant_of_remote_editor() {
    local pid="$1"

    while [[ "$pid" != "1" && -n "$pid" ]]; do
        local cmd
        cmd=$(ps -p "$pid" -o cmd= 2>/dev/null || true)

        if echo "$cmd" | grep -qE "$REMOTE_SERVERS_REGEX"; then
            return 0
        fi

        pid=$(ps -p "$pid" -o ppid= 2>/dev/null | tr -d ' ' || true)
    done

    return 1
}

kill_if_owned() {
    local label="$1"
    local pattern="$2"

    echo
    echo "[SCAN] $label"

    local found=0

    while read -r pid ppid cmd; do
        [[ -z "${pid:-}" ]] && continue
        found=1

        if is_descendant_of_remote_editor "$pid"; then
            echo "  ✔ KILL  PID=$pid  CMD=$cmd"
            kill "$pid" 2>/dev/null || true
        else
            echo "  - SKIP  PID=$pid  CMD=$cmd"
        fi
    done < <(ps -eo pid,ppid,cmd --no-headers | grep -iE "$pattern" | grep -v grep || true)

    if [[ "$found" -eq 0 ]]; then
        echo "  None found"
    fi
}

echo
echo "[1] Remote editor servers"
pgrep -af ".vscodium-server|.vscode-server" || echo "  None found"

kill_if_owned "codex" "codex"
kill_if_owned "claude" "claude"
kill_if_owned "copilot" "copilot"
kill_if_owned "extensionHost" "extensionHost"

echo
echo "[2] ripgrep / rg from VSCode or VSCodium"
kill_if_owned "ripgrep / rg" '(^|/| )rg( |$)|ripgrep'

echo
echo "======================================"
echo " FINAL CHECK"
echo "======================================"

ps aux | grep -iE "vscodium|vscode|codex|claude|copilot|ripgrep|extensionHost" | grep -v grep || echo "Clean"

echo
echo "Done."
