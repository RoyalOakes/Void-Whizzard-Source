macro "Isolate Paper"{
	setBatchMode(true);
	run("Set Measurements...", "area mean standard min centroid center perimeter bounding fit shape redirect=None decimal=3");
	
	//Open Images
	inDir = getDirectory("Choose a Directory");	// The directory that holds the input images.
	imglist = getFileList(inDir);				// The list of files in the inDir.
	houghDir = inDir + "\hough\\";				// The directory where the hough transforms will be saved.
	cropDir = inDir + "\cropped\\";				// The directory where the cropped images will be saved.
	if (!File.exists(houghDir)){
		File.makeDirectory(houghDir);
	}

	if (!File.exists(cropDir)){
		File.makeDirectory(cropDir);
	}

	// Isolate the largest spot from the image.
	for (i = 0; i < imglist.length; i++){
		curr_img = imglist[i];
		if (endsWith(curr_img, "TIF") || endsWith(curr_img, "tif") || endsWith(curr_img, "png")){
			open(inDir + "\\" + curr_img);
			preprocess(curr_img);
			isolateLargestSpot(curr_img);
			run("Select None");
			run("Fill Holes");
			run("Outline");
			run("Options...", "iterations=2 count=1 black do=Dilate");
			saveAs("PNG", houghDir + "bin" + i + ".png");
			run("Close");
		}
	}
	setBatchMode("Exit and Display");
}

/*
 * Creates a binary mask of the paper in an image. The image is first processed to remove noise and
 * to make the edges of the paper more defined.
 * 
 * 
 * Assumes the paper is ligher than the background.
 */
function preprocess(img){
	selectWindow(img);
	run("Despeckle");
	run("Kuwahara Filter", "sampling=5");
	run("Subtract Background...", "rolling=50 sliding");
	setAutoThreshold("Triangle dark");
	setOption("BlackBackground", true);
	run("Convert to Mask");
	resetThreshold();
}

/*
 * Given a binary image, this function will find the largest spot in an image and return an image containing only
 * the largest spot.
 */
function isolateLargestSpot(img){
	man_idx = roiManager("Count");
	setThreshold(254,255);
	run("Create Selection");
	resetThreshold();
	roiManager("Add");
	roiManager("Select", man_idx);
	if (selectionType() != 9){
		roiManager("Delete");
		roiManager("Deselect");
		return;
	}
	roiManager("Split");
	roiManager("Select", man_idx);
	roiManager("Delete");

	num = roiManager("Count") - man_idx;
	sels = Array.getSequence(roiManager("Count"));
	sels = Array.slice(sels, man_idx);
	roiManager("Select", sels);
	res_idx = nResults;
	roiManager("Measure");

	max = 0;
	lgst_idx = 0;
	for (i = 0; i < num; i++){
		area = getResult("Area", i + res_idx);
		if (area > max){
			lgst_idx = i + man_idx;
			max = area;
		}
	}

	roiManager("Select", lgst_idx);
	run("Make Inverse");
	setForegroundColor(0, 0, 0);
	run("Fill", "slice");

	roiManager("Select", sels);
	roiManager("Delete");
	roiManager("Deselect");

	IJ.deleteRows(res_idx, nResults - 1);
}