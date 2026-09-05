#!/usr/bin/env python3
"""Ensure every authored runtime model retains a reusable Blender source file."""

from pathlib import Path
import sys


ROOT = Path(__file__).resolve().parents[1]
MODEL_GROUPS = {
    "floorball_equipment.blend": ("floorball_stick.glb", "whiffle_ball.glb"),
    "lamb_player.blend": ("lamb_player.glb",),
    "pirate_player.blend": ("pirate_player.glb",),
}


def main() -> int:
    failures: list[str] = []
    for source_name, exports in MODEL_GROUPS.items():
        source = ROOT / "blender_source" / source_name
        if not source.is_file():
            failures.append(f"Missing editable source: {source.relative_to(ROOT)}")
            continue
        header = source.read_bytes()[:7]
        # Blender 5 can save either an uncompressed BLENDER file or a
        # Zstandard-compressed file (magic 28 b5 2f fd).
        if source.stat().st_size < 1_024 or not (
            header == b"BLENDER" or header[:4] == b"\x28\xb5\x2f\xfd"
        ):
            failures.append(f"Invalid Blender file: {source.relative_to(ROOT)}")
            continue
        for export_name in exports:
            export = ROOT / "assets" / "models" / export_name
            if not export.is_file() or export.stat().st_size < 1_024:
                failures.append(f"Missing model export: {export.relative_to(ROOT)}")
            elif source.stat().st_mtime_ns < export.stat().st_mtime_ns:
                failures.append(
                    f"{source.relative_to(ROOT)} was not saved after {export.relative_to(ROOT)}"
                )

    if failures:
        print("\n".join(f"FAIL: {failure}" for failure in failures), file=sys.stderr)
        return 1
    print("All runtime models have valid, up-to-date editable Blender sources.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
