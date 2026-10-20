#!/usr/bin/env bash
# Exercise real pinned archives offline, after prepare-deps.sh has populated the cache.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CACHE="${PHOTOCRAFT_DEPENDENCY_CACHE:-$ROOT/.patched-deps/archives}"
TMP="$(mktemp -d)"
trap 'rm -rf -- "$TMP"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }

mkdir -p "$TMP/project/scripts" "$TMP/project/patches" "$TMP/empty-cache"
cp "$ROOT/scripts/prepare-deps.sh" "$TMP/project/scripts/"
cp "$ROOT/patches/winit-0.30.13.patch" "$ROOT/patches/egui-winit-0.36.2.patch" "$TMP/project/patches/"
PREPARE="$TMP/project/scripts/prepare-deps.sh"
DEPS="$TMP/project/.patched-deps"

# Fresh source preparation is possible with networking disabled and verified archives preseeded.
PHOTOCRAFT_DEPENDENCY_CACHE="$CACHE" bash "$PREPARE" --offline
PHOTOCRAFT_DEPENDENCY_CACHE="$TMP/empty-cache" bash "$PREPARE" --offline

# Do not silently overwrite a developer's changes to generated sources.
printf '\n// local change\n' >> "$DEPS/winit-0.30.13/src/lib.rs"
if PHOTOCRAFT_DEPENDENCY_CACHE="$CACHE" bash "$PREPARE" --offline; then
  fail 'modified dependency sources were accepted'
fi
rm -rf -- "$DEPS/winit-0.30.13"
PHOTOCRAFT_DEPENDENCY_CACHE="$CACHE" bash "$PREPARE" --offline

# A patch that no longer applies must fail without damaging the working dependency tree.
cp -a "$DEPS/winit-0.30.13" "$TMP/working-winit"
printf '\n--- a/missing-file\n+++ b/missing-file\n@@ -1 +1 @@\n-old\n+new\n' >> "$TMP/project/patches/winit-0.30.13.patch"
if PHOTOCRAFT_DEPENDENCY_CACHE="$CACHE" bash "$PREPARE" --offline; then
  fail 'an inapplicable patch was accepted'
fi
diff -r "$TMP/working-winit" "$DEPS/winit-0.30.13" || fail 'failed patch damaged prepared sources'
cp "$ROOT/patches/winit-0.30.13.patch" "$TMP/project/patches/"

# Corrupt/missing archives fail closed before publishing any source directory.
rm -rf -- "$DEPS/winit-0.30.13"
mkdir "$TMP/corrupt-cache"
cp "$CACHE/winit-0.30.13.crate" "$TMP/corrupt-cache/"
printf 'corruption' >> "$TMP/corrupt-cache/winit-0.30.13.crate"
if PHOTOCRAFT_DEPENDENCY_CACHE="$TMP/corrupt-cache" bash "$PREPARE" --offline; then
  fail 'corrupt archive was accepted'
fi
[ ! -e "$DEPS/winit-0.30.13" ] || fail 'corrupt archive published dependency sources'
if PHOTOCRAFT_DEPENDENCY_CACHE="$TMP/empty-cache" bash "$PREPARE" --offline; then
  fail 'offline preparation succeeded without its archive'
fi
[ ! -e "$DEPS/winit-0.30.13" ] || fail 'missing archive published dependency sources'

echo 'dependency source preparation integrity checks passed'
