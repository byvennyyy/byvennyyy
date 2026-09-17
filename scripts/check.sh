#!/usr/bin/env bash
# Lint, typecheck and format-check every Luau source file.
# Requires rojo, luau-lsp and stylua on PATH (see rokit.toml) and a Roblox
# definitions file. Set LUAU_DEFS to override the definitions path.
set -euo pipefail
cd "$(dirname "$0")/.."
DEFS="${LUAU_DEFS:-globalTypes.d.luau}"
if [ ! -f "$DEFS" ]; then
	echo "Downloading Roblox type definitions to $DEFS"
	curl -sSL -o "$DEFS" https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/main/scripts/globalTypes.d.luau
fi
rojo sourcemap default.project.json -o sourcemap.json
luau-lsp analyze --definitions="$DEFS" --base-luaurc=.luaurc --sourcemap=sourcemap.json --no-strict-dm-types src/
stylua --check src/
echo "All checks passed."
