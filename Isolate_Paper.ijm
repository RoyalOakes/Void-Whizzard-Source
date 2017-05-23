macro "Isolate Paper"{
	Dialog.create("User Settings");
	Dialog.addString("Spot Size: ", "0-infinity", 12);
	Dialog.addString("Circularity: ", "0-infinity", 12);
	Dialog.addString("Bins: ", "0-50-100", 12);
	Dialog.addNumber("% Offset Center: ", 50, 0, 6, "%");
	Dialog.addNumber("% Offset Corners: ", 20, 0, 6, "%");
	Dialog.addCheckbox("Convert", false);
	Dialog.show();
	
	size = Dialog.getString();
	dash = indexOf(size, "-");
	//TODO: Add some more checks.
	if (dash == -1){
		exit("Invalid Spot Size.");
	} else {
		size_up = substring(size, 0, dash);
		size_dn = substring(size, dash + 1);
	}

	circ = Dialog.getString();
	dash = indexOf(circ, "-");
	dasho = -1;
	if (dash == -1){
		exit("Invalid Circularity.");
	} else {
		circ_up = substring(circ, 0, dash);
		circ_dn = substring(circ, dash + 1);
	}

	binss = Dialog.getString(); // Binss stands for 'bins string'
	bins = newArray(50);
	dash = indexOf(binss, "-");
	n = 0; 
	if (dash == -1){
		exit("Invalid Bins.");
	} else {
		while (dash != -1){
			bins[n++] = substring(binss, dasho + 1, dash);
			dasho = dash;
			dash = indexOf(binss, "-", dasho + 1);
		}
		bins[n] = substring(binss, dasho + 1);
	}
	bins = Array.trim(bins, n + 1);

	centOff = Dialog.getNumber();
	cornOff = Dialog.getNumber();
	
	convert = Dialog.getCheckbox();

	// Debugging
	print("Upper Size Limit: " + size_up);
	print("Lower Size Limit: " + size_dn);

	print("Upper Circularity Limit: " + circ_up);
	print("Lower Circularity Limit: " + circ_dn);

	print("% Offset of Center: " + centOff);
	print("% Offset of Corners: " + cornOff);

	Array.print(bins);

	print("Convert pixels to Units: " + convert);
	volu = "";	// Volume units
	areau = "";	// Area units
	volb = newArray(1);
	areab = newArray(1);

	start_time = getTime(); // Time how long the macro takes to execute.
	//run("ROI Manager...");	// Open ROImanager.
	
	setBatchMode(true);
	run("Set Measurements...", "area mean standard min centroid center perimeter bounding fit shape redirect=None decimal=3");
	
	//Open Images
	inDir = getDirectory("Choose Input Directory");	// The directory that holds the input images.
	imglist = getFileList(inDir);				// The list of files in the inDir.
	
	houghDir = inDir + File.separator + "hough" + File.separator;	// The directory where the hough transforms will be saved.
	cropDir = inDir + File.separator + "cropped" + File.separator;	// The directory where the cropped images will be saved.
	if (!File.exists(houghDir)){
		File.makeDirectory(houghDir);
	}

	if (!File.exists(cropDir)){
		File.makeDirectory(cropDir);
	}

	// Check to see if the inDir contains the file used to convert urine spots to real units
	convDir = inDir + File.separator + "conv.txt";
	if (convert){
		if (!File.exists(convDir)){
			exit("Convert was selected but no conv.txt file was found in the in the selected directory.");
		} 
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
			run("Select None"); // TODO Can This be removed?
			saveAs("PNG", houghDir + "bin" + i + ".png");
			selectWindow("bin" + i + ".png");
			run("Close");
		}
	}

	houghlist = getFileList(houghDir);	// The images to be transformed.
	thetaAxisSize = "400";
	radiusAxisSize = "400";
	minContrast = "30";		// Must be less than 255.

	// Transform the binary images
	for (i = 0; i < houghlist.length; i++){
		if (startsWith(houghlist[i], "bin")) {
			in  = houghDir + houghlist[i];
			num = substring(replace(houghlist[i], ".png", ""), 3);
			out = houghDir + "hough" + num + ".png";
			//print(houghlist[i] + " -> hough" + num); // Debugging
			call("HoughTransform.main", in, out, thetaAxisSize, radiusAxisSize, minContrast);
		}
	}

	houghlistnew = getFileList(houghDir); // All files

	arraylen = 0;	// Length of intsec_idxs and intsec_lens
	if (houghlist.length == houghlistnew.length){
		arraylen = houghlist.length / 2;
	} else {
		arraylen = houghlist.length;
	}

	// TODO Make sure that the arrays are not to big. (houghlist.length includes binary images.)
	intsec_idxs = newArray(arraylen);	// The indices of the intersection points for each image.
	intsec_lens = newArray(arraylen);	// The number of intersection points for each image.

	// Process the hough images. The hough images and the binary images are saved in the same directory.
	j = 0;
	for (i = 0; i < houghlistnew.length; i++){
		if (startsWith(houghlistnew[i], "hough")){
			temp_idx = processHough(houghDir + "bin" + j + ".png", houghDir + "hough" + j + ".png");
			intsec_idxs[j] = temp_idx;
			intsec_lens[j] = roiManager("Count") - temp_idx;
			print("bin" + j + " Index: " + intsec_idxs[j]);	 // Debugging
			print("bin" + j + " Length: " + intsec_lens[j]); // Debugging
			j++;
		}
	}

	for (i = 0; i < imglist.length; i++){
		curr_img = imglist[i];
		if (endsWith(curr_img, "TIF") || endsWith(curr_img, "tif") || endsWith(curr_img, "png")){
			open(inDir + "\\" + curr_img);
			pts = Array.getSequence(intsec_lens[i]);
			for (j = 0; j < pts.length; j++){
				pts[j] += intsec_idxs[i];
			}

			a = newArray(1);
			a = getCorners(getTitle(), pts);
			
			Array.print(a);
			print("---");
			roiManager("Select", a);
			roiManager("Combine");
			run("Convex Hull");

			res_idx = nResults;
			run("Measure");
			angle = getResult("Angle", res_idx);
			if (angle > 90){
				angle -= 180;
			}
			run("Select None");
			run("Rotate... ", "angle=" + angle + " grid=1 interpolation=Bicubic");
			run("Restore Selection");
			run("Rotate...", "  angle=" + angle);
			run("Crop");
			run("Select None");
			saveAs("Tiff", cropDir + curr_img);
			IJ.deleteRows(res_idx, nResults - 1);
		}
	}
	//roiManager("Save", cropDir + "RoiSet.zip");

	if (convert) {
		convs = File.openAsString(convDir);
		rows = split(convs, "\n");
		if (rows.length > 3){
			exit("Invalid convert file. Too many rows.");
		}
		units = split(rows[0], "\t");
		volu = units[0];
		areau = units[1];
		volb = split(rows[1], "\t");
		areab = split(rows[2], "\t");
		if (volb.length != areab.length){
			exit("Volume-Area dimension mismatch.");
		}

		for (i = 0; i < volb.length; i++){
			volb[i] = parseFloat(volb[i]);
			areab[i] = parseFloat(areab[i]);
		}

		Fit.doFit("Straight Line", areab, volb); // Form: y = a + bx;
		a = Fit.p(0);
		b = Fit.p(1);
	}

	//TODO Analysis goes here.
	
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
function processHough(bin, hough){ 
	open(hough);
	thetaAxisSize = getWidth();
	rAxisSize = getHeight();
	open(bin);
	width = getWidth();
	height = getHeight();
	hypotenuse = sqrt((width*width) + (height*height));
	selectWindow(File.getName(hough));
	run("8-bit"); // Convert RGB to 8-bit.
	run("Find Maxima...", "noise=25 output=[Point Selection]"); 
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

	d = 15;		// Arbitrary constant used to detect intersections. Must be greater than 1.
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
			roiManager("Rename", File.getName(bin) + "-" + i); //Debugging.
			ret_count++;
		}
	}

	IJ.deleteRows(res_idx, nResults - 1);

	selectWindow(File.getName(hough));
	run("Close");

	selectWindow(File.getName(bin));
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
	if (selectionType() != 9){ // Makes sure that the selection is a compsite selection.
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

/*
 * Determines the points on the convex hull that, when removed, increase the solidity of the
 * convex hull. These points are called false corners. This is done by iterating over all of
 * points and measuring the hull solidity when a point is removed. Any point that, when removed,
 * produces a hull solidity that is greater than the original hull solidity is returned in an
 * array.
 * 
 * points - An array of indices of points in the ROIManager that describe the convex hull.
 * 
 * Returns an array containg the positions of false corners in the given array of points.
 */
function getCorners(img, points){
	print("Fitting " + img + "[" + points.length + "]");
	if (points.length <= 4){
		print("No removal\n---");
		return points;
	}
	
	hs_o = getHullSolidity(img, points);	// The original hull solidity.
	hs_c = 0;						// The hull solidity of the current set of points.

	print("Original: " + hs_o);

	// The number of combinations of 4 unique points from points array =
	// factorial(points.length) / (factorial(4) * factorial(points.length - 4));

	minArea = 0.5 * areaFromPoints(points);
	imax = 0;
	jmax = 0;
	kmax = 0;
	lmax = 0;
	max = 0;
	for (i = 0; i < points.length - 4; i++){
		for (j = (i + 1); j < points.length - 3; j++){
			for (k = (j + 1); k < points.length - 2; k++){
				for (l = (k + 1); l < points.length - 1; l++){
					arr = newArray(points[i], points[j], points[k], points[l]);
					hs_c = getHullSolidity(img, arr);
					if (hs_c > max && areaFromPoints(arr) > minArea){
						max = hs_c;
						imax = i;
						jmax = j;
						kmax = k;
						lmax = l;
					}
				}
			}
		}
	}

	print("Max: " + max);
	
	arr = newArray(points[imax], points[jmax], points[kmax], points[lmax]);
	return arr;
}

/*
 * This function accepts an array that contains indices of points in the ROIManager. A convex 
 * hull is then constructed from the points. The best fit box of the convex hull is determined
 * and the area of the convex hull divided by the area of the best fit bounding box is returned.
 * This is value is called the "convex hull solidity" or "hull solidity" for short.
 * 
 * points - An array containing the indices of the points in the ROIManager.
 * 
 * Returns the hull solidity of the convex hull constructed from points.
 */
function getHullSolidity(img, points){
	hull_idx = roiManager("Count"); // Index of the convex hull in the roiManager.
	roiManager("Select", points);
	roiManager("Combine");
	run("Convex Hull");
	roiManager("Add");
	
	line_idx = convexHullToLines(img, hull_idx);
	line_num = roiManager("Count") - line_idx;
	hullBestFitBox(hull_idx, line_idx, line_num);

	sels = Array.getSequence(line_num);
	for (i = 0; i < sels.length; i++){
		sels[i] += line_idx;
	}
	roiManager("Select", sels);
	roiManager("Delete");

	box_idx = roiManager("Count") - 1;
	
	res_idx = nResults;
	roiManager("Select", hull_idx);
	run("Measure");
	roiManager("Select", box_idx);
	run("Measure");

	hullSolidity = getResult("Area", res_idx) / getResult("Area", res_idx + 1);
	IJ.deleteRows(res_idx, nResults - 1);

	roiManager("Select", newArray(hull_idx, box_idx));
	roiManager("Delete");

	return hullSolidity;
}

/* 
 * This function breaks up a convex hull into the lines that compose it.
 * 
 * img - The name of the image that the convex hull was contructed on. 
 * con_idx - The index of the convex hull in the ROIManager.
 * 
 * Returns the index to the first line in the roiManager.
 */
function convexHullToLines(img, con_idx){
	selectWindow(img);
	roiManager("Select", con_idx);
	getSelectionCoordinates(x, y);	// Get the points that define the convex hull.

	// This adds the value at position 0 to the end of the array. This is done facilitate the
	// construction of the lines later on.
	x = Array.concat(x, x[0]);
	y = Array.concat(y, y[0]);

	ret_idx = roiManager("Count");

	// Make the lines and add them to the ROIManager.
	for (i = 0; i < x.length - 1; i++){
		makeLine(x[i], y[i], x[i + 1], y[i + 1]);
		roiManager("Add");
		run("Restore Selection");
	}

	return ret_idx;
}

/*
 * Fits a box with the smallest possible area that circumscribes the given convex hull. This is
 * done by breaking the convex hull into its component lines. The angle between each line and
 * the x axis of the image is measured. Then the convex hull is rotated to each of these angles.
 * Then the area of the bounding box of the rotated convex hull is measured. The rotation that
 * gives the bounding box with the smallest area is kept. Then the selection of the smallest
 * bounding box is returned.
 * 
 * hull_idx - The index of the convex hull in the ROIManager.
 * line_idx - The index of the first line that makes up the convex hull in the ROIManager.
 * line_num - The number of lines in the ROIManager that make up the convex hull.
 * 
 * Returns the best fit bounding box in the ROIManager.
 */
function hullBestFitBox(hull_idx, line_idx, line_num){
	res_idx = nResults;
	angles = newArray(line_num); // Array containing the angels of each line.

	// Get the angles of the lines.
	for (i = 0; i < line_num; i++){
		roiManager("Select", line_idx + i);
		run("Measure");
		angles[i] = getResult("Angle", res_idx + i);
	}

	IJ.deleteRows(res_idx, nResults - 1);

	// Select the smallest box.
	min = 2147483647;
	minBox = 0;
	for (i = 0; i < angles.length; i++){
		roiManager("Select", hull_idx);
		run("Rotate...", "  angle=" + angles[i]);
		run("To Bounding Box");
		run("Measure");
		curr_area = getResult("Area", i + res_idx);
		if (curr_area < min){
			min = curr_area;
			minBox = i;
		}
	}

	IJ.deleteRows(res_idx, nResults - 1);

	// Reconstruct the smallest bounding box and add it to the ROIManager.
	roiManager("Select", hull_idx);
	run("Rotate...", "  angle=" + angles[minBox]);
	run("To Bounding Box");
	run("Rotate...", "  angle=" + (-1 * angles[minBox]));
	roiManager("Add");
}

/*
 * Creates an aray that can be used to select roi's in the roimanager.
 * 
 * Returns an array containing the indices of the roi's in the roimanager to be selected.
 */
function roiSelect(start, end){
	sels = Array.getSequence(end - start);
	for (i = 0; i < sels.length; i++){
		sels[i] += start;
	}

	return sels;
}

/*
 * Creates a new array from the given array that is missing the value at the given position.
 */
function arrayRemove(array, pos){
	if (pos >= array.length || pos < 0){
		return NaN;
	}

	retArray = newArray(array.length - 1);
	n = 0;
	for (i = 0; i < array.length; i++){
		if (i != pos){
			retArray[n] = array[i];
			n++;
		}
	}

	return retArray;
}

/*
 * Given a set of indices that point to point selections in the ROImanager
 * caluculates the area that is contained by the convex hull of those points.
 * Assumes that there is an image open. 
 */
function areaFromPoints(points){
	roiManager("Select", points);
	roiManager("Combine");
	run("Convex Hull");
	res_idx = nResults;
	run("Measure");
	area = getResult("Area", res_idx);
	IJ.deleteRows(res_idx, nResults - 1);
	run("Select None");
	return area;
}
