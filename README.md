# ADAM17-MERTK
All analysis scripts used for the paper "The Actin Cytoskeleton and Caveolae Regulate MERTK Cleavage by ADAM17."
Scripts are provided as-is, and with no warranty. Information on how to use each script can be found in the comment field at the top of each file. 

## Brief description of each script:
### Dual-Colour SPT
- CalibrateWView.m: Matlab script used to calibrate images captured using a W-View or other image splitter with sub-pixel resolution. Requires a short (12-50 frame) timelapse of tetraspec beads or another sub-resolution calibration target that emits in both channels.
- DualSPTAnalysis.m: Matlab script used to identify and measure interactions between molecules tracked within a dual-colour single-particle tracking experiment.

<!-- end of the list -->

* * Note: Both scripts require single particle tracking files analyzed using the software of Jaqaman, K., Loerke, D., Mettlen, M. et al. Robust single-particle tracking in live-cell time-lapse sequences. Nat Methods 5, 695–702 (2008). https://doi.org/10.1038/nmeth.1237 * *

- extractXY.m: Matlab script that extracts the coordinates of freely diffusing and confined moleucles from the particle tracking files.
- generate_track_overlay.py: python script that generates a 16-bit greyscale image of diffusion tracks.
- generate_interaction_track.py: python script. Same as generate_track_overlay.py, but uses a different format of input file.
- generate_animated_diffusion_tracks.py: python script that generates an multi-page 16-bit TIFF animates of diffusion tracks.
- SPTtrack_Cyan.lut: ImageJ/FIJI blue-cyan LUT for time-coding diffusion tracks.
- SPTtrack_Yellow.lut:  ImageJ/FIJI red-yellow LUT for time-coding diffusion tracks. No colour overlap with SPTtrack_Cyan.lut
- black2white.ijm: Alters RGB images encoded with SPTtrack_Cyan.lut or SPTtrack_Yellow.lut to place tracks over a white background.

### Actin Skeletonization Analysis
- /Ilastik Model
  - ActinClassification.ilp: Pre-trained classifier for segmenting actin from eSRRF images.
  - Training Images.zip: Compressed folder containing the training images required by ActinClassification.ilp. These must be decompressed and kept in the same folder as ActinClassification.ilp for the model to work.
- esrrf_skeletonize_folder.ijm: FIJI (imageJ) macro that runs Skeletonize (2D/3D) and Analyze Skeleton on the output of the Ilastik Model.

Please cite our paper <citation> if you use these scripts in your own research.
