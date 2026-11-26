#!/usr/bin/env python3
"""Fails if "squad" shows up in anything the app says to a person.

The app says "group" or the group's name. "SquadSync" (the app's name) is fine,
and so are code identifiers, keys, table and function names, log lines and
accessibility identifiers: only words a person can see or hear count.

Checks:
  - every Swift string literal under app/SquadSync (comments and log calls skipped),
  - the microphone usage text in app/project.yml, the pbxproj and Info.plist.

A literal counts as user-facing when it has a space or starts with a capital
letter (so "squad_id", "squad-title" and "sq8.squad" are identifiers). Anything
passed to accessibilityIdentifier, forKey:, Logger or a log call is skipped.

Usage: python3 scripts/check-copy.py [repo root]. Exit 1 lists each hit.
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else pathlib.Path(__file__).resolve().parent.parent)
APP = ROOT / "app" / "SquadSync"

# Contexts where a literal is an identifier, not copy.
SKIP_BEFORE = re.compile(
    r"(accessibilityIdentifier|forKey|forHTTPHeaderField|subsystem|category|Logger|NSNotification\.Name|"
    r"Notification\.Name|URLQueryItem\(name|CodingKey|path|rpc|named|systemName|identifier|"
    r"\.info|\.debug|\.notice|\.error|\.fault|\.warning|SquadLog\.\w+\.\w+|print)\s*[:(]\s*$"
)
LOG_LINE = re.compile(r"(SquadLog\.|Logger\(|chatOpenLog\.|sideThreadLog\.|pollTrace\.|\bLog\.\w+\.)")
SQUAD = re.compile(r"squad", re.IGNORECASE)


def strip_app_name(text):
    return re.sub(r"squadsync", "", text, flags=re.IGNORECASE)


def without_interpolation(text):
    out, depth, i = [], 0, 0
    while i < len(text):
        if text.startswith("\\(", i) and depth == 0:
            depth, i = 1, i + 2
            continue
        if depth:
            if text[i] == "(":
                depth += 1
            elif text[i] == ")":
                depth -= 1
            i += 1
            continue
        out.append(text[i])
        i += 1
    return "".join(out)


def literals(line):
    """(start column, contents) for each "..." literal on a line, comments removed."""
    found, i, n = [], 0, len(line)
    while i < n:
        c = line[i]
        if line.startswith("//", i):
            break
        if c == '"':
            if line.startswith('"""', i):
                return found  # multi-line literals are handled by the block scan
            j, buf, depth = i + 1, [], 0
            while j < n:
                if line[j] == "\\" and j + 1 < n:
                    if line[j + 1] == "(":
                        depth += 1
                    buf.append(line[j:j + 2])
                    j += 2
                    continue
                if line[j] == ")" and depth:
                    depth -= 1
                if line[j] == '"' and depth == 0:
                    break
                buf.append(line[j])
                j += 1
            found.append((i, "".join(buf)))
            i = j + 1
            continue
        i += 1
    return found


def user_facing(text):
    visible = strip_app_name(without_interpolation(text))
    if not SQUAD.search(visible):
        return False
    return " " in visible.strip() or visible[:1].isupper() or "'" in visible


def scan_swift(path, hits):
    in_block = False
    in_comment = False
    for number, line in enumerate(path.read_text().splitlines(), 1):
        stripped = line.strip()
        if in_comment:
            if "*/" in stripped:
                in_comment = False
            continue
        if stripped.startswith("/*"):
            in_comment = "*/" not in stripped
            continue
        if stripped.startswith("//"):
            continue
        if in_block:
            if '"""' in stripped:
                in_block = False
                continue
            if SQUAD.search(strip_app_name(without_interpolation(line))):
                hits.append((path, number, stripped))
            continue
        if stripped.endswith('"""') and stripped.count('"""') == 1:
            in_block = True
            continue
        if LOG_LINE.search(line):
            continue
        for column, text in literals(line):
            before = line[:column]
            if SKIP_BEFORE.search(before):
                continue
            if user_facing(text):
                hits.append((path, number, text))


def scan_text(path, pattern, hits):
    for number, line in enumerate(path.read_text().splitlines(), 1):
        if pattern.search(line) and SQUAD.search(strip_app_name(line)):
            hits.append((path, number, line.strip()))


def main():
    hits = []
    for path in sorted(APP.rglob("*.swift")):
        scan_swift(path, hits)
    usage = re.compile(r"UsageDescription|<string>.*</string>")
    for extra in [ROOT / "app" / "project.yml", ROOT / "app" / "SquadSync.xcodeproj" / "project.pbxproj", APP / "Info.plist"]:
        if extra.exists():
            scan_text(extra, usage, hits)
    if hits:
        print('"squad" in user-facing copy. Say "group" or the group\'s name:')
        for path, number, text in hits:
            print(f"  {path.relative_to(ROOT)}:{number}: {text}")
        return 1
    print("Copy check passed: no \"squad\" in user-facing strings.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
