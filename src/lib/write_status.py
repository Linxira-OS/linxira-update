#!/usr/bin/env python3

import argparse
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import platform
import tempfile


def reboot_required():
    return not Path(f"/usr/lib/modules/{platform.release()}/vmlinuz").is_file()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--state-dir", required=True, type=Path)
    parser.add_argument("--available-count", required=True, type=int)
    parser.add_argument(
        "--check-status", choices=("ok", "error", "incomplete"), default="ok"
    )
    parser.add_argument("--message")
    args = parser.parse_args()
    if args.available_count < 0:
        parser.error("available count must be non-negative")

    args.state_dir.mkdir(parents=True, exist_ok=True)
    document = {
        "version": 1,
        "available_update_count": args.available_count,
        "check_status": args.check_status,
        "last_check": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
        "reboot_required": reboot_required(),
    }
    if args.message:
        document["message"] = args.message
    descriptor, temporary_name = tempfile.mkstemp(
        dir=args.state_dir, prefix="status.", suffix=".tmp"
    )
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8") as stream:
            json.dump(document, stream, ensure_ascii=False, indent=2)
            stream.write("\n")
        os.replace(temporary_name, args.state_dir / "status.json")
    finally:
        if os.path.exists(temporary_name):
            os.unlink(temporary_name)


if __name__ == "__main__":
    main()
