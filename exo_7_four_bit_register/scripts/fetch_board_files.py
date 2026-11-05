#!/usr/bin/env python3
"""Download the PYNQ-Z2 board definition from a pinned Xilinx revision."""
from pathlib import Path
from urllib.request import urlopen

REVISION = "7a130a4f46db7b4c89871626093308c1642cb53c"
ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / "build/board_files/pynq-z2/A.0"
BASE = ("https://raw.githubusercontent.com/Xilinx/"
        f"xup_embedded_system_design_flow/{REVISION}/board_files/pynq-z2/A.0")


def main():
    DEST.mkdir(parents=True, exist_ok=True)
    for name in ("board.xml", "preset.xml", "part0_pins.xml", "pynq_z2.jpg"):
        with urlopen(f"{BASE}/{name}", timeout=30) as response:
            content = response.read()
        (DEST / name).write_bytes(content)
        print(f"Downloaded {name}: {len(content)} bytes")
    print(f"Board repository: {DEST.parents[1]}")


if __name__ == "__main__":
    main()
