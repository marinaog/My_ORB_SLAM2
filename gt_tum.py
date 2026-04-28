#!/usr/bin/env python3
"""
Convert a RawSLAM groundtruth.txt to TUM format for use with evo_ape.

Input format (space-separated):
    frame_id  timestamp_ms  x  y  z  roll_deg  pitch_deg  yaw_deg
    (Euler XYZ extrinsic, degrees; first line is a # comment)

Output format (TUM):
    timestamp_s  tx  ty  tz  qx  qy  qz  qw

Usage:
    python3 gt_tum.py <scene_dir>
    python3 gt_tum.py datasets/rawslam/bottles
"""

import sys
import math
import os


def euler_xyz_deg_to_quat(rx_deg, ry_deg, rz_deg):
    """Euler XYZ extrinsic angles (degrees) -> quaternion (qx, qy, qz, qw)."""
    rx = math.radians(rx_deg)
    ry = math.radians(ry_deg)
    rz = math.radians(rz_deg)
    cx, sx = math.cos(rx / 2), math.sin(rx / 2)
    cy, sy = math.cos(ry / 2), math.sin(ry / 2)
    cz, sz = math.cos(rz / 2), math.sin(rz / 2)
    # R = Rx * Ry * Rz  (XYZ extrinsic == ZYX intrinsic)
    qw = cx*cy*cz - sx*sy*sz
    qx = sx*cy*cz + cx*sy*sz
    qy = cx*sy*cz - sx*cy*sz
    qz = cx*cy*sz + sx*sy*cz
    return qx, qy, qz, qw


def convert(scene_dir):
    gt_path  = os.path.join(scene_dir, "groundtruth.txt")
    out_path = os.path.join(scene_dir, "groundtruth_tum.txt")

    if not os.path.exists(gt_path):
        print(f"[ERROR] groundtruth.txt not found in {scene_dir}", file=sys.stderr)
        sys.exit(1)

    lines_out = []
    with open(gt_path) as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith('#'):
                continue
            parts = line.split()
            ts_s = float(parts[1]) / 1000.0
            x, y, z = float(parts[2]), float(parts[3]), float(parts[4])
            rx, ry, rz = float(parts[5]), float(parts[6]), float(parts[7])
            qx, qy, qz, qw = euler_xyz_deg_to_quat(rx, ry, rz)
            lines_out.append(
                f"{ts_s:.6f} {x:.6f} {y:.6f} {z:.6f} "
                f"{qx:.6f} {qy:.6f} {qz:.6f} {qw:.6f}"
            )

    with open(out_path, "w") as f:
        f.write("\n".join(lines_out) + "\n")

    print(f"Written {len(lines_out)} poses -> {out_path}")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print(f"Usage: python3 {sys.argv[0]} <scene_dir>")
        sys.exit(1)
    convert(sys.argv[1])
