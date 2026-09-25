"""
Generate a summary of data from the actin branching/skeletonization analysis.

Creates Summary.csv from a set of "eSRRF_XXX_YYY" subdirectories created by 
esrrf_skeletonize_folder.ijm.

For each subdirectory:
  - Column A: the XXX portion of the folder name
  - Columns B-G: averages of columns B, C, H, I, J, K from files ending in "Results.csv"
  - Column H: average of column I from files ending in "Branchinfo.csv"
  - Column I: (average of column B) / (average of column I) from the same Branchinfo.csv

Bryan Heit, September 2026
"""

import os
import pandas as pd
import numpy as np

#  CONFIGURATION 
parent_dir = input("Enter the path to the parent folder containing the eSRRF_XXX_YYY subdirectories: ").strip()
output_csv = os.path.join(parent_dir, "Summary.csv")

# 0-indexed column positions for Results.csv: spreadsheet columns B, C, H, I, J, K
RESULTS_COLS = [1, 2, 7, 8, 9, 10]

# 0-indexed column positions for Branchinfo.csv: spreadsheet columns B and I
BRANCH_COL_B = 1
BRANCH_COL_I = 8


def col_average(df, col_idx):
    """Return the mean of a 0-indexed column, or NaN if the column doesn't exist."""
    if col_idx >= df.shape[1]:
        return np.nan
    return pd.to_numeric(df.iloc[:, col_idx], errors="coerce").mean()


def find_target_files(subdir_path):
    """Locate the files ending in 'Branchinfo.csv' and 'Results.csv'."""
    results_file = None
    branchinfo_file = None
    for fname in os.listdir(subdir_path):
        lower = fname.lower()
        if lower.endswith("branchinfo.csv"):
            branchinfo_file = os.path.join(subdir_path, fname)
        elif lower.endswith("results.csv"):
            results_file = os.path.join(subdir_path, fname)
    return results_file, branchinfo_file


def extract_xxx(folder_name):
    """Extract the XXX folder name."""
    parts = folder_name.split("_")
    if len(parts) >= 2:
        return parts[1]
    return folder_name  # fallback if the name doesn't match the expected pattern


def main():
    subdirs = sorted(
        d for d in os.listdir(parent_dir)
        if os.path.isdir(os.path.join(parent_dir, d)) and d.startswith("eSRRF_")
    )

    if not subdirs:
        print(f"No 'eSRRF_' subdirectories found in {parent_dir}")
        return

    rows = []

    for subdir in subdirs:
        subdir_path = os.path.join(parent_dir, subdir)
        xxx = extract_xxx(subdir)

        results_file, branchinfo_file = find_target_files(subdir_path)

        if results_file is None or branchinfo_file is None:
            print(f"Warning: missing Results.csv or Branchinfo.csv in '{subdir}' - skipping")
            continue

        #  Results.csv: averages for columns B, C, H, I, J, K -> Summary columns B-G 
        results_df = pd.read_csv(results_file)
        results_avgs = [col_average(results_df, idx) for idx in RESULTS_COLS]

        #  Branchinfo.csv: average of column I -> Summary column H 
        #     ratio avg(B)/avg(I) -> Summary column I 
        branch_df = pd.read_csv(branchinfo_file)
        branch_avg_I = col_average(branch_df, BRANCH_COL_I)
        branch_avg_B = col_average(branch_df, BRANCH_COL_B)

        if pd.isna(branch_avg_I) or branch_avg_I == 0:
            ratio = np.nan
        else:
            ratio = branch_avg_B / branch_avg_I

        row = [xxx] + results_avgs + [branch_avg_I, ratio]
        rows.append(row)

    summary_df = pd.DataFrame(rows)
    summary_df.to_csv(output_csv, index=False, header=False)

    print(f"\nSummary.csv written to: {output_csv}")
    print(f"Rows written: {len(rows)}")


if __name__ == "__main__":
    main()
