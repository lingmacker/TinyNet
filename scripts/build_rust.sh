#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CRATE_MANIFEST="$ROOT/src/rust/Cargo.toml"
OUTPUT_DIR="$ROOT/bridge/lib"

# Xcode GUI may not inherit shell PATH (cargo not found).
export PATH="$HOME/.cargo/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"

if ! command -v cargo >/dev/null 2>&1; then
  printf "error: cargo not found. Install Rust or add cargo to PATH.\n" >&2
  exit 1
fi

if [[ -n "${NATIVE_ARCH_ACTUAL:-}" ]]; then
  SELECTED_ARCH="$NATIVE_ARCH_ACTUAL"
elif [[ -n "${CURRENT_ARCH:-}" && "$CURRENT_ARCH" != "undefined_arch" ]]; then
  SELECTED_ARCH="$CURRENT_ARCH"
elif [[ -n "${ARCHS:-}" ]]; then
  case "$ARCHS" in
    *" "*) SELECTED_ARCH="$(uname -m)" ;;
    *arm64*) SELECTED_ARCH="arm64" ;;
    *x86_64*) SELECTED_ARCH="x86_64" ;;
    *) SELECTED_ARCH="$(uname -m)" ;;
  esac
else
  SELECTED_ARCH="$(uname -m)"
fi

case "$SELECTED_ARCH" in
  arm64) TARGET_TRIPLE="aarch64-apple-darwin" ;;
  x86_64) TARGET_TRIPLE="x86_64-apple-darwin" ;;
  *)
    printf "Unsupported architecture: %s\n" "$SELECTED_ARCH" >&2
    exit 1
    ;;
esac

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
