macro "Hough_Transform"{
	input = File.openDialog("Select Image"); 	// Image to be transformed.
	inDir = File.getParent(input);				// The directory where the input image is saved.
	inImg = File.getName(input);				// The name of the input image.
	output = File.openDialog("Select Save"); 	// Where the transform is to be saved.
	outDir = File.getParent(output);			// The directory where the transform is saved.
	outImg = File.getName(output);				// The name of the transform file.

	start_time = getTime(); // Time how long the macro takes to execute.
	setBatchMode(true);

	// Declare variables.
	thetaAxisSize = "720";
	radiusAxisSize = "720";
	minContrast = "30";

	// Do the transform. Images must be PNG.
	call("mouse.HoughTransform.main", input, output, thetaAxisSize, radiusAxisSize, minContrast);

	// Open the input image.
	open(input);
	selectWindow(inImg);
	width = getWidth();
	height = getHeight();
	
	// Parse varialbes to int.
	tAxisSize = parseInt(thetaAxisSize);
	rAxisSize = parseInt(radiusAxisSize);

	// Process the Hough Transform.
	hough_idx = processHough(output, width, height);
	
	setBatchMode("exit and display");
	stop_time = getTime();
	print("Time: " + (stop_time - start_time) / 1000); // Print how long it took to execute the macro.
	print("---------------------------------------------");
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
 * This function accepts the path to a hough transform of an image, and returns the intersections
 * of the lines derived from the input hough transform. The intersections are saved as point selections 
 * in the roiManager and the index of the first intersection is returned.
 * 
 * input - the path to the hough transform.
 * width - the width of the original image.
 * height - the height of the original image.
 */
function processHough(input, width, height){
	open(input);
	thetaAxisSize = getWidth();
	rAxisSize = getHeight();
	hypotenuse = sqrt((width*width) + (height*height));
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

	d = 10;
	xSec = newArray(50); // The x value of the intersection points.
	ySec = newArray(50); // The y value of the intersection points.
	n = 0;
	
	for (i = 0; i < xPos.length; i++){
		for (j = i + 1; j < yPos.length; j++){
			dx1 = 15 * cos(aPos[i]);
			dy1 = -15 * sin(aPos[i]);
			dx2 = 15 * cos(aPos[j]);
			dy2 = -15 * sin(aPos[j]);
			val = findIntersection(xPos[i], yPos[i], xPos[i] + dx1, yPos[i] + dy1, xPos[j], yPos[j], xPos[j] + dx2, yPos[j] + dy2);
			if (!isNaN(val)){
				xSec[n] = val[0];
				ySec[n] = val[1];
				n++;
			}
		}
	}

	ret_idx = roiManager("Count");

	for (i = 0; i < n; i++){
		//print("(" + xSec[i] + ", " + ySec[i] + ")"); // Debugging
		if (xSec[i] < width && xSec[i] > 0 && ySec[i] < height && ySec[i] > 0){
			makePoint(xSec[i], ySec[i]);
			roiManager("Add");
		}
	}

	IJ.deleteRows(res_idx, nResults - 1);

 	return ret_idx;
}
