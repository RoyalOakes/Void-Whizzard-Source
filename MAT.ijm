/*
 * Creates a Medial Axis Transform of a binary image using a voroni diagram.
 */
macro "Medial Axis Transform"{
	img = getTitle();
	makeVoronoi(img);
}

function makeVoronoi(img){
	selectWindow(img);
	newImage("Voronoi", "8-bit black", getWidth(), getHeight(), 1);
	newImage("Temp", "8-bit black", getWidth(), getHeight(), 1);

	selectWindow(img);
	res_idx = nResults;
	run("Find Maxima...", "noise=10 output=[Point Selection]");
	run("Measure");
	run("Select None");

	roi_idx = roiManager("Count");

	numSpot = nResults - res_idx;
	for (i = 0; i < numSpot; i++){
		doWand(getResult("X", res_idx + i), getResult("Y", res_idx +i));
		roiManager("Add");
	}

	for (i = 0; i < numSpot; i++){
		selectWindow("Temp");
		roiManager("Select", roi_idx + i);
		run("Interpolate", "interval=3 adjust");
		getSelectionCoordinates(x, y);
		makeSelection("point", x, y);
		setForegroundColor(255, 255, 255);
		run("Draw", "slice");
		roiManager("Select", roi_idx + i);
		run("Make Inverse");
	}
}
