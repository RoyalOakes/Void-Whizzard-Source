/*
 * Accepts a binary image of a VSA and analyzes the spots.
 */
macro "Analyze_Spots"{
	run("Set Measurements...", "area mean standard min centroid center perimeter bounding fit shape display redirect=None decimal=4");

	size_d = "0";
	size_u = "infinity";
	circ_d = "0";
	circ_u = "infinity";
	centOff = 30;
	cornOff = 5;
	bins = newArray(0,0.5,1,1.5,2);
	convertVolume = true;
	convertArea   = true;
	paperWidth  = 10.875;
	paperHeight = 6.375;
	paperUnits  = "inch";
	volu  = "uL";

	inDir = getDirectory("Choose Input Directory");
	imglist = getFileList(inDir);
	convDir = inDir + File.separator + "conv.txt";

	setBatchMode(true);

	if (convertVolume) {
		convs = File.openAsString(convDir);
		rows = split(convs, "\n");
		if (rows.length > 3){
			exit("Invalid convert file. Too many rows.");
		}
		volb = split(rows[0], "\t");
		areab = split(rows[1], "\t");
		if (volb.length != areab.length){
			exit("Volume-Area dimension mismatch.");
		}

		volb = Array.concat(0, volb);
		areab = Array.concat(0, areab);

		for (i = 0; i < volb.length; i++){
			volb[i] = parseFloat(volb[i]);
			areab[i] = parseFloat(areab[i]);
		}

		Fit.doFit("Straight Line", areab, volb); // Form: y = a + bx;
		a = Fit.p(0);
		b = Fit.p(1);
		//print(a + ", " + b);
	}

	initAnalysisTable("Summary");
	//initAnalysisTable("RAW");
	for (i = 0; i < imglist.length; i++){
		curr_img = imglist[i];
		if (endsWith(curr_img, "TIF") || endsWith(curr_img, "tif") || endsWith(curr_img, "png")){
			open(inDir + File.separator + curr_img);
			analyzeSpots(curr_img, convertArea, paperWidth, paperHeight, paperUnits);
			
			size_u = parseFloat(size_u);
			if (isNaN(size_u)){
				size_u = 1000000000;
			}
			size_d = parseFloat(size_d);
			if (isNaN(size_d)){
				size_d = 0;
			}

			circ_u = parseFloat(size_u);
			if (isNaN(circ_u)){
				circ_u = 1000000000;
			}
			circ_d = parseFloat(size_d);
			if (isNaN(circ_d)){
				circ_d = 0;
			}

			// Measure ellipses in the entire energy
			totArea = 0;
			totVolume = 0;
			totCount = 0;
			totBins = newArray(bins.length);

			IJ.renameResults("Ellipses", "Results");
			num = nResults;
			for (j = 0; j < num; j++){
				currArea = getResult("Area", j);
				currCirc = getResult("Circ.", j);
				if ((currArea < size_u && currArea > size_d) && (currCirc < circ_u && currCirc > circ_d)){
					totArea += currArea;
					totCount++;
					if (convertVolume){
						totVolume += (a + (currArea * b));
					}
				}
			}

			for (j = 0; j < totBins.length; j++){
				for (k = 0; k < num; k++){
					currArea = getResult("Area", k);
					currCirc = getResult("Circ.", k);
					if ((currArea < size_u && currArea > size_d) && (currCirc < circ_u && currCirc > circ_d)){
						if (j < (totBins.length - 1)){
							if (currArea > bins[j] && currArea < bins[j+1]){
								totBins[j] += 1;
							}
						} else {
							if (currArea > bins[j]){
								totBins[j] += 1;
							}
						}
					}
				}
			}
			
			IJ.renameResults("Results", "Ellipses");
			

			// Measure ellipses in center.
			areaCenter = 0;
			
			IJ.renameResults("Center Ellipses", "Results");
			
			num = nResults;
			for (j = 0; j < num; j++){
				currArea = getResult("Area", j);
				currCirc = getResult("Circ.", j);
				if ((currArea < size_u && currArea > size_d) && (currCirc < circ_u && currCirc > circ_d)){
					areaCenter += currArea;
				}
			}
			IJ.renameResults("Results", "Center Ellipses");

			// Measure ellipses in corners.
			areaCorners = 0;
			
			IJ.renameResults("Corner Ellipses", "Results");
			
			num = nResults;
			for (j = 0; j < num; j++){
				currArea = getResult("Area", j);
				currCirc = getResult("Circ.", j);
				if ((currArea < size_u && currArea > size_d) && (currCirc < circ_u && currCirc > circ_d)){
					areaCorners += currArea;
				}
			}
			IJ.renameResults("Results", "Corner Ellipses");
			
			// Print Results to Summary Table.
			IJ.renameResults("Analysis Summary Results", "Results");

			label = getTitle();
			setResult("Label", i, label);
			setResult("Count", i, totCount);	
			setResult("Total Area (" + paperUnits + "^2)", i, totArea);
			if (convertVolume){
				setResult("Total Volume (" + volu + ")", i, totVolume);
			}
			setResult("Percent area in center", i, (areaCenter / totArea) * 100);
			setResult("Percent area in corners", i, (areaCorners / totArea) * 100);

			for (j = 0; j < totBins.length - 1; j++){
				setResult(bins[j] + "--" + bins[j+1] + " " + paperUnits, i, totBins[j]);
			}
			setResult(bins[bins.length-1] + "+ " + paperUnits, i, totBins[totBins.length-1]);
		
			IJ.renameResults("Results", "Analysis Summary Results");

			// Cleanup: Close windows.
			if (roiManager("Count") > 0){
				sel = roiSelect(0, roiManager("Count"));
				roiManager("Select", sel);
				roiManager("Delete");
			}
			
			selectWindow("Ellipses");
			selectWindow("Ellipses");
			run("Close");
			selectWindow("Center Ellipses");
			selectWindow("Center Ellipses");
			run("Close");
			selectWindow("Corner Ellipses");
			selectWindow("Corner Ellipses");
			run("Close");
		}
	}
	
	setBatchMode("Exit and Display");
}

function analyzePapers(dir, cv){
	
}

function analyzeSpots(img, convA, pWidth, pHeight, pUnits){
	cent_idx = initCenter(img, centOff);
	corn_idx = initCorners(img, cornOff);

	if (convA){
		setScale(img, pWidth, pHeight, pUnits);
	}

	ell_idx = roiManager("Count");
	ell_num = getEllipses(ell_idx);
	getEllipsesSelection("Center Ellipses", cent_idx, ell_idx, ell_num);
	getEllipsesSelection("Corner Ellipses", corn_idx, ell_idx, ell_num);
}

function setScale(img, pwidth, pheight, punits){
	selectWindow(img);
	width = getWidth();
	height = getHeight();
	if (width > height){
		if (pwidth > pheight){
			run("Set Scale...", "distance=" + width + " known=" + pwidth + " pixel=1 unit=" + punits);
		} else {
			run("Set Scale...", "distance=" + width + " known=" + pheight + " pixel=1 unit=" + punits);
		}
	} else {
		if (pwidth > pheight){
			run("Set Scale...", "distance=" + height + " known=" + pwidth + " pixel=1 unit=" + punits);
		} else {
			run("Set Scale...", "distance=" + height + " known=" + pheight + " pixel=1 unit=" + punits);
		}
	}
}

function initAnalysisTable(str){
	if (isOpen("Analysis " + str + " Results")){
		return;
	}

	newImage("temp", "8-bit black", 699, 430, 1);
	
	run("Set Measurements...", "  redirect=None decimal=4");
	if (isOpen("Results")){
		run("Set Measurements...", "  redirect=None decimal=4");
		run("Measure");
		run("Clear Results");
		IJ.renameResults("Results", "Analysis " + str + " Results");
		IJ.renameResults("Temp", "Results");
	} else {
		run("Measure");
		run("Clear Results");
		IJ.renameResults("Results", "Analysis " + str + " Results");
	}
	run("Set Measurements...", "area mean standard min centroid center perimeter bounding fit shape display redirect=None decimal=4");
	selectWindow("temp");
	run("Close");
}

function getEllipses(e_idx){
	run("Ellipse Split", "binary=[Use standard watershed] add_to_manager merge_when_relativ_overlap_larger_than_threshold overlap=95 major=0-Infinity minor=0-Infinity aspect=1-Infinity");
	sels = roiSelect(e_idx, roiManager("Count"));
	roiManager("Select", sels);
	roiManager("Measure");

	for (i = 0; i < sels.length; i++){
		roiManager("Select", i + e_idx);
		run("Add Selection...");
	}

	IJ.renameResults("Results", "Ellipses");

	return roiManager("Count") - e_idx;
}

function getEllipsesSelection(title, c_idx, e_idx, e_num){
	ce_idx = roiManager("Count");
	for (i = 0; i < e_num; i++){
		arr = newArray(c_idx, e_idx + i);
		roiManager("Select", arr);
		roiManager("AND");
		if (selectionType() != -1){
			roiManager("Add");
		}
	}
	selc = roiSelect(ce_idx, roiManager("Count"));
	if (selc[0] < roiManager("Count")){
		roiManager("Select", selc);
		roiManager("Measure");

		roiManager("Select", selc);
		roiManager("Delete");

		IJ.renameResults("Results", title);
	} else {
		run("Measure");
		run("Clear Results");
		IJ.renameResults("Results", title);
	}
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
	cornWidth = round(offset * getWidth());
	cornHeight = round(offset * getHeight());
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
	if (start == end){
		tempArr = newArray(1);
		tempArr[0] = start;
		return tempArr;
	}
	sels = Array.getSequence(end - start);
	for (i = 0; i < sels.length; i++){
		sels[i] += start;
	}

	return sels;
}
