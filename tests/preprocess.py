"""Rewrite instance-style requires into file requires and inject Roblox datatype shims so pure
modules can run under the standalone `luau` CLI. Usage: preprocess.py <out_dir> <files...>"""
import os
import re
import shutil
import sys

out_dir, src_files = sys.argv[1], sys.argv[2:]
os.makedirs(out_dir, exist_ok=True)
here = os.path.dirname(os.path.abspath(__file__))
shutil.copy(os.path.join(here, "shim.luau"), os.path.join(out_dir, "_shim.luau"))

REQUIRE_PATTERNS = [
    # require(script.Parent.X), require(script.Parent.Parent.Config.X)
    re.compile(r'require\(\s*script(?:\.Parent)+(?:\.\w+)*\.(\w+)\s*\)'),
    # require(ReplicatedStorage.Shared.Config.X) / require(Shared.X)
    re.compile(r'require\(\s*(?:ReplicatedStorage\.)?Shared(?:\.\w+)*\.(\w+)\s*\)'),
    # require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("X")) and :FindFirstChild forms
    re.compile(r'require\(\s*[\w.]+(?::(?:WaitForChild|FindFirstChild)\("\w+"\))*:(?:WaitForChild|FindFirstChild)\("(\w+)"\)\s*\)'),
]
HEADER = 'local __shim = require("./_shim")\nlocal Vector3 = __shim.Vector3\nlocal Color3 = __shim.Color3\nlocal CFrame = __shim.CFrame\nlocal task = __shim.task\n'

for f in src_files:
    s = open(f, encoding="utf-8").read()
    for pat in REQUIRE_PATTERNS:
        s = pat.sub(lambda m: f'require("./{m.group(1)}")', s)
    lines = s.split("\n")
    if lines and lines[0].startswith("--!"):
        s = lines[0] + "\n" + HEADER + "\n".join(lines[1:])
    else:
        s = HEADER + s
    open(os.path.join(out_dir, os.path.basename(f)), "w", encoding="utf-8").write(s)
print(f"preprocessed {len(src_files)} files into {out_dir}")
