// Script to batch-process eSRRF actin cytoskeleton data on all TIFF files 
// in a user-selected folder. Includes a manual cleanup pause for each image
// before skeletonization.

// Note: users may need to edit line 28 to provide correct scaling to their 
// eSRRF iamges

// Bryan Heit, September 2026

inputDir = getDirectory("Choose folder containing segmented tif files to process");
list = getFileList(inputDir);

for (i = 0; i < list.length; i++) {
    filename = list[i];

    // Only process TIFF files
    if (!(endsWith(toLowerCase(filename), ".tif") || endsWith(toLowerCase(filename), ".tiff"))) {
        continue;
    }

    open(inputDir + filename);

    //Threshold and set pixel scale to 130nm/5 = 26 nm
    setThreshold(2, 255);
    setOption("BlackBackground", true);
    run("Convert to Mask");
    Stack.setXUnit("micron");
    run("Properties...", "channels=1 slices=1 frames=1 pixel_width=0.026 pixel_height=0.026 voxel_depth=0.026");

    //Extract file name
    dir = getInfo("image.directory");
    title = getTitle();
    dotIndex = lastIndexOf(title, ".");
    if (dotIndex != -1)
        baseName = substring(title, 0, dotIndex);
    else
        baseName = title;

    //Allow user to delete non-signal areas of image
    newName = baseName + "-Thresholded";
    dlgTitle = "Cleanup Image";
    msg = "If necessary, use the Selection tools to\ndelete any non-cell signal, then click \"OK\".\n\nProcessing file " + (i + 1) + " of " + list.length + ": " + filename;
    waitForUser(dlgTitle, msg);

    //Skeletonize & analyze
    run("Skeletonize (2D/3D)");
    run("Analyze Skeleton (2D/3D)", "prune=none calculate show display");

    //Create output directory
    nDir = dir + baseName + File.separator;
    File.makeDirectory(nDir);

    //save files
    newName = baseName + "-Branchinfo.csv";
    selectWindow("Branch information");
    saveAs("Results", nDir + newName);

    newName = baseName + "-Results.csv";
    selectWindow("Results");
    saveAs("Results", nDir + newName);

    selectWindow("Longest shortest paths");
    saveAs("Tiff", nDir + baseName + "-Paths");

    selectWindow("Tagged skeleton");
    saveAs("Tiff", nDir + baseName + "-TaggedSkeleton");

    selectWindow(baseName + ".tif");
    saveAs("Tiff", nDir + baseName + "-Skeleton");

    wait(200);

    //Close everything before moving to the next file
    close("*");
    if (isOpen("Results")) {
        close("Results");
    }
    if (isOpen(baseName + "-Branchinfo.csv")) {
        close(baseName + "-Branchinfo.csv");
    }
    if (isOpen("Log")) {
        close("Log");
    }
    if (isOpen("ROI Manager")) {
        close("ROI Manager");
    }
}

print("Batch skeleton analysis complete.");