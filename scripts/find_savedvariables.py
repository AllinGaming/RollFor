#!/usr/bin/env python3
from __future__ import annotations

import argparse
import sys
from pathlib import Path


def find_rollfor_lua(script_path: Path, account: str) -> Path | None:
    script_dir = script_path.resolve().parent

    for base in [script_dir, *script_dir.parents]:
        candidate = base / "WTF" / "Account" / account / "SavedVariables" / "RollFor.lua"
        if candidate.exists():
            return candidate

    return None


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Find WTF/Account/<account>/SavedVariables/RollFor.lua relative to this script."
    )
    parser.add_argument("account", help="Account folder name under WTF/Account")
    args = parser.parse_args()

    script_path = Path(__file__)
    result = find_rollfor_lua(script_path, args.account)

    if result is None:
        print(
            f"Could not find WTF/Account/{args.account}/SavedVariables/RollFor.lua from {script_path.parent}",
            file=sys.stderr,
        )
        return 1

    try:
        relative_to_script = result.relative_to(script_path.parent)
    except ValueError:
        relative_to_script = result

    print(f"absolute: {result}")
    print(f"relative: {relative_to_script}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
