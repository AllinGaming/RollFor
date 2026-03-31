#!/usr/bin/env python3
from __future__ import annotations

import argparse
import csv
import re
import sys
from pathlib import Path

from find_savedvariables import find_rollfor_lua


SCRIPT_DIR = Path(__file__).resolve().parent
OUTPUT_PATH = SCRIPT_DIR / "lastRaidExport.csv"


def read_last_raid_export_block(text: str) -> str:
    anchor = '["lastRaidExport"]'
    start = text.find(anchor)
    if start == -1:
        raise ValueError('Could not find ["lastRaidExport"] in RollFor.lua')

    brace_start = text.find("{", start)
    if brace_start == -1:
        raise ValueError('Could not find opening "{" for ["lastRaidExport"]')

    depth = 0
    in_string = False
    escaped = False

    for index in range(brace_start, len(text)):
        char = text[index]

        if in_string:
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == '"':
                in_string = False
            continue

        if char == '"':
            in_string = True
        elif char == "{":
            depth += 1
        elif char == "}":
            depth -= 1
            if depth == 0:
                return text[brace_start : index + 1]

    raise ValueError('Could not find closing "}" for ["lastRaidExport"]')


def read_entries_block(last_raid_export_block: str) -> str:
    anchor = '["entries"]'
    start = last_raid_export_block.find(anchor)
    if start == -1:
        raise ValueError('Could not find ["entries"] in ["lastRaidExport"]')

    brace_start = last_raid_export_block.find("{", start)
    if brace_start == -1:
        raise ValueError('Could not find opening "{" for ["entries"]')

    depth = 0
    in_string = False
    escaped = False

    for index in range(brace_start, len(last_raid_export_block)):
        char = last_raid_export_block[index]

        if in_string:
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == '"':
                in_string = False
            continue

        if char == '"':
            in_string = True
        elif char == "{":
            depth += 1
        elif char == "}":
            depth -= 1
            if depth == 0:
                return last_raid_export_block[brace_start : index + 1]

    raise ValueError('Could not find closing "}" for ["entries"]')


def split_entry_blocks(entries_block: str) -> list[str]:
    blocks: list[str] = []
    depth = 0
    in_string = False
    escaped = False
    block_start: int | None = None

    for index, char in enumerate(entries_block):
        if in_string:
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == '"':
                in_string = False
            continue

        if char == '"':
            in_string = True
            continue

        if char == "{":
            depth += 1
            if depth == 2:
                block_start = index
        elif char == "}":
            if depth == 2 and block_start is not None:
                blocks.append(entries_block[block_start : index + 1])
                block_start = None
            depth -= 1

    return blocks


def unescape_lua_string(value: str) -> str:
    return bytes(value, "utf-8").decode("unicode_escape")


def parse_entry(block: str) -> dict[str, str]:
    entry: dict[str, str] = {}

    string_pairs = re.findall(r'\["([^"]+)"\]\s*=\s*"((?:\\.|[^"])*)"', block)
    numeric_pairs = re.findall(r'\["([^"]+)"\]\s*=\s*([0-9]+)', block)

    for key, value in string_pairs:
        entry[key] = unescape_lua_string(value)

    for key, value in numeric_pairs:
        if key not in entry:
            entry[key] = value

    return entry


def write_csv(entries: list[dict[str, str]], output_path: Path) -> None:
    headers = [
        "ID",
        "Item",
        "Boss",
        "Attendee",
        "Class",
        "Specialization",
        "Comment",
        "Date (GMT)",
        "SR+",
    ]

    with output_path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=headers)
        writer.writeheader()

        for entry in entries:
            writer.writerow(
                {
                    "ID": entry.get("ID", ""),
                    "Item": entry.get("Item", ""),
                    "Boss": entry.get("Boss", ""),
                    "Attendee": entry.get("Attendee", ""),
                    "Class": entry.get("Class", ""),
                    "Specialization": entry.get("Specialization", ""),
                    "Comment": entry.get("Comment", ""),
                    "Date (GMT)": entry.get("Date", ""),
                    "SR+": entry.get("SRPlus", ""),
                }
            )


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Read RollFor.lua for an account and export lastRaidExport.entries to CSV in this scripts folder."
    )
    parser.add_argument("account", help="Account folder name under WTF/Account")
    args = parser.parse_args()

    rollfor_lua = find_rollfor_lua(Path(__file__), args.account)
    if rollfor_lua is None:
        print(
            f"Could not find WTF/Account/{args.account}/SavedVariables/RollFor.lua from {SCRIPT_DIR}",
            file=sys.stderr,
        )
        return 1

    text = rollfor_lua.read_text(encoding="utf-8")

    try:
        last_raid_export_block = read_last_raid_export_block(text)
        entries_block = read_entries_block(last_raid_export_block)
        entry_blocks = split_entry_blocks(entries_block)
        entries = [parse_entry(block) for block in entry_blocks]
    except ValueError as exc:
        print(str(exc), file=sys.stderr)
        return 1

    write_csv(entries, OUTPUT_PATH)
    print(f"source: {rollfor_lua}")
    print(f"csv: {OUTPUT_PATH}")
    print(f"rows: {len(entries)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
