#!/usr/bin/env python3
"""Keep Fish a drop-in replacement for Nu: same shortcuts, same environment.

Nu is the interactive shell, and Fish must stay close enough to switch back
without rework. This reads the names each config declares and fails when one
shell has a shortcut or exported variable the other lacks. Names that belong
to one shell on purpose are listed below with the reason.
"""

from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parent.parent
NU_FILES = [
    ROOT / "home/.config/nushell/config.nu",
    ROOT / "home/.config/nushell/autoload/interactive.nu",
]
FISH_FILES = [
    ROOT / "home/.config/fish/config.fish",
]

NU_ONLY_SHORTCUTS = {
    "ls_entries": "helper behind ls and lsa",
    "ls_mounts": "helper behind ls and lsa",
    "ls_long": "the command the ls alias points to",
    "mise": "wraps mise's Nu activation module; Fish activates mise directly",
    "nu-complete mise": "completer for the mise wrapper",
}
FISH_ONLY_SHORTCUTS: dict[str, str] = {}
NU_ONLY_ENV = {
    "PATH": "Fish edits PATH with fish_add_path",
    "FZF_CTRL_T_OPTS": "Nu's fzf integration; fzf.fish sets its own previews",
    "FZF_CTRL_R_COMMAND": "Nu's fzf integration; Fish binds atuin after fzf.fish instead",
}
FISH_ONLY_ENV = {
    "XDG_CONFIG_HOME": "set before the Nu handoff; Nu inherits it",
    "XDG_DATA_HOME": "set before the Nu handoff; Nu inherits it",
    "XDG_CACHE_HOME": "set before the Nu handoff; Nu inherits it",
}

NU_SHORTCUT = re.compile(
    r'^\s*(?:alias\s+(?P<alias>\S+)\s*=|def\s+(?:--\S+\s+)*(?:"(?P<quoted>[^"]+)"|(?P<def>[^\s\[]+)))',
    re.M,
)
NU_ENV = re.compile(r"^\s*\$env\.([A-Z][A-Z0-9_]*)\s*=", re.M)
FISH_SHORTCUT = re.compile(
    r"(?:^|;\s*and\s+)\s*(?:alias\s+(?P<alias>[^\s=]+)|abbr\s+-a\s+(?P<abbr>\S+)|function\s+(?P<function>\S+))",
    re.M,
)
FISH_ENV = re.compile(r"^\s*set\s+-[a-zA-Z]*x[a-zA-Z]*\s+([A-Z][A-Z0-9_]*)\b", re.M)


def read(files: list[Path]) -> str:
    return "\n".join(path.read_text() for path in files if path.exists())


def names(pattern: re.Pattern[str], text: str) -> set[str]:
    found = set()
    for match in pattern.finditer(text):
        groups = match.groupdict()
        values = [v for v in (groups.values() if groups else match.groups()) if v]
        found.update(values)
    return found


def compare(kind: str, nu: set[str], fish: set[str], nu_only: dict, fish_only: dict) -> list[str]:
    problems = []
    for name in sorted(nu - fish - nu_only.keys()):
        problems.append(f"{kind} {name!r} is defined in Nu but not in Fish")
    for name in sorted(fish - nu - fish_only.keys()):
        problems.append(f"{kind} {name!r} is defined in Fish but not in Nu")
    for name in sorted((nu_only.keys() - nu) | (fish_only.keys() - fish)):
        problems.append(f"{kind} {name!r} is listed as shell-specific but no longer defined")
    return problems


def main() -> int:
    nu_text, fish_text = read(NU_FILES), read(FISH_FILES)
    problems = compare(
        "shortcut", names(NU_SHORTCUT, nu_text), names(FISH_SHORTCUT, fish_text),
        NU_ONLY_SHORTCUTS, FISH_ONLY_SHORTCUTS,
    ) + compare(
        "variable", names(NU_ENV, nu_text), names(FISH_ENV, fish_text),
        NU_ONLY_ENV, FISH_ONLY_ENV,
    )
    if problems:
        print("\n".join(problems))
        return 1
    print("PASS: Fish and Nu define the same shortcuts and variables")
    return 0


if __name__ == "__main__":
    sys.exit(main())
