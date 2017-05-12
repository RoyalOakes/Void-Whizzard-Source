macro "Hull Solidity"{
	//setBatchMode(true);
	hull_idx = roiManager("Count");

	//open("F:\\Vezina Lab\\VSA\\Void Whizzard Source\\img\\VSA Papers\\hough\\bin13.png");

	pt_idx = 193;
	pt_num = 8;

	pts = Array.getSequence(pt_num);
	for (i = 0; i < pts.length; i++){
		pts[i] += pt_idx;
	}

	a = newArray(1);
	//for (j = 0; j < 2; j++){
		a = getFalseCorners(getTitle(), pts);
		print("---");
	
		for (i = 0; i < a.length; i++){
			pts = arrayRemove(pts, a[i]);
		}
	//}
	Array.print(pts);
	roiManager("Select", pts);
	roiManager("Combine");
	run("Convex Hull");
	
	//print(getHullSolidity(pts)); 
	//setBatchMode("Exit and Display");
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
function getFalseCorners(img, points){
	hs_o = getHullSolidity(img, points);	// The original hull solidity.
	hs_c = 0;						// The hull solidity of the current set of points.

	print("Original: " + hs_o);
	
	falseCorners = newArray(pts.length); // TODO Find out where pts came from.
	n = 0;
	newpts = newArray(1);
	for (i = 0; i < pts.length; i++){
		newpts = arrayRemove(points, i);
		hs_c = getHullSolidity(img, newpts);
		print("Remove " + i + ": " + hs_c);
		if (hs_c > hs_o){
			falseCorners[n] = i;
			n++;
		}
	}

	return Array.trim(falseCorners, n);
	print(n);
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
	if (pos > array.length || pos < 0){
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
