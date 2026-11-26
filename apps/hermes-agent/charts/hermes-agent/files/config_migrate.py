#!/usr/bin/env python3
"""Run Hermes' non-interactive config migration before the workload starts.

The pinned Docker image's boot wrapper treats every config with an effective
version below its support floor as ancient, including a chart-seeded partial
config with no explicit ``_config_version``. Hermes' own migrate_config()
distinguishes those cases: an absent version is a fresh partial config and can
run through the migration ladder; an explicitly old version is left untouched.

This wrapper preserves that distinction and snapshots mutable files before
calling the upstream migration API. It runs from the chart's seed init
container, after the chart config has been copied to HERMES_HOME, as the
runtime user (see the hermes-agent.migrateConfig helper), so every file it or
Hermes creates here is already owned by the user the gateway runs as.
"""

from __future__ import annotations

import shutil
import sys
from pathlib import Path
from typing import Iterable


def _backup_existing(paths: Iterable[Path]) -> dict[Path, Path]:
    from hermes_cli.config_backups import backup_config, list_config_backups

    backups: dict[Path, Path] = {}
    for path in paths:
        if not path.is_file():
            continue
        backup = backup_config(path, "pre-chart-migrate")
        if backup is None:
            backup = next(iter(list_config_backups(path, "pre-chart-migrate")), None)
        if backup is None or not backup.is_file():
            raise RuntimeError(f"Could not back up {path}; config migration was not started")
        backups[path] = backup
    return backups


def _restore_backups(backups: dict[Path, Path]) -> list[Path]:
    restored: list[Path] = []
    for original, backup in backups.items():
        if backup.is_file():
            shutil.copy2(backup, original)
            restored.append(original)
    return restored


def main() -> int:
    from hermes_cli.config import (
        check_config_version,
        get_config_path,
        get_env_path,
        migrate_config,
        read_user_config_raw,
    )
    from hermes_cli.config_migrations import SUPPORT_FLOOR_VERSION, support_floor_message

    config_path = get_config_path()
    env_path = get_env_path()
    if not config_path.is_file():
        return 0

    current_version, latest_version = check_config_version(raise_on_parse_error=True)
    if current_version >= latest_version:
        print(f"[chart-config-migrate] Config schema is current (v{current_version})")
        return 0

    raw_config = read_user_config_raw(config_path)
    has_explicit_version = "_config_version" in raw_config
    if (
        has_explicit_version
        and current_version < SUPPORT_FLOOR_VERSION
        and current_version < latest_version
    ):
        print(
            f"[chart-config-migrate] WARNING: {support_floor_message()} Config left unchanged.",
            file=sys.stderr,
        )
        return 0

    backups = _backup_existing((config_path, env_path))
    backup_text = ", ".join(str(path) for path in backups.values()) or "none"
    print(
        f"[chart-config-migrate] Migrating config schema "
        f"v{current_version} -> v{latest_version}; backups: {backup_text}"
    )
    try:
        result = migrate_config(interactive=False, quiet=False)
    except Exception:
        restored = _restore_backups(backups)
        if restored:
            print(
                "[chart-config-migrate] Migration failed; restored "
                + ", ".join(str(path) for path in restored),
                file=sys.stderr,
            )
        raise

    for warning in result.get("warnings", []):
        print(f"[chart-config-migrate] WARNING: {warning}", file=sys.stderr)

    migrated_version, _ = check_config_version(raise_on_parse_error=True)
    if migrated_version < latest_version:
        restored = _restore_backups(backups)
        restored_text = ", ".join(str(path) for path in restored) or "none"
        raise RuntimeError(
            f"Migration did not advance config version to {latest_version} "
            f"(still {migrated_version}); restored: {restored_text}"
        )
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(f"[chart-config-migrate] ERROR: {exc}", file=sys.stderr)
        raise SystemExit(1)
