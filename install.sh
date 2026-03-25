#!/bin/bash
#
# trex install script
#
# Usage:
#   curl -sL https://raw.githubusercontent.com/robbinfan/trex/main/install.sh | bash
#   # or
#   ./install.sh [--target REPO_DIR] [--platform claude|codex|cursor|all]
#
set -e

# Parse named arguments (with fallback to positional for backwards compat)
TARGET="."
PLATFORM="claude"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target)
      TARGET="$2"
      shift 2
      ;;
    --platform)
      PLATFORM="$2"
      shift 2
      ;;
    -*)
      echo "Unknown option: $1" >&2
      echo "Usage: ./install.sh [--target REPO_DIR] [--platform claude|codex|cursor|all]" >&2
      exit 1
      ;;
    *)
      # Positional fallback: first positional = target, second = platform
      if [[ "$TARGET" == "." ]]; then
        TARGET="$1"
      elif [[ "$PLATFORM" == "claude" ]]; then
        PLATFORM="$1"
      fi
      shift
      ;;
  esac
done

TREX_DIR="$TARGET/.claude/tools/trex"

echo "Installing trex to $TREX_DIR ..."

# Create tool directory
mkdir -p "$TREX_DIR"

# Copy source
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cp "$SCRIPT_DIR/main.go" "$TREX_DIR/"
cp "$SCRIPT_DIR/go.mod" "$TREX_DIR/"

# Build
echo "Building trex..."
(cd "$TREX_DIR" && go build -o trex .)

# Build index
echo "Building trigram index..."
"$TREX_DIR/trex" build --dir "$TARGET"

# Install skill definition
case "$PLATFORM" in
  claude|all)
    echo "Installing Claude Code skill..."
    mkdir -p "$TARGET/.claude/skills"
    cp "$SCRIPT_DIR/skills/claude/skill.md" "$TARGET/.claude/skills/trex.md"
    ;;
esac

# Append to .gitignore if entries are missing
GITIGNORE="$TARGET/.gitignore"
ENTRIES=(
  ".claude/tools/trex/trex"
  ".claude/trigram-index.bin"
)
for entry in "${ENTRIES[@]}"; do
  if [ ! -f "$GITIGNORE" ] || ! grep -qxF "$entry" "$GITIGNORE"; then
    echo "$entry" >> "$GITIGNORE"
    echo "Added '$entry' to .gitignore"
  fi
done

echo ""
echo "Done! trex installed at $TREX_DIR"
echo ""
echo "Usage:"
echo "  $TREX_DIR/trex search --pattern 'YourPattern' --root $TARGET --files-only"
echo ""
echo "To rebuild index after file changes:"
echo "  $TREX_DIR/trex update --dir $TARGET"
