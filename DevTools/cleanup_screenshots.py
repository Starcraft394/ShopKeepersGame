#!/usr/bin/env python3
"""Cleanup playtest screenshots after review."""
import shutil
import os
import sys

base = os.path.join(
    os.environ.get("APPDATA", ""),
    "Godot",
    "app_userdata",
    "ShopKeepersGame",
    "playtest_screenshots",
)

if not os.path.exists(base):
    print("[Cleanup] No screenshots directory found at:")
    print(f"  {base}")
    sys.exit(0)

# List runs before deleting
runs = [d for d in os.listdir(base) if os.path.isdir(os.path.join(base, d))]
if not runs:
    print("[Cleanup] Screenshots directory exists but is empty.")
    sys.exit(0)

print(f"[Cleanup] Found {len(runs)} screenshot run(s):")
total_files = 0
for run in sorted(runs):
    run_path = os.path.join(base, run)
    files = [f for f in os.listdir(run_path) if f.endswith(".png")]
    total_files += len(files)
    print(f"  {run}: {len(files)} screenshots")

print(f"\n[Cleanup] Total: {total_files} screenshots")

if "--force" not in sys.argv:
    response = input("\nDelete all? (y/N): ").strip().lower()
    if response != "y":
        print("[Cleanup] Cancelled.")
        sys.exit(0)

shutil.rmtree(base)
print(f"[Cleanup] Deleted: {base}")
