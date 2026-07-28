#!/usr/bin/env python3

import json
import time
from math import floor


def get_next_check_duration_human_readable(input_json, now=None):
    """Return a compact duration from systemctl list-timers JSON."""
    try:
        timer_json = json.loads(input_json)
        if not isinstance(timer_json, list) or not timer_json:
            return None
        next_microseconds = int(timer_json[0].get("next", 0))
    except (json.JSONDecodeError, TypeError, ValueError, AttributeError):
        return None

    if next_microseconds <= 0:
        return None
    if now is None:
        now = time.time()
    seconds = max(0, floor((next_microseconds - int(now * 1_000_000)) / 1_000_000))
    if seconds == 0:
        return "now"

    parts = []
    for length, suffix in ((86400, "d"), (3600, "h"), (60, "m")):
        value, seconds = divmod(seconds, length)
        if value:
            parts.append(f"{value}{suffix}")
    if seconds:
        parts.append(f"{seconds}s")
    return " ".join(parts)
