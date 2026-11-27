#!/usr/bin/env python3
"""Claude Code status line.

Line 1, session health: model, effort | context bar, cache countdown | plan usage, reset
Line 2, location:       project | worktree | scratch folder

Install: save as ~/.claude/statusline.py and add to ~/.claude/settings.json:

    "statusLine": {"type": "command", "command": "python3 ~/.claude/statusline.py",
                   "refreshInterval": 30}

refreshInterval keeps the cache countdown moving while the session is idle.
The context, cache, and plan values fade from green to red as each nears its
limit. The project and scratch folder are OSC 8 links that open the folder.
The scratch folder is the repo's .agents/scratch/, else the
session's own scratchpad, shown only when it holds files.

It uses only the standard library and no 3.10+ syntax, because macOS
/usr/bin/python3 is 3.9. The input schema is documented inside the Claude Code
binary; search it for "recache_tokens_if_cold".
"""

import json
import os
import re
import sys
import time
from urllib.parse import quote

R = "\033[0m"


def rgb(r, g, b):
    return f"\033[38;2;{r};{g};{b}m"


# Traffic-light stops for every level color: leaf, sand, apricot, dusty rose.
# Leaf is a yellow-green, kept well away from the Opus teal.
LEAF, SAND, APRICOT, ROSE = (
    (115, 195, 105),
    (210, 190, 120),
    (215, 150, 105),
    (205, 105, 100),
)
GRADIENT = [LEAF, SAND, APRICOT, ROSE]
GRAY = rgb(130, 130, 130)
BAR_TRACK = rgb(100, 100, 100)
BAR_TRACK_CHAR = "░"  # a space gives a bare track with no texture
SEP = f" {GRAY}|{R} "
BOLD = "\033[1m"
# Cool hues, so a model name never reads as a warning from the gradient above.
MODEL_COLORS = {
    "Opus": rgb(105, 185, 175),  # teal
    "Sonnet": rgb(155, 145, 220),  # iris
    "Haiku": rgb(125, 170, 215),  # sky
    "Fable": rgb(195, 135, 180),  # orchid
}
EFFORT_COLORS = {
    "low": rgb(200, 180, 120),  # gold
    "medium": rgb(140, 180, 130),  # green
    "high": rgb(115, 145, 205),  # blue
    "xhigh": rgb(165, 135, 205),  # purple
    "max": rgb(205, 130, 165),  # pink
}

BAR_WIDTH = 10
# The countdown stays blank while a cold cache would cost little to rebuild.
# A fresh session with many tools and MCP servers can already hold about 95k
# tokens, so the conversation itself is at stake only above that.
CACHE_STAKE_MIN_TOKENS = 100_000
WINDOW_SECONDS = {"five_hour": 5 * 3600, "seven_day": 7 * 86400}
WINDOW_TAGS = {"five_hour": "5h", "seven_day": "7d"}


def gradient_color(value, safe, danger):
    """Leaf at `safe`, dusty rose at `danger`, blended through GRADIENT between.

    Works in either direction: danger may be above safe (tokens) or below it
    (seconds left).
    """
    t = min(max((value - safe) / (danger - safe), 0.0), 1.0)
    pos = t * (len(GRADIENT) - 1)
    i = min(int(pos), len(GRADIENT) - 2)
    lo, hi, f = GRADIENT[i], GRADIENT[i + 1], pos - i
    return rgb(*(round(a + (b - a) * f) for a, b in zip(lo, hi)))


def context_color(tokens, window):
    """Pure green while nothing can compact the session: Claude Code compacts an
    idle session only from 200k tokens up (idle compaction, in the binary as
    CLAUDE_CODE_IDLE_COMPACT_MIN_TOKENS). Pure red at 90% of the window, just
    before threshold compaction at the effective window minus 13k.
    """
    return gradient_color(tokens, min(200_000, window // 2), int(window * 0.9))


def cache_color(seconds_left):
    """Leaf with 20+ minutes left, rose at 2 minutes: barely time to send a message.

    These are absolute times, so a 5-minute cache starts near apricot.
    """
    return gradient_color(seconds_left, 20 * 60, 2 * 60)


def plan_color(pct):
    """Leaf up to 50%, then sand, apricot, and rose from 90%."""
    return gradient_color(pct, 50, 90)


def clean(text):
    """Drop control characters, so a folder or branch name cannot inject escapes."""
    return re.sub(r"[\x00-\x1f\x7f-\x9f]", "", text)


def link(path, text):
    """OSC 8 hyperlink: a click opens the folder. quote() encodes the path."""
    return f"\033]8;;file://{quote(path)}\033\\{clean(text)}\033]8;;\033\\"


def git_dir_of(path):
    """Return (worktree root, git dir, is linked worktree) for path, or None."""
    while True:
        dot_git = os.path.join(path, ".git")
        if os.path.isdir(dot_git):
            return path, dot_git, False
        if os.path.isfile(dot_git):
            with open(dot_git) as f:
                line = f.read().strip()
            if line.startswith("gitdir:"):
                gitdir = os.path.join(path, line[len("gitdir:") :].strip())
                # A submodule also has a .git file; only a linked worktree's
                # git dir holds a commondir file.
                linked = os.path.isfile(os.path.join(gitdir, "commondir"))
                return path, gitdir, linked
        parent = os.path.dirname(path)
        if parent == path:
            return None
        path = parent


def branch_of(gitdir):
    try:
        with open(os.path.join(gitdir, "HEAD")) as f:
            head = f.read().strip()
    except OSError:
        return ""
    return (
        head[len("ref: refs/heads/") :] if head.startswith("ref: refs/heads/") else ""
    )


def has_files(path):
    try:
        return any(e.name != ".DS_Store" for e in os.scandir(path))
    except OSError:
        return False


def fmt_left(seconds):
    m = seconds // 60
    if m >= 1440:
        return f"{m // 1440}d {m % 1440 // 60}h"
    return f"{m // 60}:{m % 60:02d}"


def model_segment(data):
    name = (data.get("model") or {}).get("display_name") or "?"
    name = clean(re.sub(r"\s*\(.*?\)", "", name).replace("Claude ", ""))
    color = next((c for k, c in MODEL_COLORS.items() if k in name), "")
    name = f"{BOLD}{color}{name}{R}"
    # effort is absent when the model has no reasoning effort.
    effort = (data.get("effort") or {}).get("level")
    if effort:
        name += f" {EFFORT_COLORS.get(effort, '')}{clean(effort)}{R}"
    return name


def context_segment(data, now):
    ctx = data.get("context_window") or {}
    pct = max(0, min(int(ctx.get("used_percentage") or 0), 100))
    window = ctx.get("context_window_size") or 200_000
    tokens = ctx.get("total_input_tokens") or window * pct // 100
    filled = round(pct * BAR_WIDTH / 100)
    color = context_color(tokens, window)
    bar = f"{color}{'█' * filled}{BAR_TRACK}{BAR_TRACK_CHAR * (BAR_WIDTH - filled)}{R}"
    out = f"{bar} {color}{pct}%{R}"

    cache = data.get("prompt_cache") or {}
    expires = cache.get("expires_at")
    stake = cache.get("recache_tokens_if_cold") or 0
    if cache.get("warm") and expires and stake >= CACHE_STAKE_MIN_TOKENS:
        left = int(expires - now)
        if left > 0:
            mins = f"{left // 60} min" if left >= 60 else "<1 min"
            out += f" {cache_color(left)}⏳ {mins}{R}"
    return out


def plan_segment(data, now):
    limits = data.get("rate_limits") or {}
    windows = [(k, limits[k]) for k in WINDOW_SECONDS if limits.get(k)]
    if not windows:
        return ""
    # The window closest to its limit; on a tie, the one that locks you out longer.
    key, w = max(windows, key=lambda kw: (kw[1]["used_percentage"], kw[1]["resets_at"]))
    pct = int(w["used_percentage"])
    left = max(0, int(w["resets_at"] - now))
    elapsed = 1 - left / WINDOW_SECONDS[key]
    ahead = "↑" if pct / 100 > elapsed else ""
    tag = f"{GRAY}{WINDOW_TAGS[key]}{R}"
    return f"🕒 {tag} {plan_color(pct)}{pct}%{ahead}{R} {fmt_left(left)}"


def project_segment(data, home):
    ws = data.get("workspace") or {}
    path = ws.get("project_dir") or ws.get("current_dir") or data.get("cwd") or ""
    if path == home:
        label = "~"
    else:
        rel = path[len(home) + 1 :] if home and path.startswith(home + "/") else path
        label = "/".join(rel.strip("/").split("/")[-2:])
    return link(path, label)


def main():
    data = json.load(sys.stdin)
    now = time.time()
    home = os.environ.get("HOME", "")
    cwd = (data.get("workspace") or {}).get("current_dir") or data.get("cwd") or ""
    repo = git_dir_of(cwd) if cwd else None

    health = [model_segment(data), context_segment(data, now)]
    plan = plan_segment(data, now)
    if plan:
        health.append(plan)

    where = [project_segment(data, home)]

    wt = data.get("worktree") or {}
    if wt:
        where.append(f"🌿 {clean(wt.get('branch') or wt.get('name') or '')}")
    elif repo and repo[2]:
        where.append(f"🌿 {clean(branch_of(repo[1]) or os.path.basename(repo[0]))}")

    # (folder, label): the repo's scratch folder first, then the session's.
    scratch_dirs = []
    if repo:
        scratch_dirs.append((os.path.join(repo[0], ".agents", "scratch"), "scratch"))
    if data.get("scratchpad_dir"):
        scratch_dirs.append((data["scratchpad_dir"], "session"))
    scratch = next((s for s in scratch_dirs if has_files(s[0])), None)
    if scratch:
        where.append("📁 " + link(*scratch))

    print(SEP.join(health))
    print(SEP.join(where))


main()
