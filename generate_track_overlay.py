"""
Generates a single 16-bit TIFF image visualizing object tracks from paired X/Y
coordinate spreadsheets.

Input spreadsheets (csv or xlsx, no header row/column):
  - X-coordinates file: one row per object, one column per timepoint
  - Y-coordinates file: same as X-coordinates file
  - A value of 0 in the X and Y sheet for a given object/timepoint means
    that object is absent at that timepoint

Output: a single 16-bit TIFF image where diffusion tracks are drawn for all
particles in the input spreadsheets. Line thickness is user-defined and line 
intensity = partices timepoint (e.g. frame 1 has intensity = 1, frame 25 has 
intensity = 25). 

Crossing tracks overwrite with the newer intensity. Objects that appear or 
disappear mid-series have no segment drawn between the "gap" in the track.

Bryan Heit - September 2026
"""

import numpy as np
import pandas as pd
import cv2
import tifffile


def load_table(path):
    """Load coordinate spreadsheet (csv or xlsx)."""
    if path.lower().endswith((".xlsx", ".xls")):
        return pd.read_excel(path, header=None).values
    return pd.read_csv(path, header=None).values


def main():
    #  User inputs 
    x_file = input("Path to X-coordinates spreadsheet: ").strip()
    y_file = input("Path to Y-coordinates spreadsheet: ").strip()
    width = int(input("Image width (X size, pixels): ").strip())
    height = int(input("Image height (Y size, pixels): ").strip())
    line_width = int(input("Line width (pixels): ").strip())
    output_path = input("Output TIFF path (e.g. tracks.tif): ").strip()

    #  Load coordinate data 
    X = load_table(x_file)
    Y = load_table(y_file)

    if X.shape != Y.shape:
        raise ValueError(f"X and Y tables must match in shape. Got X{X.shape}, Y{Y.shape}")

    #  Verify the loaded data actually looks like coordinates 
    print(f"X dtype: {X.dtype}, Y dtype: {Y.dtype}")
    print(f"X range: {np.nanmin(X)} to {np.nanmax(X)}  |  non-zero entries: {np.count_nonzero(X)} / {X.size}")
    print(f"Y range: {np.nanmin(Y)} to {np.nanmax(Y)}  |  non-zero entries: {np.count_nonzero(Y)} / {Y.size}")

    n_objects, n_frames = X.shape
    print(f"Loaded {n_objects} objects across {n_frames} timepoints.")
    print(f"Output image: {width} x {height}, line width = {line_width}")

    #  Build the image 
    img = np.zeros((height, width), dtype=np.uint16)

    for t in range(n_frames - 1):
        timepoint_number = t + 1  # 1-indexed, used as the line intensity

        for i in range(n_objects):
            x1, y1 = X[i, t], Y[i, t]
            x2, y2 = X[i, t + 1], Y[i, t + 1]

            present_now = not (x1 == 0 and y1 == 0)
            present_next = not (x2 == 0 and y2 == 0)

            if present_now and present_next:
                pt1 = (int(round(x1)), int(round(y1)))
                pt2 = (int(round(x2)), int(round(y2)))
                cv2.line(
                    img, pt1, pt2,
                    color=int(timepoint_number), thickness=line_width,
                    lineType=cv2.LINE_8,
                )
            # If either end is absent (object appearing or disappearing here),
            # no line is drawn for that gap.

    #  Confirm data actually has non-zero, meaningful values 
    max_val = int(img.max())
    nonzero_px = int(np.count_nonzero(img))
    print(f"Max pixel intensity written: {max_val}  |  Non-zero pixels: {nonzero_px}")
    if max_val == 0:
        print("WARNING: image is entirely zero - check that coordinates are being read correctly.")

    #  Save as 16-bit TIFF
    tifffile.imwrite(
        output_path, img, dtype=np.uint16, imagej=True,
        metadata={"min": 0, "max": max_val if max_val > 0 else 1},
    )
    print(f"Saved TIFF image to {output_path}")


if __name__ == "__main__":
    main()
