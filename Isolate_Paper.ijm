macro "Isolate Paper"{
	start_time = getTime(); // Time how long the macro takes to execute.
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
			run("Select None");
			saveAs("PNG", houghDir + "bin" + i + ".png");
			selectWindow("bin" + i + ".png");
			run("Close");
		}
	}

	houghlist = getFileList(houghDir);	// The images to be transformed.
	thetaAxisSize = "720";
	radiusAxisSize = "720";
	minContrast = "30";

	// Transform the binary images
	for (i = 0; i < houghlist.length; i++){
		if (startsWith(houghlist[i], "bin")) {
			in  = houghDir + houghlist[i];
			num = substring(replace(houghlist[i], ".png", ""), 3);
			out = houghDir + "hough" + num + ".png";
			//print(houghlist[i] + " -> hough" + num); // Debugging
			call("mouse.HoughTransform.main", in, out, thetaAxisSize, radiusAxisSize, minContrast);
		}
	}

	intsec_idxs = newArray(houghlist.length);	// The indices of the intersection points for each image.
	intsec_lens = newArray(houghlist.length);	// The number of intersection points for each image.

	// Process the hough images
	for (i = 0; i < houghlist.length; i++){
		temp_idx = processHough(houghDir + "bin" + i + ".png", houghDir + "hough" + i + ".png");
		intsec_idxs[i] = temp_idx;
		intsec_lens[i] = roiManager("Count") - temp_idx;
		print("bin" + i + " Index: " + intsec_idxs[i]);	 // Debugging
		print("bin" + i + " Length: " + intsec_lens[i]); // Debugging
	}
		
	setBatchMode("Exit and Display");
	
	stop_time = getTime();
	print("Time: " + (stop_time - start_time) / 1000); // Print how long it took to execute the macro.
	print("---------------------------------------------");
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
 * This function accepts the path to a hough transform of an image, and returns the intersections
 * of the lines derived from the input hough transform. The intersections are saved as point selections 
 * in the roiManager and the index of the first intersection is returned.
 * 
 * bin - path to binary image
 * hough - path to hough transform image.
 */
function processHough(bin, hough){ //TODO FIX
	open(hough);
	thetaAxisSize = getWidth();
	rAxisSize = getHeight();
	open(bin);
	width = getWidth();
	height = getHeight();
	hypotenuse = sqrt((width*width) + (height*height));
	selectWindow(File.getName(hough));
	run("8-bit"); // Convert RGB to 8-bit.
	run("Find Maxima...", "noise=30 output=[Point Selection]");
	res_idx = nResults; // The index of the first result in the result table.
	run("Measure");

	rPos = newArray(nResults - res_idx);
	tPos = newArray(nResults - res_idx);
	for (i = 0; i < tPos.length; i++){
		rPos[i] = (getResult("Y", i + res_idx) - (rAxisSize / 2)) * hypotenuse / (rAxisSize / 2);
		tPos[i] = getResult("X", i + res_idx) * (180)/thetaAxisSize;
	}

	xPos = newArray(tPos.length); // The corresponding x value to the r and theta values.
	yPos = newArray(tPos.length); // The corresponding y value to the r and theta values.
	aPos = newArray(tPos.length); // The angle of the line passing through (xPos, yPos).

	// Calculate (x, y) and angle for each point on the hough transform.
	for (i = 0; i < tPos.length; i++){
		xPos[i] = (-1) * rPos[i] * cos((PI/180) * tPos[i]);
		yPos[i] = 600 + (rPos[i] * sin((PI/180) * tPos[i]));
		aPos[i] = ((-1) * ((PI/2) - (PI/180) * (tPos[i])));
	}

	//Debugging
	//for (i = 0; i < tPos.length; i++){
	//	print("(" + xPos[i] + ", " + yPos[i] + ") -> " + "(" + tPos[i] + ", " + rPos[i] + ")");
	//	print(aPos[i] * (180/PI));
	//}

	d = 15;							// Arbitrary constant used to detect intersections. Must be greater than 1.
	// TODO Find better way to size the arrays.
	xSec = newArray(150);	// The x value of the intersection points.
	ySec = newArray(150); 	// The y value of the intersection points.
	n = 0;							// The number of intersections for this hough transform.
	
	for (i = 0; i < xPos.length; i++){
		for (j = i + 1; j < yPos.length; j++){
			dx1 = d * cos(aPos[i]);
			dy1 = -1 * d * sin(aPos[i]);
			dx2 = d * cos(aPos[j]);
			dy2 = -1 * d * sin(aPos[j]);
			val = findIntersection(xPos[i], yPos[i], xPos[i] + dx1, yPos[i] + dy1, xPos[j], yPos[j], xPos[j] + dx2, yPos[j] + dy2);
			if (!isNaN(val)){
				xSec[n] = val[0];
				ySec[n] = val[1];
				n++;
			}
		}
	}

	selectWindow(File.getName(bin));

	ret_idx = roiManager("Count"); // The start of the intersections of the current paper.
	ret_count = 0;

	for (i = 0; i < n; i++){
		//print(File.getName(bin) + "-" + i + " (" + xSec[i] + ", " + ySec[i] + ")"); // Debugging
		if (xSec[i] < width && xSec[i] > 0 && ySec[i] < height && ySec[i] > 0){
			makePoint(xSec[i], ySec[i]);
			roiManager("Add");
			roiManager("Select", ret_idx + ret_count);
			roiManager("Rename", File.getName(bin) + "-" + i);
			ret_count++;
		}
	}

	IJ.deleteRows(res_idx, nResults - 1);

	selectWindow(File.getName(hough));
	run("Close");

 	return ret_idx;
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

/*
 * This function finds the intersection of two lines given the endpoints.
 * 
 * x1, y1, x2, y2 - Line 1
 * x3, y3, x4, y4 - Line 2
 * 
 * Returns an array containing the intersection [x, y].
 */
function findIntersection(x1, y1, x2, y2, x3, y3, x4, y4){
	x12 = x1 - x2;
	x34 = x3 - x4;
	y12 = y1 - y2;
	y34 = y3 - y4;
	
	c = (x12 * y34) - (y12 * x34);
	
	if (abs(c) < 0.1) {
		// No intersection
		return NaN;
	} else {
		// Intersection
		a = (x1 * y2) - (y1 * x2);
		b = (x3 * y4) - (y3 * x4);
		
		x = ((a * x34) - (b * x12)) / c;
		y = ((a * y34) - (b * y12)) / c;
		
		return newArray(x, y);
	}
}