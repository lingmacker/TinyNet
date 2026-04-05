#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CRATE_MANIFEST="$ROOT/src/rust/Cargo.toml"
OUTPUT_DIR="$ROOT/bridge/lib"

if [[ -n "${ARCHS:-}" ]]; then
  case "$ARCHS" in
    *x86_64*) TARGET_TRIPLE="x86_64-apple-darwin" ;;
    *) TARGET_TRIPLE="aarch64-apple-darwin" ;;
  esac
else
  case "$(uname -m)" in
    x86_64) TARGET_TRIPLE="x86_64-apple-darwin" ;;
    arm64) TARGET_TRIPLE="aarch64-apple-darwin" ;;
    *)
      printf "Unsupported architecture: %s\n" "$(uname -m)" >&2
      exit 1
      ;;
  esac
fi

mkdir -p "$OUTPUT_DIR"

if [[ "${CONFIGURATION:-Debug}" == "Release" ]]; then
  cargo build --manifest-path "$CRATE_MANIFEST" --release --target "$TARGET_TRIPLE"
  PROFILE_DIR="release"
else
  cargo build --manifest-path "$CRATE_MANIFEST" --target "$TARGET_TRIPLE"
  PROFILE_DIR="debug"
fi

cp "$ROOT/target/$TARGET_TRIPLE/$PROFILE_DIR/libnet_speed_core.a" "$OUTPUT_DIR/libnet_speed_core.a"
cp "$ROOT/target/$TARGET_TRIPLE/$PROFILE_DIR/libnet_speed_core.dylib" "$OUTPUT_DIR/libnet_speed_core.dylib"

printf "Rust artifacts copied to %s (target: %s, profile: %s)\n" "$OUTPUT_DIR" "$TARGET_TRIPLE" "$PROFILE_DIR"
