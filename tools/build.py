#!/usr/bin/env python3
"""Regenerates scripts/*.sh and README.md from the source files, so code in the
README / user-data never drifts from the real files.  Run: python3 tools/build.py"""
import pathlib, re, sys
root = pathlib.Path(__file__).resolve().parent.parent

def read(rel):
    return (root / rel).read_text(encoding="utf-8").rstrip("\n")

def expand(text, pattern, fmt=lambda s: s):
    return re.sub(pattern, lambda m: fmt(read(m.group(1))), text)

for tpl, out in (("web-userdata.tpl.sh", "web-userdata.sh"), ("app-userdata.tpl.sh", "app-userdata.sh")):
    src = (root / "tools/templates" / tpl).read_text(encoding="utf-8")
    (root / "scripts" / out).write_text(expand(src, r"@@FILE:(.+?)@@") + "\n", encoding="utf-8")

readme_tpl = root / "tools/templates/README.tpl.md"
if readme_tpl.exists():
    text = expand(readme_tpl.read_text(encoding="utf-8"), r"\{\{file:(.+?)\}\}")
    (root / "README.md").write_text(text, encoding="utf-8")
print("built")
