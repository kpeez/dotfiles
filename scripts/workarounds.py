# /// script
# requires-python = ">=3.11"
# dependencies = []
# ///
"""Check that each anchor in the workarounds registry still exists in its file.

Usage: uv run --script scripts/workarounds.py [registry.toml]
Anchor paths resolve from the repo root, the parent of this script's folder.
"""

import sys
import tomllib
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
KEYS = {"remove_when", "anchors", "upstream"}


def nonempty(value: object) -> bool:
    return isinstance(value, str) and bool(value.strip())


def check(slug: str, entry: object) -> list[str]:
    if not isinstance(entry, dict):
        return [f"{slug}: not a table"]
    problems = [f"{slug}: unknown key: {key}" for key in sorted(entry.keys() - KEYS)]
    if not nonempty(entry.get("remove_when")):
        problems.append(f"{slug}: needs a non-empty remove_when")
    if "upstream" in entry and not nonempty(entry["upstream"]):
        problems.append(f"{slug}: upstream must be a non-empty string")
    anchors = entry.get("anchors")
    if not isinstance(anchors, list) or not anchors:
        return [*problems, f"{slug}: needs a non-empty anchors list"]
    for anchor in anchors:
        if not isinstance(anchor, dict) or anchor.keys() != {"path", "text"}:
            problems.append(f"{slug}: an anchor needs exactly path and text: {anchor}")
            continue
        path, text = anchor["path"], anchor["text"]
        if not nonempty(path) or not nonempty(text):
            problems.append(f"{slug}: anchor path and text must be non-empty: {anchor}")
            continue
        file = (ROOT / path).resolve()
        if not file.is_relative_to(ROOT):
            problems.append(f"{slug}: anchor path outside the repo: {path}")
        elif not file.is_file():
            problems.append(f"{slug}: anchor file missing: {path}")
        elif text not in file.read_text(encoding="utf-8"):
            problems.append(f"{slug}: anchor not found in {path}: {text}")
    return problems


def main() -> int:
    registry = (
        Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "docs/workarounds.toml"
    )
    try:
        entries = tomllib.loads(registry.read_text(encoding="utf-8"))
    except (OSError, tomllib.TOMLDecodeError) as error:
        print(f"{registry}: {error}", file=sys.stderr)
        return 1
    problems = [p for slug, entry in entries.items() for p in check(slug, entry)]
    for problem in problems:
        print(problem, file=sys.stderr)
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
