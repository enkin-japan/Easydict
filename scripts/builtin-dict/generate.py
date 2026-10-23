#!/usr/bin/env python3
"""Builds the bundled dictionary database used by the Built-in Dictionary service.

Usage: generate.py <source-dir> <output-dir>

<source-dir> holds the files fetched by update.sh:
  ecdict.csv                     ECDICT (English -> Chinese)
  jmdict-examples-eng-*.json     JMdict with Tatoeba examples (jmdict-simplified)
  kanjidic2-en-*.json            KANJIDIC2 (jmdict-simplified)
  accents.txt                    Kanjium pitch accent data

Writes <output-dir>/builtin-dictionary.sqlite (the caller compresses it). Japanese keys are
normalized with `normalize_key`, which BuiltinDictionaryStore.normalizedJapaneseKey mirrors.
"""

import csv
import glob
import json
import os
import re
import sqlite3
import sys
import unicodedata

SCHEMA_VERSION = 1

# ECDICT `exchange` codes that name an inflected form of the entry's word.
ENGLISH_FORM_CODES = {"p", "d", "i", "3", "r", "t", "s"}


def normalize_key(text):
    """NFKC, then katakana -> hiragana, so カタカナ, ｶﾀｶﾅ and かたかな share a key."""
    text = unicodedata.normalize("NFKC", text)
    return "".join(
        chr(ord(ch) - 0x60) if "ァ" <= ch <= "ヶ" else ch for ch in text
    )


def as_int(value):
    try:
        return int(value or 0)
    except ValueError:
        return 0


def build_english(db, path):
    # `key` is the lowercased word; case variants (May / may) are separate rows.
    db.execute(
        """CREATE TABLE en (
            key TEXT NOT NULL, word TEXT NOT NULL, phonetic TEXT, translation TEXT,
            definition TEXT, pos TEXT, collins INTEGER, oxford INTEGER, tag TEXT,
            bnc INTEGER, frq INTEGER, exchange TEXT, PRIMARY KEY (key, word)) WITHOUT ROWID"""
    )
    db.execute(
        """CREATE TABLE en_form (
            form TEXT NOT NULL, word TEXT NOT NULL, kind TEXT NOT NULL,
            PRIMARY KEY (form, word, kind)) WITHOUT ROWID"""
    )

    rows = forms = 0
    with open(path, encoding="utf-8") as file:
        for row in csv.DictReader(file):
            translation = row["translation"].replace("\\n", "\n").strip()
            if not translation:
                continue
            word = row["word"].strip()
            bnc, frq, collins = as_int(row["bnc"]), as_int(row["frq"]), as_int(row["collins"])
            oxford = as_int(row["oxford"])
            # English definitions (mostly WordNet) only for words with frequency data; they
            # roughly double the size and matter little next to the Chinese translation.
            ranked = bnc or frq or collins or oxford
            # ECDICT lists ~370k multi-word terms, nearly all unranked technical jargon; keep
            # ranked ones and short lowercase phrases with a general (untagged) meaning.
            if " " in word and not (ranked or row["tag"].strip()):
                general = any(not line.startswith("[") for line in translation.split("\n"))
                if len(word.split()) > 3 or not word.islower() or not general:
                    continue
            definition = row["definition"].replace("\\n", "\n").strip() if ranked else ""
            exchange = row["exchange"].strip()
            db.execute(
                "INSERT OR IGNORE INTO en VALUES (?,?,?,?,?,?,?,?,?,?,?,?)",
                (word.lower(), word, row["phonetic"].strip(), translation, definition, row["pos"].strip(),
                 collins, oxford, row["tag"].strip(), bnc, frq, exchange),
            )
            rows += 1
            for item in exchange.split("/"):
                code, _, form = item.partition(":")
                if code in ENGLISH_FORM_CODES and form and form.lower() != word.lower():
                    db.execute("INSERT OR IGNORE INTO en_form VALUES (?,?,?)", (form.lower(), word, code))
                    forms += 1

    return rows, forms


def load_accents(path):
    accents = {}
    with open(path, encoding="utf-8") as file:
        for line in file:
            parts = line.rstrip("\n").split("\t")
            if len(parts) != 3:
                continue
            expression, reading, accent = parts
            accents[(expression, reading or expression)] = accent
    return accents


def compact_sense(sense):
    item = {"p": sense["partOfSpeech"], "g": [g["text"] for g in sense["gloss"]]}
    for key, name in (("misc", "m"), ("field", "f"), ("dialect", "d"), ("info", "i")):
        if sense.get(key):
            item[name] = sense[key]
    if sense["appliesToKanji"] != ["*"]:
        item["ak"] = sense["appliesToKanji"]
    if sense["appliesToKana"] != ["*"]:
        item["ar"] = sense["appliesToKana"]
    examples = []
    for example in sense.get("examples") or []:
        sentences = {s["lang"]: s["text"] for s in example["sentences"]}
        if "jpn" in sentences and "eng" in sentences:
            examples.append([sentences["jpn"], sentences["eng"]])
    if examples:
        item["x"] = examples[:2]
    return item


def build_japanese(db, jmdict_path, accents_path):
    accents = load_accents(accents_path)
    db.execute("CREATE TABLE ja (id INTEGER PRIMARY KEY, common INTEGER NOT NULL, entry TEXT NOT NULL)")
    db.execute(
        """CREATE TABLE ja_key (key TEXT NOT NULL, id INTEGER NOT NULL, kana INTEGER NOT NULL,
            PRIMARY KEY (key, id, kana)) WITHOUT ROWID"""
    )

    with open(jmdict_path, encoding="utf-8") as file:
        words = json.load(file)["words"]

    with_accent = 0
    for word in words:
        kanji_forms = [k["text"] for k in word["kanji"]]
        readings = []
        for kana in word["kana"]:
            applies = kana["appliesToKanji"]
            candidates = kanji_forms if applies == ["*"] else applies
            accent = next(
                (accents[(k, kana["text"])] for k in candidates if (k, kana["text"]) in accents),
                None,
            ) or accents.get((kana["text"], kana["text"]))
            item = [kana["text"], int(kana["common"])]
            if accent or applies != ["*"] or kana["tags"]:
                item.append(accent or "")
            if applies != ["*"] or kana["tags"]:
                item.append(applies)
            if kana["tags"]:
                item.append(kana["tags"])
            readings.append(item)
            with_accent += bool(accent)

        entry = {
            "k": [[k["text"], int(k["common"])] + ([k["tags"]] if k["tags"] else []) for k in word["kanji"]],
            "r": readings,
            "s": [compact_sense(s) for s in word["sense"]],
        }
        common = int(any(k["common"] for k in word["kanji"]) or any(k["common"] for k in word["kana"]))
        entry_id = int(word["id"])
        db.execute(
            "INSERT INTO ja VALUES (?,?,?)",
            (entry_id, common, json.dumps(entry, ensure_ascii=False, separators=(",", ":"))),
        )
        keys = {(normalize_key(k), 0) for k in kanji_forms}
        keys |= {(normalize_key(k["text"]), 1) for k in word["kana"]}
        db.executemany("INSERT INTO ja_key VALUES (?,?,?)", [(k, entry_id, kana) for k, kana in keys])

    return len(words), with_accent


def build_kanji(db, path):
    db.execute("CREATE TABLE kanji (literal TEXT PRIMARY KEY, entry TEXT NOT NULL) WITHOUT ROWID")
    with open(path, encoding="utf-8") as file:
        characters = json.load(file)["characters"]
    for character in characters:
        groups = (character.get("readingMeaning") or {}).get("groups") or []
        readings = [r for g in groups for r in g["readings"]]
        entry = {
            "on": [r["value"] for r in readings if r["type"] == "ja_on"],
            "kun": [r["value"] for r in readings if r["type"] == "ja_kun"],
            "py": [r["value"] for r in readings if r["type"] == "pinyin"],
            "m": [m["value"] for g in groups for m in g["meanings"] if m["lang"] == "en"],
        }
        misc = character["misc"]
        for key, name in (("grade", "g"), ("jlptLevel", "j"), ("frequency", "f")):
            if misc.get(key):
                entry[name] = misc[key]
        if misc.get("strokeCounts"):
            entry["s"] = misc["strokeCounts"][0]
        db.execute(
            "INSERT INTO kanji VALUES (?,?)",
            (character["literal"], json.dumps(entry, ensure_ascii=False, separators=(",", ":"))),
        )
    return len(characters)


def main():
    source_dir, output_dir = sys.argv[1], sys.argv[2]
    output = os.path.join(output_dir, "builtin-dictionary.sqlite")
    if os.path.exists(output):
        os.remove(output)

    db = sqlite3.connect(output)
    db.execute("PRAGMA page_size = 4096")
    db.execute("CREATE TABLE meta (key TEXT PRIMARY KEY, value TEXT NOT NULL)")

    en_rows, en_forms = build_english(db, os.path.join(source_dir, "ecdict.csv"))
    jmdict = glob.glob(os.path.join(source_dir, "jmdict-examples-eng-*.json"))[0]
    ja_rows, ja_accents = build_japanese(db, jmdict, os.path.join(source_dir, "accents.txt"))
    kanji_path = glob.glob(os.path.join(source_dir, "kanjidic2-en-*.json"))[0]
    kanji_rows = build_kanji(db, kanji_path)

    db.execute("INSERT INTO meta VALUES ('schema_version', ?)", (str(SCHEMA_VERSION),))
    db.commit()
    db.execute("VACUUM")
    db.close()

    print(f"English: {en_rows} entries, {en_forms} inflected forms")
    print(f"Japanese: {ja_rows} entries, {ja_accents} readings with pitch accent")
    print(f"Kanji: {kanji_rows} characters")
    print(f"{output}: {os.path.getsize(output) / 1e6:.1f} MB")


if __name__ == "__main__":
    main()
