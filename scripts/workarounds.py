# /// script
# requires-python = ">=3.11"
# dependencies = []
# ///
"""Check that each anchor in the workarounds registry still exists in its file.

Usage: uv run --script scripts/workarounds.py [registry.md]
Anchor paths resolve from the repo root, the parent of this script's folder.
"""

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ITEM = re.compile(r"\s*[-*+]\s+(.*)")
FIELD = re.compile(r"(Anchor|Remove when|Upstream):\s*(.*)")
ANCHOR = re.compile(r"`([^`·]+)` · `([^`·]+)`")


def parse(registry: Path) -> tuple[dict[str, dict[str, list[str]]], list[str]]:
    entries: dict[str, dict[str, list[str]]] = {}
    problems = []
    slug = None
    for line in registry.read_text(encoding="utf-8").splitlines():
        if line.startswith("## "):
            slug = line[3:].strip()
            if slug in entries:
                problems.append(f"{slug}: duplicate slug")
            entries.setdefault(slug, {"Anchor": [], "Remove when": [], "Upstream": []})
            continue
        item = ITEM.fullmatch(line)
        if not item:
            continue
        field = FIELD.fullmatch(item.group(1))
        if slug is None:
            if field:
                problems.append(f"field before the first `## ` entry: {line}")
        elif field:
            entries[slug][field.group(1)].append(field.group(2))
        else:
            problems.append(f"{slug}: unknown list line: {line}")
    return entries, problems


def check(slug: str, entry: dict[str, list[str]]) -> list[str]:
    problems = []
    if not entry["Anchor"]:
        problems.append(f"{slug}: no `- Anchor:` line")
    if len(entry["Remove when"]) != 1 or not entry["Remove when"][0]:
        problems.append(f"{slug}: needs one non-empty `- Remove when:` line")
    if len(entry["Upstream"]) > 1 or not all(entry["Upstream"]):
        problems.append(f"{slug}: needs at most one non-empty `- Upstream:` line")
    for value in entry["Anchor"]:
        anchor = ANCHOR.fullmatch(value)
        if not anchor:
            problems.append(f"{slug}: malformed anchor: {value}")
            continue
        path, text = anchor.groups()
        file = (ROOT / path).resolve()
        if not file.is_relative_to(ROOT):
            problems.append(f"{slug}: anchor path outside the repo: {path}")
        elif not file.is_file():
            problems.append(f"{slug}: anchor file missing: {path}")
        elif text not in file.read_text(encoding="utf-8"):
            problems.append(f"{slug}: anchor not found in {path}: {text}")
    return problems


def main() -> int:
    registry = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "docs/workarounds.md"
    entries, problems = parse(registry)
    for slug, entry in entries.items():
        problems += check(slug, entry)
    for problem in problems:
        print(problem, file=sys.stderr)
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
