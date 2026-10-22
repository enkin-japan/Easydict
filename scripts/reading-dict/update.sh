#!/bin/sh
set -eu

# Regenerates the bundled reading dictionaries used by the Reading service.
# Sources are pinned so the generated resources are reproducible; bump the
# pins below to pick up upstream fixes, then commit the regenerated files.

cd "$(dirname "$0")/../.."

PHRASE_PINYIN_COMMIT="cee0ed6e6e4898580cafd2bd5e3723e20b214aa0"
CHAR_PINYIN_COMMIT="9e5e9bdfe8add694300e0cc93a27b803b68377f9"
JMDICT_FURIGANA_TAG="2.3.1%2B2026-09-25"

OUTPUT_DIR="Easydict/Swift/Service/Reading/Resources"
WORK_DIR=$(mktemp -d)
trap 'rm -rf "$WORK_DIR"' EXIT

fetch() {
  curl -sSfL -o "$WORK_DIR/$1" "$2"
}

fetch large_pinyin.txt \
  "https://raw.githubusercontent.com/mozillazg/phrase-pinyin-data/$PHRASE_PINYIN_COMMIT/large_pinyin.txt"
fetch char_pinyin.txt \
  "https://raw.githubusercontent.com/mozillazg/pinyin-data/$CHAR_PINYIN_COMMIT/pinyin.txt"
fetch JmdictFurigana.txt \
  "https://github.com/Doublevil/JmdictFurigana/releases/download/$JMDICT_FURIGANA_TAG/JmdictFurigana.txt"

mkdir -p "$OUTPUT_DIR"
swift scripts/reading-dict/generate.swift "$WORK_DIR" "$OUTPUT_DIR"
