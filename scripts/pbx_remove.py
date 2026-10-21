#!/usr/bin/env python3
"""Remove files / folders from an Xcode project.pbxproj (Xcode-formatted text).

Usage: pbx_remove.py <project.pbxproj> <path-prefix> [<path-prefix> ...]
       pbx_remove.py <project.pbxproj> --package <repo-url-part> [...]

Path prefixes are relative to the project root (the folder containing the
.xcodeproj), e.g. "Easydict/Swift/Feature/Screenshot".  Every PBXFileReference
and PBXGroup whose resolved path is equal to or below a prefix is removed,
together with its PBXBuildFile entries and every list entry that points at
the removed objects.  Prints what it removed.
"""

import re
import sys

ID = r"[0-9A-F]{24}"


def parse_objects(text):
    """Return {id: body_text} for every object definition."""
    objs = {}
    # single-line objects: \t\tID /* x */ = {isa = ...; };
    for m in re.finditer(rf"^\t\t({ID})(?: /\*.*?\*/)? = \{{(.*?)\}};$", text, re.M):
        objs[m.group(1)] = m.group(2)
    # multi-line objects
    for m in re.finditer(rf"^\t\t({ID})(?: /\*.*?\*/)? = \{{\n(.*?)^\t\t\}};$", text, re.M | re.S):
        objs[m.group(1)] = m.group(2)
    return objs


def field(body, name):
    m = re.search(rf"\b{name} = (\"(?:[^\"\\]|\\.)*\"|[^;]+);", body)
    if not m:
        return None
    v = re.sub(r"\s*/\*.*?\*/", "", m.group(1)).strip()
    if v.startswith('"'):
        v = v[1:-1]
    return v


def children(body):
    m = re.search(r"children = \((.*?)\);", body, re.S)
    return re.findall(ID, m.group(1)) if m else []


def main():
    pbx_path, prefixes = sys.argv[1], [p.rstrip("/") for p in sys.argv[2:]]
    text = open(pbx_path, encoding="utf-8").read()
    objs = parse_objects(text)

    root_id = re.search(rf"rootObject = ({ID})", text).group(1)
    main_group = field(objs[root_id], "mainGroup")

    paths = {}  # id -> resolved path

    def walk(gid, base):
        body = objs.get(gid, "")
        tree = field(body, "sourceTree")
        p = field(body, "path")
        if p is None:
            cur = base
        elif tree == '<group>' or tree is None:
            cur = f"{base}/{p}" if base else p
        elif tree == "SOURCE_ROOT":
            cur = p
        else:
            cur = None  # SDK / built products etc.
        paths[gid] = cur
        for c in children(body):
            walk(c, cur if cur is not None else base)

    walk(main_group, "")

    def doomed(p):
        return p is not None and any(p == x or p.startswith(x + "/") for x in prefixes)

    remove = {i for i, p in paths.items() if doomed(p) and i != main_group}
    # build files pointing at removed refs
    for i, body in objs.items():
        if "isa = PBXBuildFile" in body and field(body, "fileRef") in remove:
            remove.add(i)

    if not remove:
        print("nothing matched")
        return

    for i in sorted(remove, key=lambda x: paths.get(x) or ""):
        if i in paths:
            print("remove", paths[i])

    # 1) drop definitions
    def drop_defs(t):
        t = re.sub(rf"^\t\t({ID})(?: /\*.*?\*/)? = \{{.*?\}};\n",
                   lambda m: "" if m.group(1) in remove else m.group(0), t, flags=re.M)
        t = re.sub(rf"^\t\t({ID})(?: /\*.*?\*/)? = \{{\n.*?^\t\t\}};\n",
                   lambda m: "" if m.group(1) in remove else m.group(0), t, flags=re.M | re.S)
        return t

    text = drop_defs(text)
    # 2) drop list entries "\t\t\t\tID /* x */,"
    text = re.sub(rf"^\s+({ID})(?: /\*.*?\*/)?,\n",
                  lambda m: "" if m.group(1) in remove else m.group(0), text, flags=re.M)

    leftovers = [i for i in remove if i in text]
    if leftovers:
        print("WARNING: dangling ids still referenced:", leftovers[:10])
    open(pbx_path, "w", encoding="utf-8").write(text)




def remove_packages(pbx_path, url_parts):
    """Remove Swift package references whose repositoryURL contains any of url_parts."""
    text = open(pbx_path, encoding="utf-8").read()
    objs = parse_objects(text)
    pkgs = {i for i, b in objs.items()
            if "isa = XCRemoteSwiftPackageReference" in b
            and any(u in (field(b, "repositoryURL") or "") for u in url_parts)}
    prods = {i for i, b in objs.items()
             if "isa = XCSwiftPackageProductDependency" in b and field(b, "package") in pkgs}
    builds = {i for i, b in objs.items()
              if "isa = PBXBuildFile" in b and field(b, "productRef") in prods}
    remove = pkgs | prods | builds
    for i in prods:
        print("remove package product", field(objs[i], "productName"))
    text = re.sub(rf"^\t\t({ID})(?: /\*.*?\*/)? = \{{.*?\}};\n",
                  lambda m: "" if m.group(1) in remove else m.group(0), text, flags=re.M)
    text = re.sub(rf"^\t\t({ID})(?: /\*.*?\*/)? = \{{\n.*?^\t\t\}};\n",
                  lambda m: "" if m.group(1) in remove else m.group(0), text, flags=re.M | re.S)
    text = re.sub(rf"^\s+({ID})(?: /\*.*?\*/)?,\n",
                  lambda m: "" if m.group(1) in remove else m.group(0), text, flags=re.M)
    left = [i for i in remove if i in text]
    if left:
        print("WARNING: dangling ids:", left)
    open(pbx_path, "w", encoding="utf-8").write(text)


if __name__ == "__main__":
    if len(sys.argv) > 2 and sys.argv[2] == "--package":
        remove_packages(sys.argv[1], sys.argv[3:])
    else:
        main()
