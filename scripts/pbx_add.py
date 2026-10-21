#!/usr/bin/env python3
"""Add Swift source files to a target in an Xcode project.pbxproj.

Usage: pbx_add.py <project.pbxproj> <target-name> <file-path> [<file-path> ...]

File paths are relative to the project root, e.g.
"Easydict/Swift/Feature/SystemService/SystemServiceProvider.swift".
Missing intermediate groups are created (as path-based <group> groups).
"""

import hashlib
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from pbx_remove import ID, children, field, parse_objects  # noqa: E402


def new_id(seed, used):
    n = 0
    while True:
        h = hashlib.md5(f"{seed}:{n}".encode()).hexdigest().upper()[:24]
        if h not in used:
            used.add(h)
            return h
        n += 1


def insert_object(text, section, obj_id, body_line):
    """Insert a single-line object definition into a section (kept sorted-ish: appended)."""
    end = f"/* End {section} section */"
    assert end in text, section
    return text.replace(end, f"\t\t{obj_id} {body_line}\n{end}", 1)


def add_child(text, group_id, child_id, comment):
    pat = re.compile(rf"(^\t\t{group_id}(?: /\*.*?\*/)? = \{{\n.*?children = \(\n)(.*?)(^\t\t\t\);)", re.M | re.S)
    m = pat.search(text)
    assert m, group_id
    return text[: m.end(2)] + f"\t\t\t\t{child_id} /* {comment} */,\n" + text[m.end(2):]


def main():
    pbx_path, target_name, files = sys.argv[1], sys.argv[2], sys.argv[3:]
    text = open(pbx_path, encoding="utf-8").read()
    used = set(re.findall(ID, text))

    for rel in files:
        objs = parse_objects(text)
        root_id = re.search(rf"rootObject = ({ID})", text).group(1)
        main_group = field(objs[root_id], "mainGroup")

        # find target and its Sources phase
        target_id = next(i for i, b in objs.items()
                         if "isa = PBXNativeTarget" in b and field(b, "name") == target_name)
        phases = re.findall(ID, re.search(r"buildPhases = \((.*?)\);", objs[target_id], re.S).group(1))
        sources_id = next(p for p in phases if "isa = PBXSourcesBuildPhase" in objs[p])

        # walk / create groups
        parts = rel.split("/")
        gid = main_group
        for comp in parts[:-1]:
            found = None
            for c in children(objs[gid]):
                b = objs.get(c, "")
                if "isa = PBXGroup" in b and (field(b, "path") == comp or (field(b, "path") is None and field(b, "name") == comp)):
                    found = c
                    break
            if found is None:
                found = new_id(f"group:{rel}:{comp}", used)
                block = (f"\t\t{found} /* {comp} */ = {{\n\t\t\tisa = PBXGroup;\n\t\t\tchildren = (\n\t\t\t);\n"
                         f"\t\t\tpath = {comp};\n\t\t\tsourceTree = \"<group>\";\n\t\t}};\n")
                end = "/* End PBXGroup section */"
                text = text.replace(end, block + end, 1)
                text = add_child(text, gid, found, comp)
                objs = parse_objects(text)
            gid = found

        name = parts[-1]
        if any(field(objs.get(c, ""), "path") == name for c in children(objs[gid])):
            print("already present", rel)
            continue
        quoted = f'"{name}"' if re.search(r"[^A-Za-z0-9_.]", name) else name
        file_id = new_id(f"file:{rel}", used)
        build_id = new_id(f"build:{rel}", used)
        text = insert_object(text, "PBXFileReference", file_id,
                             f"/* {name} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; "
                             f"path = {quoted}; sourceTree = \"<group>\"; }};")
        text = insert_object(text, "PBXBuildFile", build_id,
                             f"/* {name} in Sources */ = {{isa = PBXBuildFile; fileRef = {file_id} /* {name} */; }};")
        text = add_child(text, gid, file_id, name)
        pat = re.compile(rf"(^\t\t{sources_id}(?: /\*.*?\*/)? = \{{\n.*?files = \(\n)", re.M | re.S)
        m = pat.search(text)
        text = text[: m.end()] + f"\t\t\t\t{build_id} /* {name} in Sources */,\n" + text[m.end():]
        print("added", rel)

    open(pbx_path, "w", encoding="utf-8").write(text)


if __name__ == "__main__":
    main()
