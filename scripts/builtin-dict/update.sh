#!/bin/sh
set -eu

# Regenerates the bundled database used by the Built-in Dictionary service.
# Sources are pinned so the generated resource is reproducible; bump the pins
# below to pick up upstream fixes, then commit the regenerated file.

cd "$(dirname "$0")/../.."

ECDICT_COMMIT="bc015ed2e24a7abef49fc6dbbb7fe32c1dadaf8b"
KANJIUM_COMMIT="9ebca4589565c696e7c39e089e2e928ad65f678c"
JMDICT_SIMPLIFIED_TAG="3.6.2+20261019180022"

OUTPUT_DIR="Easydict/Swift/Service/Dictionary/Builtin/Resources"
WORK_DIR=$(mktemp -d)
trap 'rm -rf "$WORK_DIR"' EXIT

fetch() {
  curl -sSfL -o "$WORK_DIR/$1" "$2"
}

JMDICT_RELEASE="https://github.com/scriptin/jmdict-simplified/releases/download/$(printf %s "$JMDICT_SIMPLIFIED_TAG" | sed 's/+/%2B/')"

fetch ecdict.csv \
  "https://raw.githubusercontent.com/skywind3000/ECDICT/$ECDICT_COMMIT/ecdict.csv"
fetch accents.txt \
  "https://raw.githubusercontent.com/mifunetoshiro/kanjium/$KANJIUM_COMMIT/data/source_files/raw/accents.txt"
fetch jmdict.tgz "$JMDICT_RELEASE/jmdict-examples-eng-$JMDICT_SIMPLIFIED_TAG.json.tgz"
fetch kanjidic.tgz "$JMDICT_RELEASE/kanjidic2-en-$JMDICT_SIMPLIFIED_TAG.json.tgz"
tar -xzf "$WORK_DIR/jmdict.tgz" -C "$WORK_DIR"
tar -xzf "$WORK_DIR/kanjidic.tgz" -C "$WORK_DIR"

mkdir -p "$OUTPUT_DIR"
python3 -I scripts/builtin-dict/generate.py "$WORK_DIR" "$WORK_DIR"
# LZMA: ~26 MB instead of ~36 MB with LZFSE; the app decompresses it once (~0.7 s).
compression_tool -encode -a lzma -i "$WORK_DIR/builtin-dictionary.sqlite" \
  -o "$OUTPUT_DIR/builtin-dictionary.sqlite.xz"
