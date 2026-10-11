"""Start the existing Qud + Raves pair without duplicating or terminating either app.

Uses Steam for Qud, the mod's localhost bridge, and Raves' --join-running flag.
No saves, mod permissions, or visual preferences are changed by this launcher.
"""
import argparse
import csv
import io
import json
import os
from pathlib import Path
import socket
import subprocess
import sys
import time
from datetime import datetime, timezone

REPO = Path(__file__).resolve().parents[1]
WORK = REPO.parent
DEFAULT_ENGINE = WORK / "runtime/godot/bin/Godot_v4.7.2-stable_win64.exe"
SUPPORT = Path(os.environ.get("USERPROFILE", str(Path.home()))) / "Library/Application Support/RavesOfQud"
RECEIPT = WORK / "raves-launch-status.json"


def listening(port):
    try:
        with socket.create_connection(("127.0.0.1", port), timeout=0.3):
            return True
    except OSError:
        return False


def qud_running():
    result = subprocess.run(
        ["tasklist", "/FI", "IMAGENAME eq CoQ.exe", "/FO", "CSV", "/NH"],
        capture_output=True, text=True, timeout=10,
        creationflags=subprocess.CREATE_NO_WINDOW,
    )
    if result.returncode:
        raise RuntimeError("Could not check whether Qud is running; no duplicate was started.")
    return any(row and row[0].lower() == "coq.exe" for row in csv.reader(io.StringIO(result.stdout)))


def state(filename):
    path = SUPPORT / filename
    try:
        if time.time() - path.stat().st_mtime > 10:
            return {}
        return json.loads(path.read_text(encoding="utf-8-sig"))
    except (OSError, ValueError):
        return {}


def record(status, detail, **extra):
    payload = {"time": datetime.now(timezone.utc).isoformat(),
               "status": status, "detail": detail, **extra}
    RECEIPT.write_text(json.dumps(payload, indent=2), encoding="utf-8")
    print(detail, flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="Check dependencies without launching apps")
    parser.add_argument("--engine", type=Path, default=DEFAULT_ENGINE)
    parser.add_argument("--wait-seconds", type=int, default=60)
    args = parser.parse_args()
    if not 1 <= args.wait_seconds <= 120:
        raise ValueError("--wait-seconds must be between 1 and 120")
    if not args.engine.is_file():
        raise FileNotFoundError(f"Godot is missing: {args.engine}")
    if not (REPO / "godot/project.godot").is_file():
        raise FileNotFoundError(f"Raves project is missing: {REPO / 'godot'}")
    if args.check:
        record("checked", "Godot and the Raves project are present. No apps were started.",
               bridge=listening(48710), viewer=listening(17893))
        return 0
    if listening(17893):
        current = state("raves_state.json")
        if current.get("popup"):
            record("menu_open", "Raves is already running with a menu open. Switch to Raves "
                   "with Alt+Tab and close the menu to resume.", viewer_state=current)
            return 0
        # Snapshots are turn-driven; an idle game can keep the same snapshot
        # for hours. The separately refreshed state files prove app liveness.
        if (current.get("scene") == "in_game" and current.get("snap_ts", 0) > 0
                and state("qud_state.json").get("live") and listening(48710)):
            record("ready", "Raves has loaded your running game. Switch to it with Alt+Tab.",
                   viewer_state=current)
            return 0
        if current.get("scene") == "title":
            record("already_running", "Raves is already at its title screen. Load a character "
                   "in Qud, then use Continue in Raves if it does not attach automatically.",
                   viewer_state=current)
            return 0
        raise RuntimeError("Raves is already running, but fresh game data could not be confirmed. "
                           "Switch to Qud, close its pause menu, then retry this launcher. "
                           "No duplicate was started.")
    if not listening(48710):
        if not qud_running():
            print("Starting Caves of Qud through Steam...", flush=True)
            os.startfile("steam://rungameid/333640")
        print("Waiting for Qud's bridge. Enable Raves of Mud Bridge in Qud if needed.", flush=True)
        deadline = time.monotonic() + args.wait_seconds
        while not listening(48710):
            if time.monotonic() >= deadline:
                raise TimeoutError("Qud's bridge did not start in time. Check its Mods screen, "
                                   "restart Qud if requested, then run this launcher again.")
            time.sleep(0.5)
    process = subprocess.Popen(
        [str(args.engine), "--path", str(REPO / "godot"),
         "--log-file", str(WORK / "raves-live.log"), "--", "--join-running"],
        cwd=REPO, creationflags=subprocess.CREATE_NO_WINDOW,
    )
    deadline = time.monotonic() + 30
    while time.monotonic() < deadline:
        if process.poll() is not None:
            raise RuntimeError(f"Raves exited during startup (code {process.returncode}). "
                               f"See {WORK / 'raves-live.log'}")
        current = state("raves_state.json")
        if current.get("pid") == process.pid:
            if current.get("scene") == "in_game" and current.get("snap_ts", 0) > 0:
                record("connected", "Raves is displaying your running game. Keep Qud open.",
                       pid=process.pid, viewer_state=current)
                return 0
            if current.get("scene") == "title" and not state("qud_state.json").get("live"):
                record("waiting_for_character", "Raves is ready. Load or create a character in Qud; "
                       "Raves will attach automatically.", pid=process.pid)
                return 0
        time.sleep(0.5)
    raise TimeoutError("Raves opened, but a live game connection was not confirmed within 30 seconds. "
                       "Switch to Qud and close its pause menu, then retry this launcher. "
                       "The apps were left running; details are in raves-live.log.")


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as exc:
        record("failed", str(exc))
        sys.exit(1)
