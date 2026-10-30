#!/usr/bin/env python3
"""Convert the REMIND JSON grids into the binary file the app loads (REMIND_cells.bin).

Re-run after changing either JSON file:
    python3 Scripts/convert_remind_json.py

Format (little-endian):
    header: b"RMD1", uint32 cellCount
    per cell: uint16 lon, uint16 lat, uint16 baseCount, uint16 policyCount,
              float32[baseCount] baseline values, float32[policyCount] 2-degree-policy values
Only cells present in both files are written (same rule the app used with the JSON files).
"""

import json
import struct
from array import array
from pathlib import Path

DATA = Path(__file__).resolve().parent.parent / "ARKitExample" / "Data"
BASE = DATA / "REMIND_BASE_v02_ACCU.json"
POLICY = DATA / "REMIND_26_v02_ACCU.json"
OUT = DATA / "REMIND_cells.bin"


def main():
    base = json.loads(BASE.read_text())
    policy = json.loads(POLICY.read_text())

    cells = []
    for lat_key in sorted(base, key=int):
        policy_lat = policy.get(lat_key)
        if policy_lat is None:
            continue
        for lon_key in sorted(base[lat_key], key=int):
            policy_values = policy_lat.get(lon_key)
            if policy_values is None:
                continue
            cells.append((int(lon_key), int(lat_key), base[lat_key][lon_key], policy_values))

    with OUT.open("wb") as out:
        out.write(struct.pack("<4sI", b"RMD1", len(cells)))
        for lon, lat, base_values, policy_values in cells:
            out.write(struct.pack("<HHHH", lon, lat, len(base_values), len(policy_values)))
            floats = array("f", base_values + policy_values)
            if floats.itemsize != 4:
                raise SystemExit("float32 expected")
            out.write(floats.tobytes())

    print(f"Wrote {len(cells)} cells to {OUT} ({OUT.stat().st_size / 1e6:.1f} MB)")


if __name__ == "__main__":
    main()
