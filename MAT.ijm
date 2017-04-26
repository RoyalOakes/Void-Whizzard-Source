/*
 * Creates a Medial Axis Transform of a binary image using a voroni diagram.
 */
macro "Medial Axis Transform"{
	run("Set Measurements...", "area mean standard min centroid center perimeter bounding fit shape feret's redirect=None decimal=3");
	
	img = getTitle();
	makeVoronoi(img, 50);
}

/*
 * Makes a composite voronoi diagram from a given image. The image is assumed to be binary. This
 * function also accepts a threshold that donotes the minimum length of the perimeter of a spot
 * for the spot to be turned into a voronoi diagram. If a spot has a perimenter that is less than
 * the threshold, the spot is converted into a single point from its centroid.
 * 
 * img - The title of the image to be processed.
 * threshold - The minimum perimeter for a spot to be turned into a vornonoi diagram.
 */
function makeVoronoi(img, threshold){
	selectWindow(img);
	width = getWidth();
	height = getHeight();
	newImage("Voronoi", "8-bit black", width, height, 1);	// The image where the composite 
															// voronoi will be stored.
	newImage("Temp", "8-bit black", width, height, 1);		// A temportary image to assist
															// with the construction of the voronoi.
	selectWindow(img);
	res_idx = nResults; // The starting index for measurments in the results table.
	run("Select None");
	run("Find Maxima...", "noise=10 output=[Point Selection]");	// Get all the spots in the image.
	run("Measure");
	run("Select None");

	roi_idx = roiManager("Count"); // The index of the selection of the first spot from the image.

	numSpot = nResults - res_idx;
	for (i = 0; i < numSpot; i++){ // Store all the spots in the roiManager.
		doWand(getResult("X", res_idx + i), getResult("Y", res_idx +i));
		roiManager("Add");
	}

	IJ.deleteRows(res_idx, nResults);

	// Make voronoi diagrams of all the spots above the perimenter threshold.
	for (i = 0; i < numSpot; i++){
		selectWindow("Temp");
		roiManager("Select", roi_idx + i);
		run("Measure");

		if (getResult("Perim.", res_idx + i) > threshold){	// Voronoi
			run("Interpolate", "interval=3 adjust");
			getSelectionCoordinates(x, y);
			makeSelection("point", x, y);
			setForegroundColor(255, 255, 255);
			run("Draw", "slice");
			setThreshold(1, 255);
			run("Convert to Mask");
			run("Voronoi");
			roiManager("Select", roi_idx + i);
			run("Copy");

			setForegroundColor(0, 0, 0);
			makeRectangle(0, 0, width, height);
			run("Fill", "slice");

			selectWindow("Voronoi");
			roiManager("Select", roi_idx + i);
			run("Paste");
		} else {	// Centroid
			makePoint(getResult("X", res_idx + i), getResult("Y", res_idx + i));
			setForegroundColor(255, 255, 255);
			run("Draw", "slice");
			setThreshold(1, 255);
			run("Convert to Mask");
			roiManager("Select", roi_idx + i);
			run("Copy");

			setForegroundColor(0, 0, 0);
			makeRectangle(0, 0, width, height);
			run("Fill", "slice");

			selectWindow("Voronoi");
			roiManager("Select", roi_idx + i);
			run("Paste");
		}
	}

	// Make the voronoi diagram binary.
	selectWindow("Voronoi");
	setThreshold(1, 255);
	run("Convert to Mask");

	IJ.deleteRows(res_idx, nResults);

	// Delete the temporary window.
	selectWindow("Temp");
	run("Close");

	// Delete the selections in the roiManger.
	sels = newArray(1);
	sels = roiSelect(roi_idx, roiManager("Count"));
	roiManager("Select", sels);
	roiManager("Delete");
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

function pruneBranchLayer(bin_name, dist_name){
	selectWindow(bin_name);
	
	run("Duplicate...", "title=Junctions");
	
	run("Duplicate...", "title=Ends");
	run("Convolve...", "text1=[0 1 0\n1 10 1\n0 1 0\n] normalize");
	setThreshold(200, 200);
	run("Convert to Mask");

	selectWindow("Junctions");
	run("Convolve...", "text1=[0 1 0\n1 10 1\n0 1 0\n] normalize");
	setThreshold(237, 255);
	run("Convert to Mask");

	imageCalculator("XOR create", bin_name,"Junctions");
	rename("Branches");

	/*
	selectWindow("Ends");
	st_idx = nResults;
	run("Find Maxima...", "noise=0 output=[Point Selection]");
	run("Measure");

	selectWindow("Ends");
	run("Close");

	selectWindow("Branches");
	run("Duplicate...", "title=Branches-1");
	imageCalculator("AND create", "Branches-1", dist_name);

	selectWindow("Branches-1");
	run("Close");
	selectWindow("Result of Branches-1");
	rename("Weighted Branches");
	
	setForegroundColor(0, 0, 0);
	count = nResults;
	for (i = 0; i < count - st_idx; i++){
		selectWindow("Branches");
		doWand(getResult("X", i + st_idx), getResult("Y", i + st_idx), 0.0, "4-connected");
		selectWindow("Weighted Branches");
		run("Restore Selection");
		run("Measure");
		if ((getResult("StdDev", nResults - 1) / getResult("Area", nResults - 1)) > 0.20){
			selectWindow("Branches");
			run("Fill", "slice");
		}
	}

	IJ.deleteRows(st_idx, nResults - 1);

	imageCalculator("OR create", "Branches","Junctions");

	selectWindow("Branches");
	run("Close");
	selectWindow("Weighted Branches");
	run("Close");
	selectWindow("Junctions");
	run("Close");
	selectWindow(bin_name);
	run("Close");

	selectWindow("Result of Branches");
	rename(bin_name);
	*/
}