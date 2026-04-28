#!/usr/bin/env python3
"""
Generate an ORB-SLAM2 association file for a RawSLAM scene.

The RawSLAM dataset layout expected inside <scene_dir>:
    groundtruth.txt        -- space-separated: frame_id  timestamp_ms  x y z rx ry rz
    sRGB/<frame_id>.png    -- standard 8-bit sRGB images
    raw_linear_sRGB/<id>.png  -- 16-bit linear HDR images (used when 'raw' flag given)
    depth/<frame_id>.png

Output format (one line per frame, matches LoadImages() in rgbd_rawslam.cc):
    timestamp_s  <rgb_subdir>/<id>.png  timestamp_s  depth/<id>.png

Usage:
    python3 associate_rawslam.py <scene_dir> [raw] [output_file]

Examples:
    python3 associate_rawslam.py datasets/rawslam/bottles
        -> Examples/RGB-D/associations/rawslam_bottles.txt  (sRGB paths)

    python3 associate_rawslam.py datasets/rawslam/bottles raw
        -> Examples/RGB-D/associations/rawslam_bottles.txt  (raw_linear_sRGB paths)

    python3 associate_rawslam.py datasets/rawslam/bottles my_assoc.txt
        -> my_assoc.txt  (sRGB paths)

    python3 associate_rawslam.py datasets/rawslam/bottles raw my_assoc.txt
        -> my_assoc.txt  (raw_linear_sRGB paths)
"""

import sys
import os


ASSOC_DIR = "Examples/RGB-D/associations"


def associate(scene_dir, use_raw=False, out_path=None):
    rgb_subdir = "raw_linear_sRGB" if use_raw else "sRGB"
    gt_path    = os.path.join(scene_dir, "groundtruth.txt")
    rgb_dir    = os.path.join(scene_dir, rgb_subdir)
    depth_dir  = os.path.join(scene_dir, "depth")

    if not os.path.exists(gt_path):
        print(f"[ERROR] groundtruth.txt not found in {scene_dir}", file=sys.stderr)
        sys.exit(1)

    if out_path is None:
        scene_name = os.path.basename(os.path.normpath(scene_dir))
        suffix = "_raw" if use_raw else ""
        out_path = os.path.join(ASSOC_DIR, f"rawslam_{scene_name}{suffix}.txt")

    os.makedirs(os.path.dirname(out_path), exist_ok=True)

    lines_out = []
    skipped = 0

    with open(gt_path) as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith('#'):
                continue
            parts = line.split()
            frame_id = parts[0]                     # e.g. "273"
            ts_s     = float(parts[1]) / 1000.0    # ms -> seconds

            rgb_rel = f"{rgb_subdir}/{frame_id}.png"
            dep_rel = f"depth/{frame_id}.png"

            if not os.path.exists(os.path.join(rgb_dir, f"{frame_id}.png")):
                skipped += 1
                continue
            if not os.path.exists(os.path.join(depth_dir, f"{frame_id}.png")):
                skipped += 1
                continue

            lines_out.append(f"{ts_s:.6f} {rgb_rel} {ts_s:.6f} {dep_rel}")

    with open(out_path, "w") as f:
        f.write("\n".join(lines_out) + "\n")

    mode = "raw_linear_sRGB (16-bit HDR)" if use_raw else "sRGB (8-bit)"
    print(f"[{mode}] Written {len(lines_out)} associations -> {out_path}")
    if skipped:
        print(f"Skipped {skipped} frames (missing {rgb_subdir} or depth image)")


if __name__ == "__main__":
    args = sys.argv[1:]
    if len(args) < 1 or len(args) > 3:
        print(f"Usage: python3 {sys.argv[0]} <scene_dir> [raw] [output_file]")
        sys.exit(1)

    scene_dir = args[0]
    use_raw   = False
    out_path  = None

    remaining = args[1:]
    if remaining and remaining[0] == "raw":
        use_raw   = True
        remaining = remaining[1:]
    if remaining:
        out_path = remaining[0]

    associate(scene_dir, use_raw, out_path)
