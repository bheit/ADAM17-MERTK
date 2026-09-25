// Script to move diffusion tracks from a black background to white background.
// Script simply replaces black [0,0,0] with white [255,255,255] in RGB images.
// Bryan Heit, September 2026


orig = getTitle();
// Build a mask of pure-black pixels from a duplicate
run("Duplicate...", "title=black_mask");
run("8-bit");
setThreshold(0, 0);
setOption("BlackBackground", true);
run("Convert to Mask");
run("Create Selection");
close(); // close the mask image, selection carries over

// Apply the selection to the original and fill with white
selectWindow(orig);
run("Restore Selection");
setColor(255, 255, 255);
fill();
run("Select None");