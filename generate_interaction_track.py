"""
Generate a 16-bit TIFF stack visualizing particle tracks from a single CSV
where each row is a particle and each pair of columns is (X, Y) at a
successive timepoint.

Input CSV (no header row/column):
  - Columns 1 & 2: X, Y at timepoint 1
  - Columns 3 & 4: X, Y at timepoint 2
  - ... etc.
  - Each row is a different particle
  - 'NaN' means that particle is absent at that timepoint

Output: a 16-bit TIFF stack with one slice per particle.
On each particle's slice, a line is drawn between its position at the
current timepoint and its position at the next timepoint, for every pair of
consecutive timepoints where it is present in both. Line thickness = the
user-defined line width. Line intensity = the current (source) timepoint
number (1-indexed) - e.g. the segment connecting timepoint 4 to timepoint 5
has intensity 4.

Since segments for a given particle are drawn onto its slice in timepoint
order, a later segment crossing an earlier one on the same track overwrites
it with the newer intensity. Particles that appear or disappear mid-series
simply have no segment drawn for the timepoint pair where either end is
absent - the rest of the track is drawn normally.

Bryan Heit, September 2026
"""

import numpy as np
import pandas as pd
import cv2
import tifffile


def main():
    #  User inputs 
    csv_file = input("Path to particle position CSV: ").strip()
    width = int(input("Image width (X size, pixels): ").strip())
    height = int(input("Image height (Y size, pixels): ").strip())
    line_width = int(input("Line width (pixels): ").strip())
    output_path = input("Output TIFF path (e.g. tracks.tif): ").strip()

    #  Load data 
    data = pd.read_csv(csv_file, header=None).values.astype(float)
    n_particles, n_cols = data.shape

    if n_cols % 2 != 0:
        raise ValueError(f"Expected an even number of columns (X/Y pairs), got {n_cols}")

    n_timepoints = n_cols // 2

    # Verify the  data 
    nan_count = int(np.isnan(data).sum())
    finite_vals = data[~np.isnan(data)]
    print(f"Loaded {n_particles} particles across {n_timepoints} timepoints.")
    print(f"NaN entries: {nan_count} / {data.size}")
    if finite_vals.size > 0:
        print(f"Finite value range: {finite_vals.min()} to {finite_vals.max()}")
    else:
        print("WARNING: no finite values found in the CSV at all.")
    print(f"Output stack: {width} x {height}, {n_particles} slices, line width = {line_width}")

    #  Build the stack 
    stack = np.zeros((n_particles, height, width), dtype=np.uint16)

    for i in range(n_particles):
        row = data[i]
        X = row[0::2]
        Y = row[1::2]

        slice_img = np.zeros((height, width), dtype=np.uint16)

        for t in range(n_timepoints - 1):
            x1, y1 = X[t], Y[t]
            x2, y2 = X[t + 1], Y[t + 1]

            present_now = not (np.isnan(x1) or np.isnan(y1))
            present_next = not (np.isnan(x2) or np.isnan(y2))

            if present_now and present_next:
                timepoint_number = t + 1  # 1-indexed, used as line intensity
                pt1 = (int(round(x1)), int(round(y1)))
                pt2 = (int(round(x2)), int(round(y2)))
                cv2.line(
                    slice_img, pt1, pt2,
                    color=int(timepoint_number), thickness=line_width,
                    lineType=cv2.LINE_8,
                )
            # If either end is absent (particle appearing or disappearing
            # here), skip this segment.

        stack[i] = slice_img

    #  Confirm data has non-zero values 
    max_val = int(stack.max())
    nonzero_px = int(np.count_nonzero(stack))
    print(f"Max pixel intensity written: {max_val}  |  Non-zero pixels: {nonzero_px}")
    if max_val == 0:
        print("WARNING: stack is entirely zero - check that coordinates are being read correctly.")

    #  Save as 16-bit TIFF stack 
    tifffile.imwrite(
        output_path, stack, dtype=np.uint16, imagej=True,
        metadata={"min": 0, "max": max_val if max_val > 0 else 1},
    )
    print(f"Saved TIFF stack to {output_path}")


if __name__ == "__main__":
    main()
