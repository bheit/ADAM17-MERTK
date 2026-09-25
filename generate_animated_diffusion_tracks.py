"""
Generate a 16-bit TIFF stack visualizing object tracks from paired X/Y coordinate
spreadsheets.

Input spreadsheets (csv or xlsx, no header row/column):
  - X-coordinates file: one row per object, one column per timepoint
  - Y-coordinates file: same as X-coordinates file
  - A value of 0 in the X and Y sheet for a given object/timepoint means
    that object is absent at that timepoint

Output: a multi-page 16-bit TIFF where:
  - Frame 1 shows a filled circle (diameter = 2x line width) at each 
    object's starting position, with intensity = n_frames + 1
  - Each subsequent frame draws a line from the object's previous position to
    its current position, with thickness = line width and intensity = the
    current frame number
  - Once drawn, a track segment persists on all later frames unless a newer 
    segment is drawn on top of it
  - Objects that disappear mid-series leave their existing track in place
  - If an object appears mid-series it starts fresh (no line drawn back to
    frame 1)
  - The position marker (circle) is drawn on every frame except the final
    frame, which shows only the accumulated tracks
    
Bryan Heit, September 2026
"""

import numpy as np
import pandas as pd
import cv2
import tifffile


def load_table(path):
    """Load a coordinate spreadsheet (csv or xlsx) with no header row/column."""
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

    #  Diagnostic: verify the loaded data actually looks like coordinates 
    print(f"X dtype: {X.dtype}, Y dtype: {Y.dtype}")
    print(f"X range: {np.nanmin(X)} to {np.nanmax(X)}  |  non-zero entries: {np.count_nonzero(X)} / {X.size}")
    print(f"Y range: {np.nanmin(Y)} to {np.nanmax(Y)}  |  non-zero entries: {np.count_nonzero(Y)} / {Y.size}")
    print(f"X row 0, first 5 values: {X[0, :5]}")
    print(f"Y row 0, first 5 values: {Y[0, :5]}")

    n_objects, n_frames = X.shape
    marker_intensity = n_frames + 1
    circle_radius = line_width  # diameter = 2 x line width

    print(f"Loaded {n_objects} objects across {n_frames} timepoints.")
    print(f"Output stack: {width} x {height}, {n_frames} slices, marker intensity = {marker_intensity}")

    #  Build stack 
    accumulator = np.zeros((height, width), dtype=np.uint16)
    stack = np.zeros((n_frames, height, width), dtype=np.uint16)

    # Last known position of each object
    prev_pos = [None] * n_objects

    for t in range(n_frames):
        frame_number = t + 1  # used as line intensity

        current_present = []
        for i in range(n_objects):
            x_val, y_val = X[i, t], Y[i, t]
            present = not (x_val == 0 and y_val == 0)

            if present:
                cur = (int(round(x_val)), int(round(y_val)))
                if prev_pos[i] is not None:
                    # Connect previous position to current position
                    cv2.line(
                        accumulator, prev_pos[i], cur,
                        color=int(frame_number), thickness=line_width,
                        lineType=cv2.LINE_8,
                    )
                # else: new object - no line, marker only
                prev_pos[i] = cur
                current_present.append(cur)
            else:
                # Object absent - reset so a future reappearance starts fresh
                # instead of drawing a line across the gap
                prev_pos[i] = None

        # Copy the accumulated tracks into final frame
        stack[t] = accumulator

        # Overlay current-position markers, except on the final frame
        if t < n_frames - 1:
            frame_with_marker = stack[t].copy()
            for cur in current_present:
                cv2.circle(
                    frame_with_marker, cur, radius=circle_radius,
                    color=int(marker_intensity), thickness=-1,
                )
            stack[t] = frame_with_marker

    #  Confirm data actually has non-zero, meaningful values 
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
