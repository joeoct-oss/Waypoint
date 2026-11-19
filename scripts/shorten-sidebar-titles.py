#!/usr/bin/env python3
"""Gives the DocC sidebar short symbol names instead of full declarations.

DocC titles sidebar entries with each symbol's declaration, such as
`init(flow: FlowID, configuration: NavigationConfiguration, file: StaticString, line: UInt)`,
which wraps over several lines. This rewrites `index/index.json` in a built site so each
symbol shows its page title, such as `init(flow:configuration:)`, without the call-site
`file:` and `line:` labels that every caller leaves at their defaults.

Usage: shorten-sidebar-titles.py <site directory>
"""
import json
import re
import sys
from pathlib import Path

CALL_SITE_LABELS = re.compile(r"\b(?:file|fileID|filePath|line|column|function):")


def short_title(site: Path, path: str):
    data = site / "data" / (path.lstrip("/") + ".json")
    try:
        title = json.loads(data.read_text())["metadata"]["title"]
    except (OSError, KeyError, ValueError):
        return None
    if "(" in title:
        name, _, rest = title.partition("(")
        title = name + "(" + CALL_SITE_LABELS.sub("", rest)
    return title


def shorten(site: Path, nodes) -> int:
    changed = 0
    shortened = {}
    for node in nodes:
        path = node.get("path")
        if path and node.get("type") not in (None, "groupMarker", "module", "article"):
            title = short_title(site, path)
            if title and title != node["title"]:
                shortened[id(node)] = title
    # Keep the declaration where two siblings would end up with the same short name.
    counts = {}
    for title in shortened.values():
        counts[title] = counts.get(title, 0) + 1
    for node in nodes:
        title = shortened.get(id(node))
        if title and counts[title] == 1:
            node["title"] = title
            changed += 1
        changed += shorten(site, node.get("children", []))
    return changed


def main() -> None:
    site = Path(sys.argv[1])
    index = site / "index" / "index.json"
    document = json.loads(index.read_text())
    changed = sum(
        shorten(site, nodes) for nodes in document["interfaceLanguages"].values()
    )
    index.write_text(json.dumps(document, ensure_ascii=False, separators=(",", ":")))
    print(f"Shortened {changed} sidebar titles.")


if __name__ == "__main__":
    main()
