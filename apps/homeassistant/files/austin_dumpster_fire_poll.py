#!/usr/bin/env python3
"""
Austin Dumpster/Trash Fire poller for Home Assistant.

Called every ~5 minutes by a command_line sensor. Fetches the latest matching
incidents from the City of Austin real-time fire dataset, compares against a
persistent set of previously-seen traffic_report_id values, and prints a
single-line JSON document with the fields listed in RESULT_KEYS below.

Design contract:

- On first ever successful run (state file missing or "initialized" is false):
  * Every current incident id is seeded into the "seen" set.
  * new_incident_count is reported as 0 so downstream automations DO NOT trigger.
  * "initialized" is set to true.

- On every subsequent successful run:
  * new_ids = current_ids - seen_ids
  * All new_ids are immediately persisted into "seen".
  * new_incident_count = len(new_ids). new_run_id increments only when
    new_incident_count > 0, so downstream automations trigger exactly once per
    batch of newly-discovered incidents.
  * "seen" entries older than RETENTION_SECONDS are pruned.

- On any failure (network, HTTP, JSON, schema):
  * State file is not mutated.
  * new_incident_count is reported as 0.
  * new_run_id is NOT incremented (so downstream automations do NOT trigger).
  * poll_ok is false and error is populated.

This script is intentionally standalone: it does NOT press the physical button,
does NOT read the flame-state sensor, and does NOT start/restart the activity
timer. Those actions are done by Home Assistant automations in
`austin_dumpster_fire.yaml`. This keeps physical-device policy in HA where it
belongs, and keeps this script trivially testable in isolation.
"""

from __future__ import annotations

import json
import os
import sys
import tempfile
import time
import traceback
import urllib.parse
import urllib.request
from datetime import datetime, timezone

STATE_PATH = os.environ.get(
    "AUSTIN_FIRE_STATE_PATH", "/config/austin_dumpster_fire_state.json"
)
API_URL = "https://data.austintexas.gov/resource/wpu4-x69d.json"
TARGET_LABELS = ("DUMP - Dumpster Fire", "TRASH - Trash Fire")
FETCH_LIMIT = 25
HTTP_TIMEOUT_SECONDS = 20
RETENTION_SECONDS = 48 * 60 * 60  # 48 hours

# Keys always present in the emitted JSON, so that HA's json_attributes template
# gets a stable schema even on error paths.
RESULT_KEYS = (
    "poll_ok",
    "initialized",
    "new_incident_count",
    "new_run_id",
    "new_ids",
    "current_count",
    "seen_count",
    "last_poll",
    "last_incident_id",
    "last_issue_reported",
    "last_address",
    "last_published_date",
    "last_status",
    "error",
)


def _now_iso() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


def _load_state() -> dict:
    try:
        with open(STATE_PATH, "r", encoding="utf-8") as fh:
            data = json.load(fh)
        if not isinstance(data, dict):
            raise ValueError("state file is not a JSON object")
        data.setdefault("initialized", False)
        data.setdefault("seen", {})
        data.setdefault("new_run_id", 0)
        if not isinstance(data["seen"], dict):
            data["seen"] = {}
        return data
    except FileNotFoundError:
        return {"initialized": False, "seen": {}, "new_run_id": 0}
    except Exception:
        # Corrupt state file. Treat as uninitialized to fail safe. We do NOT
        # blow it away here; the atomic write on the next successful poll will
        # replace it. This means a corrupt file behaves like a fresh install:
        # historical incidents will be re-seeded without triggering the toy.
        return {"initialized": False, "seen": {}, "new_run_id": 0}


def _save_state_atomic(state: dict) -> None:
    directory = os.path.dirname(STATE_PATH) or "."
    fd, tmp_path = tempfile.mkstemp(prefix=".austin_fire_state.", dir=directory)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as fh:
            json.dump(state, fh, indent=2, sort_keys=True)
            fh.flush()
            os.fsync(fh.fileno())
        os.replace(tmp_path, STATE_PATH)
    except Exception:
        try:
            os.unlink(tmp_path)
        except OSError:
            pass
        raise


def _fetch_incidents() -> list[dict]:
    """
    Fetch up to FETCH_LIMIT most-recent matching incidents.

    Returns a list of dicts on success. Raises on any transport, HTTP, JSON,
    or schema failure - callers must treat any raised exception as "poll
    failed, do not mutate state".
    """
    where_clause = "issue_reported IN({})".format(
        ",".join("'{}'".format(x) for x in TARGET_LABELS)
    )
    params = {
        "$select": (
            "traffic_report_id,published_date,issue_reported,address,"
            "traffic_report_status"
        ),
        "$where": where_clause,
        "$order": "published_date DESC",
        "$limit": str(FETCH_LIMIT),
    }
    url = "{}?{}".format(API_URL, urllib.parse.urlencode(params))
    req = urllib.request.Request(
        url,
        headers={
            "Accept": "application/json",
            "User-Agent": "homeassistant-austin-dumpster-fire/1.0",
        },
    )
    with urllib.request.urlopen(req, timeout=HTTP_TIMEOUT_SECONDS) as resp:
        if resp.status != 200:
            raise RuntimeError("HTTP {}".format(resp.status))
        raw = resp.read()
    data = json.loads(raw)
    if not isinstance(data, list):
        raise RuntimeError("API did not return a JSON array")
    for row in data:
        if not isinstance(row, dict) or not row.get("traffic_report_id"):
            raise RuntimeError("API row missing traffic_report_id")
    return data


def _prune_seen(seen: dict, now_ts: float) -> int:
    cutoff = now_ts - RETENTION_SECONDS
    to_drop = []
    for k, v in seen.items():
        try:
            dt = datetime.fromisoformat(v.replace("Z", "+00:00"))
            if dt.timestamp() < cutoff:
                to_drop.append(k)
        except Exception:
            to_drop.append(k)
    for k in to_drop:
        seen.pop(k, None)
    return len(to_drop)


def _empty_result() -> dict:
    return {k: None for k in RESULT_KEYS}


def main() -> int:
    result = _empty_result()
    result["last_poll"] = _now_iso()
    result["new_incident_count"] = 0
    result["new_ids"] = []

    state = _load_state()
    result["initialized"] = bool(state.get("initialized", False))
    result["new_run_id"] = int(state.get("new_run_id", 0))
    result["seen_count"] = len(state.get("seen", {}))

    try:
        rows = _fetch_incidents()
    except Exception as exc:
        result["poll_ok"] = False
        result["error"] = "fetch failed: {}".format(exc).strip()
        # Do NOT mutate state. Do NOT bump new_run_id.
        print(json.dumps(result, sort_keys=True))
        return 0  # exit 0 so command_line sensor keeps working

    result["poll_ok"] = True
    result["error"] = None
    result["current_count"] = len(rows)

    current_ids = [r["traffic_report_id"] for r in rows]
    seen = dict(state.get("seen", {}))
    now_ts = time.time()

    if not state.get("initialized", False):
        # First-ever poll: seed everything, never trigger.
        for r in rows:
            seen[r["traffic_report_id"]] = _now_iso()
        _prune_seen(seen, now_ts)
        state["seen"] = seen
        state["initialized"] = True
        # DO NOT bump new_run_id; downstream automation must not fire.
        try:
            _save_state_atomic(state)
        except Exception as exc:
            # State write failed. Report as poll failure so we retry cleanly
            # next cycle without triggering.
            result["poll_ok"] = False
            result["error"] = "state write failed: {}".format(exc)
            result["initialized"] = False
            print(json.dumps(result, sort_keys=True))
            return 0
        result["initialized"] = True
        result["seen_count"] = len(seen)
        # Reflect what we would report on a subsequent no-op poll.
        if rows:
            top = rows[0]
            result["last_incident_id"] = top.get("traffic_report_id")
            result["last_issue_reported"] = top.get("issue_reported")
            result["last_address"] = top.get("address")
            result["last_published_date"] = top.get("published_date")
            result["last_status"] = top.get("traffic_report_status")
        print(json.dumps(result, sort_keys=True))
        return 0

    # Normal poll: compute new ids.
    new_rows = [r for r in rows if r["traffic_report_id"] not in seen]
    new_ids = [r["traffic_report_id"] for r in new_rows]

    if new_ids:
        stamp = _now_iso()
        for nid in new_ids:
            seen[nid] = stamp
        _prune_seen(seen, now_ts)
        state["seen"] = seen
        state["new_run_id"] = int(state.get("new_run_id", 0)) + 1
        try:
            _save_state_atomic(state)
        except Exception as exc:
            result["poll_ok"] = False
            result["error"] = "state write failed: {}".format(exc)
            # Do NOT report new_incident_count on failed persistence; that
            # would fire the automation without a durable "seen" record and
            # replay on the next poll.
            result["new_incident_count"] = 0
            result["new_ids"] = []
            print(json.dumps(result, sort_keys=True))
            return 0
        result["new_incident_count"] = len(new_ids)
        result["new_ids"] = new_ids
        result["new_run_id"] = state["new_run_id"]
        result["seen_count"] = len(seen)
        # Report metadata about the most recently published NEW incident so
        # HA can log it.
        newest = max(
            new_rows,
            key=lambda r: r.get("published_date") or "",
        )
        result["last_incident_id"] = newest.get("traffic_report_id")
        result["last_issue_reported"] = newest.get("issue_reported")
        result["last_address"] = newest.get("address")
        result["last_published_date"] = newest.get("published_date")
        result["last_status"] = newest.get("traffic_report_status")
    else:
        # No new incidents. Still prune old ones. Persist only if we actually
        # pruned something, so idle polls do not thrash the state file.
        pruned = _prune_seen(seen, now_ts)
        if pruned:
            state["seen"] = seen
            try:
                _save_state_atomic(state)
            except Exception:
                # Prune-only failure is non-fatal; log but do not fail the
                # poll.
                pass
        result["new_incident_count"] = 0
        result["new_ids"] = []
        result["seen_count"] = len(state.get("seen", {}))
        # Populate last_incident_* with top of the current feed for
        # observability, even if it was previously seen.
        if rows:
            top = rows[0]
            result["last_incident_id"] = top.get("traffic_report_id")
            result["last_issue_reported"] = top.get("issue_reported")
            result["last_address"] = top.get("address")
            result["last_published_date"] = top.get("published_date")
            result["last_status"] = top.get("traffic_report_status")

    print(json.dumps(result, sort_keys=True))
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception:
        err = _empty_result()
        err["poll_ok"] = False
        err["last_poll"] = _now_iso()
        err["new_incident_count"] = 0
        err["new_ids"] = []
        err["error"] = "unhandled: {}".format(traceback.format_exc().splitlines()[-1])
        print(json.dumps(err, sort_keys=True))
        sys.exit(0)
