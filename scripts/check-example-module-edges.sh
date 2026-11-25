#!/usr/bin/env bash
#
#  check-example-module-edges.sh
#  Waypoint
#
#  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
#  Copyright © 2026 Yousef Mohamed. MIT License.
#
# Fails when a folder of the example app uses a type, or a view modifier, from a
# folder its future module may not depend on (planning #445). The example app is splitting into
# modules along its folders; a framework can't use the app, a module above it, or a feature beside
# it, so this check keeps the folders in that order before and while the modules exist:
#
#   Catalog, Store                   nothing
#   Services                         Store
#   DesignSystem                     Catalog, Store
#   Navigation                       Catalog, Store, DesignSystem
#   Flows/Addresses                  Catalog, Store, DesignSystem
#   Flows/Auth, Products, Lab        Catalog, Store, Services, DesignSystem, Navigation
#   Flows/Cart                       the same, and Addresses
#   Flows/Account                    the same, and Addresses and Lab, which it opens
#   App, Flows/Main, Flows/Splash    anything: the app wires the modules together
#
# It reads names, not the compiler's view: a type or member declared in one folder and named in
# another counts as a use. Names declared in more than one folder, and comments and strings, are
# left out. The compiler takes over once the modules exist.
#
# Usage: scripts/check-example-module-edges.sh [example-app-dir]

set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
app_dir="${1:-$root/Example/WaypointExample}"

if [ ! -d "$app_dir" ]; then
    echo "error: $app_dir does not exist" >&2
    exit 2
fi

python3 - "$app_dir" <<'PYTHON'
import collections
import os
import re
import sys

app_dir = sys.argv[1]

APP = "app"
allowed = {
    "Catalog": set(),
    "Store": set(),
    "Services": {"Store"},
    "DesignSystem": {"Catalog", "Store"},
    "Navigation": {"Catalog", "Store", "DesignSystem"},
    "Flows/Addresses": {"Catalog", "Store", "DesignSystem"},
}
feature_base = {"Catalog", "Store", "Services", "DesignSystem", "Navigation"}
for feature in ["Flows/Auth", "Flows/Products", "Flows/Lab"]:
    allowed[feature] = feature_base
allowed["Flows/Cart"] = feature_base | {"Flows/Addresses"}
allowed["Flows/Account"] = feature_base | {"Flows/Addresses", "Flows/Lab"}
app_folders = {"App", "Flows/Main", "Flows/Splash", "Resources"}


def folder_of(path):
    parts = path.split(os.sep)
    folder = "/".join(parts[:2]) if parts[0] == "Flows" else parts[0]
    if folder in app_folders:
        return APP
    if folder not in allowed:
        sys.exit(f"error: {path} is in {folder}, which has no module; add it to {sys.argv[0]}")
    return folder


def strip(text):
    text = re.sub(r"/\*.*?\*/", "", text, flags=re.S)
    text = re.sub(r"//.*", "", text)
    return re.sub(r'"[^"\n]*"', '""', text)


sources = {}
for directory, _, files in os.walk(app_dir):
    for name in files:
        if name.endswith(".swift"):
            path = os.path.relpath(os.path.join(directory, name), app_dir)
            with open(os.path.join(app_dir, path), encoding="utf-8") as file:
                sources[path] = strip(file.read())

declared = collections.defaultdict(set)
members = collections.defaultdict(set)
type_pattern = r"\b(?:struct|class|enum|protocol|actor|typealias)\s+([A-Z]\w*)"
extension_pattern = r"^extension\s+View\b[^{]*\{(.*?)^\}"
member_pattern = r"\b(?:func|var)\s+([a-z]\w*)"
for path, text in sources.items():
    folder = folder_of(path)
    for match in re.finditer(type_pattern, text):
        declared[match.group(1)].add(folder)
    for block in re.finditer(extension_pattern, text, flags=re.S | re.M):
        for match in re.finditer(member_pattern, block.group(1)):
            members[match.group(1)].add(folder)

owner = {name: next(iter(folders)) for name, folders in declared.items() if len(folders) == 1}
member_owner = {
    name: next(iter(folders))
    for name, folders in members.items()
    if len(folders) == 1 and name not in {"body", "id", "description"}
}

failures = []
for path, text in sorted(sources.items()):
    folder = folder_of(path)
    if folder == APP:
        continue
    used = set()
    for name in set(re.findall(r"\b[A-Z]\w*\b", text)):
        if name in owner:
            used.add((owner[name], name))
    for name in set(re.findall(r"\.([a-z]\w*)\b", text)):
        if name in member_owner:
            used.add((member_owner[name], f".{name}"))
    for other, name in sorted(used):
        if other == folder or other in allowed[folder]:
            continue
        target = "the app" if other == APP else other
        failures.append(f"Example/WaypointExample/{path}: uses {name} from {target}, which {folder} may not use")

for failure in failures:
    print(failure, file=sys.stderr)
if failures:
    sys.exit(1)
print("Every example app folder uses only the folders its module may depend on")
PYTHON
