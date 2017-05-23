/*
 * Accepts a binary image of a VSA and analyzes the spots.
 */
macro "Analyze_Spots"{
	img = getTitle();

	centOff = 30;
	cornOff = 5;

	cent_idx = initCenter(img, centOff);
	corn_idx = initCorners(img, cornOff);

	ell_idx = roiManager("Count");
	run("Ellipse Split", "binary=[Use standard watershed] add_to_manager merge_when_relativ_overlap_larger_than_threshold overlap=95 major=0-Infinity minor=0-Infinity aspect=1-Infinity");
	ell_num = roiManager("Count") - ell_idx;
	sels = roiSelect(ell_idx, roiManager("Count"));
	roiManager("Select", sels);
	roiManager("Measure");

	IJ.renameResults("Results", "Ellipses");

	getEllipsesCenter(cent_idx, ell_idx, ell_num);
}

function getEllipsesCenter(c_idx, e_idx, e_num){
	ce_idx = roiManager("Count");	// Index of the first center (c) ellipse (e).
	for (i = 0; i < e_num; i++){
		arr = newArray(c_idx, e_idx + i);
		roiManager("Select", arr);
		roiManager("AND");
		if (selectionType() != -1){
			roiManager("Add");
		}
	}
	selc = roiSelect(ce_idx, roiManager("Count"));
	roiManager("Select", selc);
	roiManager("Measure");
}

/*
 * Draws a box that encloses a percentage of the area in the center of an image 
 * given by an offset. 
 */
function initCenter(img, offset){
	offset = sqrt(offset * 0.01);
	idx = roiManager("Count");
	run("Select All");
	run("Scale... ", "x=" + offset + " y=" + offset + " centered");
	roiManager("Add");
	return idx;
}

/*
 * Draws four bxes that each contain a percentage of the area of an image given
 * by an offset. Each box contains the percentage of the area given by offset.
 */
function initCorners(img, offset){
	selectWindow(img);
	
	offset = sqrt(offset * 0.01);
	cornWidth = offset * getWidth();
	cornHeight = offset * getHeight();
	idx = roiManager("Count");
	
	makeRectangle(0, 0, cornWidth, cornHeight);
	roiManager("Add");
	makeRectangle(0, getHeight() - cornHeight, cornWidth, cornHeight);
	roiManager("Add");
	makeRectangle(getWidth() - cornWidth, 0, cornWidth, cornHeight);
	roiManager("Add");
	makeRectangle(getWidth() - cornWidth, getHeight() - cornHeight, cornWidth, cornHeight);
	roiManager("Add");
	
	sels = roiSelect(idx, idx + 4);
	roiManager("Select", sels);
	roiManager("Combine");
	roiManager("Add");
	roiManager("Select", sels);
	roiManager("Delete");
	
	return idx;
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