#!/usr/bin/env bash
# Runs every tests/*.spec.luau under the standalone luau CLI against the pure Shared modules.
# Requires `luau` on PATH (from https://github.com/luau-lang/luau/releases) or LUAU=/path/to/luau.
set -uo pipefail
cd "$(dirname "$0")/.."
LUAU="${LUAU:-luau}"
BUILD=tests/build
rm -rf "$BUILD"
python3 tests/preprocess.py "$BUILD" $(find src/ReplicatedStorage/Shared -name '*.luau')
cp tests/assert.luau "$BUILD/assert.luau"
status=0
for spec in tests/*.spec.luau; do
	name=$(basename "$spec")
	cp "$spec" "$BUILD/$name"
	echo "== $name"
	if ! "$LUAU" "$BUILD/$name"; then status=1; fi
done
[ $status -eq 0 ] && echo "All specs passed." || echo "Some specs FAILED."
exit $status
