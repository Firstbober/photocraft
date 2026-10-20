#!/usr/bin/env bash
# Prepare patched crates before Cargo resolves the workspace. Never edit Cargo's registry cache.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEPS="$ROOT/.patched-deps"
CACHE="${PHOTOCRAFT_DEPENDENCY_CACHE:-$DEPS/archives}"
OFFLINE=false
case "${1:-}" in
  --offline) OFFLINE=true; shift ;;
  --help) echo 'Usage: bash scripts/prepare-deps.sh [--offline]'; exit 0 ;;
  '') ;;
  *) echo "error: unknown argument: $1" >&2; exit 1 ;;
esac
if [ "$#" -ne 0 ]; then echo 'error: too many arguments' >&2; exit 1; fi

if command -v sha256sum >/dev/null 2>&1; then
  HASH=(sha256sum)
elif command -v shasum >/dev/null 2>&1; then
  HASH=(shasum -a 256)
else
  echo 'error: install sha256sum or shasum to verify dependency sources' >&2
  exit 1
fi
sha256() { "${HASH[@]}" "$1" | cut -d' ' -f1; }
source_digest() {
  (
    cd "$1"
    # Cargo may write a target directory when a patched crate is tested directly.
    find . -type f ! -name .prepared ! -path './target/*' -exec "${HASH[@]}" {} + |
      LC_ALL=C sort | "${HASH[@]}" | cut -d' ' -f1
  )
}

mkdir -p "$DEPS" "$CACHE"
# Keep independent preparation processes from replacing sources under each other.
if ! mkdir "$DEPS/.prepare-lock" 2>/dev/null; then
  echo "error: dependency preparation is already running; if interrupted, remove $DEPS/.prepare-lock" >&2
  exit 1
fi
STAGE=''
DOWNLOAD=''
cleanup() {
  if [ -n "$STAGE" ]; then rm -rf -- "$STAGE"; fi
  if [ -n "$DOWNLOAD" ]; then rm -f -- "$DOWNLOAD"; fi
  rmdir "$DEPS/.prepare-lock"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

prepare() {
  local name="$1" version="$2" expected="$3" package archive patch signature marker old_signature old_digest
  package="$name-$version"
  archive="$CACHE/$package.crate"
  patch="$ROOT/patches/$package.patch"
  signature="$(printf '%s\n' "$expected" "$(sha256 "$patch")" "$(sha256 "${BASH_SOURCE[0]}")" | "${HASH[@]}" | cut -d' ' -f1)"
  marker="$DEPS/$package/.prepared"

  if [ -f "$marker" ]; then
    { IFS= read -r old_signature; IFS= read -r old_digest; } < "$marker"
    if [ "$(source_digest "$DEPS/$package")" != "$old_digest" ]; then
      echo "error: prepared sources changed: $DEPS/$package; inspect your edits, then remove that generated directory to regenerate" >&2
      return 1
    fi
    if [ "$old_signature" = "$signature" ]; then
      echo "Prepared $package (verified)"
      return 0
    fi
  elif [ -e "$DEPS/$package" ]; then
    echo "error: unrecognized generated directory: $DEPS/$package; remove it to regenerate" >&2
    return 1
  fi

  if [ -f "$archive" ]; then
    if [ "$(sha256 "$archive")" != "$expected" ]; then
      echo "error: SHA-256 mismatch: $archive; remove the corrupt archive before retrying" >&2
      return 1
    fi
  elif [ "$OFFLINE" = true ]; then
    echo "error: offline dependency archive missing: $archive" >&2
    return 1
  else
    DOWNLOAD="$(mktemp "$CACHE/.$package.XXXXXX")"
    curl --fail --location --silent --show-error --user-agent Photocraft-dev \
      "https://static.crates.io/crates/$name/$package.crate" --output "$DOWNLOAD"
    if [ "$(sha256 "$DOWNLOAD")" != "$expected" ]; then
      echo "error: SHA-256 mismatch downloading $package" >&2
      return 1
    fi
    mv "$DOWNLOAD" "$archive"
    DOWNLOAD=''
  fi

  STAGE="$(mktemp -d "$DEPS/.prepare.XXXXXX")"
  tar -xzf "$archive" -C "$STAGE"
  (
    # Do not let git discover the application repository or an inherited Git worktree.
    unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE
    export GIT_CEILING_DIRECTORIES="$STAGE"
    cd "$STAGE/$package"
    git -c core.autocrlf=false apply --check --whitespace=error-all "$patch"
    git -c core.autocrlf=false apply --whitespace=error-all "$patch"
  )
  printf '%s\n%s\n' "$signature" "$(source_digest "$STAGE/$package")" > "$STAGE/$package/.prepared"
  # A failed download or patch never replaces a previously prepared crate.
  if [ -d "$DEPS/$package" ]; then mv "$DEPS/$package" "$STAGE/previous"; fi
  mv "$STAGE/$package" "$DEPS/$package"
  rm -rf -- "$STAGE"
  STAGE=''
  echo "Prepared $package"
}

# Crates.io archive checksums; patch provenance is recorded in ATTRIBUTION.md.
prepare winit 0.30.13 a6755fa58a9f8350bd1e472d4c3fcc25f824ec358933bba33306d0b63df5978d
prepare egui-winit 0.36.2 98466000559d66ba4db786a30448b01483946add4188e7f10f522a27b4fb89cc
