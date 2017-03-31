macro "SS"{
	setBatchMode(true);
	hull_idx = roiManager("Count");

	pt_idx = 353;
	pt_num = 38;

	pts = Array.getSequence(pt_num);
	for (i = 0; i < pts.length; i++){
		pts[i] += pt_idx;
	}

	getFalseCorners(pts);
	
	//print(getHullSolidity(pts)); 
	setBatchMode("Exit and Display");
}

function getFalseCorners(points){
	newpts = newArray(1);
	for (i = 0; i < pts.length; i++){
		newpts = arrayRemove(points, i);
		print("Round " + i + ": " + getHullSolidity(newpts));
	}
}

function getHullSolidity(points){
	hull_idx = roiManager("Count"); // Index of the convex hull in the roiManager.
	roiManager("Select", points);
	roiManager("Combine");
	run("Convex Hull");
	roiManager("Add");
	
	line_idx = convexHullToLines(getTitle(), hull_idx);
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
 * Accepts a pointer to a convex hull in the ROIManager and an image. Saves the lines in the ROIManager.
 * Returns an index to the first line.
 */
function convexHullToLines(img, con_idx){
	selectWindow(img);
	roiManager("Select", con_idx);
	getSelectionCoordinates(x, y);

	x = Array.concat(x, x[0]);
	y = Array.concat(y, y[0]);

	ret_idx = roiManager("Count");

	for (i = 0; i < x.length - 1; i++){
		makeLine(x[i], y[i], x[i + 1], y[i + 1]);
		roiManager("Add");
		run("Restore Selection");
	}

	return ret_idx;
}

function hullBestFitBox(hull_idx, line_idx, line_num){
	res_idx = nResults;
	angles = newArray(line_num);
	
	for (i = 0; i < line_num; i++){
		roiManager("Select", line_idx + i);
		run("Measure");
		angles[i] = getResult("Angle", res_idx + i);
	}

	IJ.deleteRows(res_idx, nResults - 1);

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
	
	roiManager("Select", hull_idx);
	run("Rotate...", "  angle=" + angles[minBox]);
	run("To Bounding Box");
	run("Rotate...", "  angle=" + (-1 * angles[minBox]));
	roiManager("Add");
}

/*
 * Creates an aray that can be used to select roi's in the roimanager.
 * Returns an array containing the indices of the roi's in the roimanager to be selected.
 */
function roiSelect(start, end){
	sels = Array.getSequence(end - start);
	for (i = 0; i < sels.length; i++){
		sels[i] += start;
	}

	return sels;
}

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
