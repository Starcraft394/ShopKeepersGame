#!/usr/bin/env python3
"""
parse_telemetry.py — Analyze local playtest telemetry files.

Reads session JSON files from the telemetry directory and prints summary statistics:
- Combat win/loss by region and floor
- Average combat rounds and duration
- Most common death floor
- Session count and average duration
- Hero death frequency by class

Usage:
    python DevTools/parse_telemetry.py <telemetry_folder>

Example:
    python DevTools/parse_telemetry.py "%APPDATA%/Godot/app_userdata/ShopKeepersGame/telemetry"
"""

import json
import os
import sys
from collections import defaultdict
from pathlib import Path


def load_sessions(folder: str) -> list[dict]:
    sessions = []
    for fname in sorted(Path(folder).glob("session_*.json")):
        try:
            with open(fname, "r", encoding="utf-8") as f:
                sessions.append(json.load(f))
        except (json.JSONDecodeError, OSError) as e:
            print(f"  WARNING: Skipping {fname.name}: {e}")
    return sessions


def analyze(sessions: list[dict]) -> None:
    combat_events = []
    death_events = []
    run_events = []
    session_durations = []

    for session in sessions:
        for ev in session.get("events", []):
            t = ev.get("type", "")
            if t == "combat_end":
                combat_events.append(ev)
            elif t == "hero_death":
                death_events.append(ev)
            elif t == "run_end":
                run_events.append(ev)
            elif t == "session_end":
                dur = ev.get("duration_seconds", 0)
                if dur > 0:
                    session_durations.append(dur)

    print("=" * 60)
    print("  PLAYTEST TELEMETRY SUMMARY")
    print("=" * 60)
    print(f"  Sessions: {len(sessions)}")
    if session_durations:
        avg_dur = sum(session_durations) / len(session_durations)
        print(f"  Avg session duration: {avg_dur / 60:.1f} min")
    print()

    # Combat stats by region
    if combat_events:
        print("--- Combat Results by Region ---")
        by_region = defaultdict(lambda: {"wins": 0, "losses": 0, "rounds": [], "duration": []})
        for ev in combat_events:
            region = ev.get("region", "unknown")
            entry = by_region[region]
            if ev.get("outcome") == "VICTORY":
                entry["wins"] += 1
            else:
                entry["losses"] += 1
            entry["rounds"].append(ev.get("rounds", 0))
            entry["duration"].append(ev.get("duration_ms", 0))

        for region in sorted(by_region.keys()):
            d = by_region[region]
            total = d["wins"] + d["losses"]
            win_rate = d["wins"] / total * 100 if total > 0 else 0
            avg_rounds = sum(d["rounds"]) / len(d["rounds"]) if d["rounds"] else 0
            avg_ms = sum(d["duration"]) / len(d["duration"]) if d["duration"] else 0
            print(f"  {region}: {total} fights, {win_rate:.0f}% win, avg {avg_rounds:.1f} rounds, {avg_ms / 1000:.1f}s")
        print()

    # Combat by floor
    if combat_events:
        print("--- Combat by Floor ---")
        by_floor = defaultdict(lambda: {"wins": 0, "losses": 0})
        for ev in combat_events:
            floor_num = ev.get("floor", 0)
            if ev.get("outcome") == "VICTORY":
                by_floor[floor_num]["wins"] += 1
            else:
                by_floor[floor_num]["losses"] += 1
        for floor_num in sorted(by_floor.keys()):
            d = by_floor[floor_num]
            total = d["wins"] + d["losses"]
            win_rate = d["wins"] / total * 100 if total > 0 else 0
            print(f"  Floor {floor_num}: {total} fights, {win_rate:.0f}% win rate")
        print()

    # Boss encounters
    boss_fights = [ev for ev in combat_events if ev.get("boss")]
    if boss_fights:
        print("--- Boss Encounters ---")
        wins = sum(1 for ev in boss_fights if ev.get("outcome") == "VICTORY")
        print(f"  Total: {len(boss_fights)}, Wins: {wins}, Losses: {len(boss_fights) - wins}")
        print()

    # Hero deaths
    if death_events:
        print("--- Hero Deaths by Class ---")
        by_class = defaultdict(int)
        for ev in death_events:
            by_class[ev.get("hero_class", "unknown")] += 1
        for cls in sorted(by_class.keys(), key=lambda c: -by_class[c]):
            print(f"  {cls}: {by_class[cls]} deaths")
        print()

        print("--- Deaths by Region/Floor ---")
        by_loc = defaultdict(int)
        for ev in death_events:
            key = f"{ev.get('region', '?')} F{ev.get('floor', '?')}"
            by_loc[key] += 1
        for loc in sorted(by_loc.keys(), key=lambda l: -by_loc[l]):
            print(f"  {loc}: {by_loc[loc]} deaths")
        print()

    # Dungeon runs
    if run_events:
        print("--- Dungeon Runs ---")
        print(f"  Total runs: {len(run_events)}")
        floors = [ev.get("floors_cleared", 0) for ev in run_events]
        if floors:
            print(f"  Avg floors cleared: {sum(floors) / len(floors):.1f}")
        print()

    print("=" * 60)


def main():
    if len(sys.argv) < 2:
        print("Usage: python parse_telemetry.py <telemetry_folder>")
        print("  Folder is typically: %APPDATA%/Godot/app_userdata/ShopKeepersGame/telemetry")
        sys.exit(1)

    folder = sys.argv[1]
    if not os.path.isdir(folder):
        print(f"ERROR: Directory not found: {folder}")
        sys.exit(1)

    sessions = load_sessions(folder)
    if not sessions:
        print("No session files found.")
        sys.exit(0)

    analyze(sessions)


if __name__ == "__main__":
    main()
