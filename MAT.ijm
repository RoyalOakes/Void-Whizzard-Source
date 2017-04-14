/*
 * Creates a Medial Axis Transform of a binary image using a voroni diagram.
 */
macro "Medial Axis Transform"{
	run("Set Measurements...", "area mean standard min centroid center perimeter bounding fit shape feret's redirect=None decimal=3");
	
	img = getTitle();
	makeVoronoi(img, 50);
}

function makeVoronoi(img, threshold){
	selectWindow(img);
	width = getWidth();
	height = getHeight();
	newImage("Voronoi", "8-bit black", width, height, 1);
	newImage("Temp", "8-bit black", width, height, 1);

	selectWindow(img);
	res_idx = nResults;
	run("Select None");
	run("Find Maxima...", "noise=10 output=[Point Selection]");
	run("Measure");
	run("Select None");

	roi_idx = roiManager("Count");

	numSpot = nResults - res_idx;
	for (i = 0; i < numSpot; i++){
		doWand(getResult("X", res_idx + i), getResult("Y", res_idx +i));
		roiManager("Add");
	}

	IJ.deleteRows(res_idx, nResults);

	for (i = 0; i < numSpot; i++){
		selectWindow("Temp");
		roiManager("Select", roi_idx + i);
		run("Measure");
		
		if (getResult("Perim.", res_idx + i) > threshold){
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
		} else {
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

	selectWindow("Voronoi");
	setThreshold(1, 255);
	run("Convert to Mask");

	IJ.deleteRows(res_idx, nResults);
}
