/*
 * Accepts a binary image of a VSA and analyzes the spots.
 */
macro "Analyze_Spots"{
	img = getTitle();

	centOff = 50;
	cornOff = 25;

	centOff *= 0.01;
	cent_idx = roiManager("Count");
	run("Select All");
	run("Scale... ", "x=" + centOff + " y=" + centOff + " centered");
	roiManager("Add");

	cornOff *= 0.01;
	cornWidth = cornOff * getWidth();
	cornHeight = cornOff * getHeight();
	corn_idx = roiManager("Count");
	makeRectangle(0, 0, cornWidth, cornHeight);
	roiManager("Add");
	makeRectangle(0, getHeight() - cornHeight, cornWidth, cornHeight);
	roiManager("Add");
	makeRectangle(getWidth() - cornWidth, 0, cornWidth, cornHeight);
	roiManager("Add");
	makeRectangle(getWidth() - cornWidth, getHeight() - cornHeight, cornWidth, cornHeight);
	roiManager("Add");
	sels = roiSelect(corn_idx, corn_idx + 4);
	roiManager("Select", sels);
	roiManager("Combine");
	roiManager("Add");
	roiManager("Select", sels);
	roiManager("Delete");

	ell_idx = roiManager("Count");
	run("Ellipse Split", "binary=[Use standard watershed] add_to_manager merge_when_relativ_overlap_larger_than_threshold overlap=95 major=0-Infinity minor=0-Infinity aspect=1-Infinity");
	sels = roiSelect(ell_idx, roiManager("Count"));
	roiManager("Select", sels);
	roiManager("Measure");

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