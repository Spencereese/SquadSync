#!/usr/bin/env python3
"""Catch Swift compile errors the Linux harness cannot see.

The harness only compiles Foundation sources (see squadsync-harness/build.sh).
SwiftUI files such as Store/MockStore.swift and Screens/GameOnViews.swift are
never type-checked on Linux, so a non-exhaustive switch or a typo'd Type.member
reaches the Mac as a build failure. This script walks app/SquadSync and fails on:

  1. A switch over a uniquely named app enum that has no default and is missing
     a case (the Seed.party / LaunchScenario failure).
  2. A Type.member reference where Type is defined in the app and has no such
     member (the SpotThread.initial typo; ChatBubbleSide.initial was meant).

Enums that share a short name (Action, Load, Display, Kind, Field, CodingKeys)
are skipped for (1), because cases from two private enums would be merged.
Types that share a name with Foundation or SwiftUI (Thread, Notification, …)
are skipped for (2).

Usage: python3 scripts/check-swift-surface.py [repo root]. Exit 1 lists each hit.
"""
from __future__ import annotations

import pathlib
import re
import sys
from collections import defaultdict

ROOT = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else pathlib.Path(__file__).resolve().parent.parent)
APP = ROOT / "app" / "SquadSync"

# Types we define whose names collide with the standard library. Checking
# them flags real Foundation members (Thread.sleep, Notification.Name).
SHADOWED_TYPES = {
    "Thread",
    "Notification",
    "URL",
    "URLSession",
    "Data",
    "Date",
    "UUID",
    "Error",
    "Result",
    "Optional",
    "Array",
    "Set",
    "Dictionary",
    "String",
    "Int",
    "Double",
    "Bool",
    "Character",
    "Task",
    "Button",
    "Text",
    "Image",
    "Color",
    "Font",
    "State",
    "Binding",
    "Environment",
    "View",
    "List",
    "Form",
    "Section",
    "Label",
    "Alert",
    "Timer",
    "Bundle",
    "Operation",
    "Publisher",
}

# Members Swift synthesizes, or that live on the metatype.
SYNTHESIZED = {
    "rawValue",
    "allCases",
    "init",
    "none",
    "some",
    "self",
    "Type",
    "Protocol",
    "hashValue",
    "description",
    "debugDescription",
    "customMirror",
    "localizedDescription",
    "CodingKeys",
    "ID",
    "Element",
    "Iterator",
    "Index",
}

TYPE_DECL = re.compile(r"\b(?:enum|struct|class|actor|extension)\s+(\w+)\b")
ENUM_DECL = re.compile(r"\benum\s+(\w+)\b")
REF = re.compile(r"(?<![\w.])([A-Z]\w*)\.(\w+)")


def strip_comments(text: str) -> str:
    text = re.sub(r"/\*.*?\*/", "", text, flags=re.S)
    out = []
    for line in text.splitlines(True):
        i, in_s, esc = 0, False, False
        while i < len(line):
            c = line[i]
            if in_s:
                if esc:
                    esc = False
                elif c == "\\":
                    esc = True
                elif c == '"':
                    in_s = False
            else:
                if c == '"':
                    in_s = True
                elif c == "/" and i + 1 < len(line) and line[i + 1] == "/":
                    line = line[:i] + ("\n" if line.endswith("\n") else "")
                    break
            i += 1
        out.append(line)
    return "".join(out)


def extract_block(text: str, open_idx: int) -> str | None:
    depth, in_s, esc = 0, False, False
    for i, c in enumerate(text[open_idx:], open_idx):
        if in_s:
            if esc:
                esc = False
            elif c == "\\":
                esc = True
            elif c == '"':
                in_s = False
            continue
        if c == '"':
            in_s = True
            continue
        if c == "{":
            depth += 1
        elif c == "}":
            depth -= 1
            if depth == 0:
                return text[open_idx + 1 : i]
    return None


def walk_depth0(body: str):
    """Yield (index, remaining-text) at brace depth 0, skipping strings."""
    depth, in_s, esc, i = 0, False, False, 0
    while i < len(body):
        c = body[i]
        if in_s:
            if esc:
                esc = False
            elif c == "\\":
                esc = True
            elif c == '"':
                in_s = False
            i += 1
            continue
        if c == '"':
            in_s = True
            i += 1
            continue
        if c == "{":
            depth += 1
            i += 1
            continue
        if c == "}":
            depth -= 1
            i += 1
            continue
        if depth == 0:
            yield i, body[i:]
        i += 1


def at_statement(body: str, i: int) -> bool:
    return i == 0 or body[i - 1] in " \t\n{"


def take_until_newline(body: str, start: int) -> int:
    d, in_s, esc, k = 0, False, False, start
    while k < len(body):
        ch = body[k]
        if in_s:
            if esc:
                esc = False
            elif ch == "\\":
                esc = True
            elif ch == '"':
                in_s = False
            k += 1
            continue
        if ch == '"':
            in_s = True
            k += 1
            continue
        if ch in "([{":
            d += 1
        elif ch in ")]}":
            d -= 1
        elif ch == "\n" and d == 0:
            break
        k += 1
    return k


def take_until_colon(body: str, start: int) -> int:
    d, in_s, esc, k = 0, False, False, start
    while k < len(body):
        ch = body[k]
        if in_s:
            if esc:
                esc = False
            elif ch == "\\":
                esc = True
            elif ch == '"':
                in_s = False
            k += 1
            continue
        if ch == '"':
            in_s = True
            k += 1
            continue
        if ch in "([{":
            d += 1
        elif ch in ")]}":
            d -= 1
        elif ch == ":" and d == 0:
            return k
        k += 1
    return k


def split_cases(chunk: str) -> list[str]:
    parts, cur, depth, in_s, esc = [], "", 0, False, False
    for c in chunk:
        if in_s:
            cur += c
            if esc:
                esc = False
            elif c == "\\":
                esc = True
            elif c == '"':
                in_s = False
            continue
        if c == '"':
            in_s = True
            cur += c
            continue
        if c in "([{":
            depth += 1
            cur += c
        elif c in ")]}":
            depth -= 1
            cur += c
        elif c == "," and depth == 0:
            parts.append(cur)
            cur = ""
        else:
            cur += c
    if cur.strip():
        parts.append(cur)
    names = []
    for part in parts:
        p = re.sub(r"\s*=\s*.*$", "", part).strip()
        p = re.sub(r"\s*[\(:].*$", "", p).strip()
        if re.match(r"^[A-Za-z_]\w*$", p):
            names.append(p)
    return names


def enum_cases(body: str) -> set[str]:
    cases: set[str] = set()
    for i, rest in walk_depth0(body):
        if not rest.startswith("case") or not at_statement(body, i):
            continue
        if not re.match(r"case\s+", rest):
            continue
        after = rest[4:].lstrip()
        if after.startswith(".") or after.startswith("let") or after.startswith("var"):
            continue
        start = i + len("case")
        end = take_until_newline(body, start)
        cases.update(split_cases(body[start:end]))
    return cases


def type_members(body: str) -> set[str]:
    found: set[str] = set()
    decl = re.compile(
        r"(?:(?:public|internal|private|fileprivate|open|static|class|override|"
        r"nonisolated|mutating|indirect|convenience|required|final|lazy|weak|"
        r"unowned|nonisolated\([^\)]*\))\s+|@\w+(?:\([^\)]*\))?\s+)*"
        r"(?:func|var|let|typealias|enum|struct|class|actor|init|subscript)\s+(\w+)?"
    )
    for i, rest in walk_depth0(body):
        if re.match(r"case\s+", rest) and at_statement(body, i):
            after = rest[4:].lstrip()
            if after.startswith(".") or after.startswith("let") or after.startswith("var"):
                continue
            end = take_until_newline(body, i + 4)
            found.update(split_cases(body[i + 4 : end]))
            continue
        m = decl.match(rest)
        if not m or not at_statement(body, i):
            continue
        if m.group(1):
            found.add(m.group(1))
        if re.match(r"(?:(?:\w+|@\w+(?:\([^\)]*\))?)\s+)*init\b", rest):
            found.add("init")
    return found


def switch_info(body: str) -> tuple[set[str], bool]:
    mentioned: set[str] = set()
    has_default = False
    for i, rest in walk_depth0(body):
        if not at_statement(body, i):
            continue
        if re.match(r"(?:@unknown\s+)?default\s*:", rest):
            has_default = True
            continue
        m = re.match(r"case\s+", rest)
        if not m:
            continue
        end = take_until_colon(body, i + m.end())
        chunk = body[i + m.end() : end]
        mentioned.update(re.findall(r"(?<![\w])\.(\w+)", chunk))
    return mentioned, has_default


def load_sources() -> list[tuple[pathlib.Path, str, str]]:
    sources = []
    for path in sorted(APP.rglob("*.swift")):
        raw = path.read_text()
        sources.append((path, raw, strip_comments(raw)))
    return sources


def collect(sources):
    enums: dict[str, list[tuple[pathlib.Path, set[str]]]] = defaultdict(list)
    members: dict[str, set[str]] = defaultdict(set)
    for path, _, text in sources:
        for m in ENUM_DECL.finditer(text):
            brace = text.find("{", m.end() - 1)
            if brace < 0:
                continue
            body = extract_block(text, brace)
            if body is None:
                continue
            cases = enum_cases(body)
            if cases:
                enums[m.group(1)].append((path, cases))
        for m in TYPE_DECL.finditer(text):
            brace = text.find("{", m.end() - 1)
            if brace < 0:
                continue
            body = extract_block(text, brace)
            if body is None:
                continue
            members[m.group(1)].update(type_members(body))
    unique = {name: cases[0][1] for name, cases in enums.items() if len(cases) == 1}
    return unique, members


def check_switches(sources, unique_enums) -> list[str]:
    hits = []
    for path, raw, text in sources:
        for m in re.finditer(r"\bswitch\s+", text):
            brace = text.find("{", m.end())
            if brace < 0:
                continue
            header = text[m.end() : brace].strip()
            body = extract_block(text, brace)
            if body is None:
                continue
            mentioned, has_default = switch_info(body)
            if has_default or not mentioned:
                continue
            matches = [
                (name, cases)
                for name, cases in unique_enums.items()
                if mentioned <= cases
            ]
            if not matches:
                continue
            # Most specific unique enum that covers the case names.
            name, cases = min(matches, key=lambda item: len(item[1]))
            missing = cases - mentioned
            if not missing:
                continue
            # Require at least one case that belongs only to this enum, so a
            # small overlap with another unique enum doesn't get flagged.
            exclusive = mentioned - set().union(*(c for n, c in unique_enums.items() if n != name))
            if not exclusive:
                continue
            line = text.count("\n", 0, m.start()) + 1
            rel = path.relative_to(ROOT)
            hits.append(
                f"{rel}:{line}: switch {header} over {name} is missing {', '.join('.' + c for c in sorted(missing))}"
            )
    return hits


def check_members(sources, members) -> list[str]:
    hits = []
    defined = {name for name, vals in members.items() if vals} - SHADOWED_TYPES
    for path, _, text in sources:
        nos = re.sub(r'"(?:\\.|[^"\\])*"', '""', text)
        for m in REF.finditer(nos):
            typ, mem = m.group(1), m.group(2)
            if typ not in defined or mem in members[typ] or mem in SYNTHESIZED:
                continue
            line = nos.count("\n", 0, m.start()) + 1
            rel = path.relative_to(ROOT)
            hits.append(f"{rel}:{line}: {typ} has no member '{mem}'")
    return hits


def main() -> int:
    if not APP.is_dir():
        print(f"No app sources at {APP}", file=sys.stderr)
        return 2
    sources = load_sources()
    unique_enums, members = collect(sources)
    hits = check_switches(sources, unique_enums) + check_members(sources, members)
    if hits:
        print("Swift surface check failed:")
        print("\n".join(hits))
        return 1
    print(
        f"Swift surface check passed: {len(unique_enums)} unique enums, "
        f"{len(sources)} files, no missing cases or members."
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
