/*
 * This is the source code for the Void Whizzard.
 * 
 * Author: Steven Royal Oakes (soakes@wisc.edu)
 * 
 * Version: v1.3
 * 
 * Date: 2018/01/19
 */

macro "Void Whizzard v1.3"{
	VSAtypes = newArray("Ultraviolet", "Ninhydrin");

	Dialog.create("Void Whizzard (v1.3) Settings");
	Dialog.addString("Spot Size: ", "0-infinity", 12);
	Dialog.addString("Circularity: ", "0-1", 12);
	Dialog.addString("Bins: ", "0-0.1-0.25-0.5-1-2-3-4", 12);
	Dialog.addNumber("% Offset Center: ", 30, 0, 6, "%");
	Dialog.addNumber("% Offset Corners: ", 5, 0, 6, "%");
	Dialog.addCheckbox("Convert pixels to area", true);
	Dialog.addCheckbox("Convert area to volume", true);
	Dialog.addNumber("Width: ", 27.6225, 3, 12, "");
	Dialog.addNumber("Height: ", 16.1925, 3, 12, "");
	Dialog.addString("Area Units: ", "cm", 12);
	Dialog.addString("Volume Units: ", "uL", 12);
	Dialog.addChoice("Type of VSA:", VSAtypes, "Ultraviolet");
	//Dialog.addCheckbox("Verbose", false);
	
	Dialog.show();
	
	size = Dialog.getString();
	dash = indexOf(size, "-");
	//TODO: Add some more checks.
	if (dash == -1){
		exit("Invalid Spot Size.");
	} else {
		size_d = substring(size, 0, dash);
		size_u = substring(size, dash + 1);
	}

	circ = Dialog.getString();
	dash = indexOf(circ, "-");
	dasho = -1;
	if (dash == -1){
		exit("Invalid Circularity.");
	} else {
		circ_d = substring(circ, 0, dash);
		circ_u = substring(circ, dash + 1);
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

	convertPixel = Dialog.getCheckbox();	// Convert pixels to area
	convertVolume = Dialog.getCheckbox();	// Convert the area to volume

	paperWidth  = Dialog.getNumber();
	paperHeight = Dialog.getNumber();
	paperUnits  = Dialog.getString();
	paperUnitsV = Dialog.getString();

	if (!convertVolume && !convertPixel){
		paperUnits = "pixel";
	}

	//verbose = Dialog.getCheckbox();
	verbose = false;
	precropped = true;

	// Debugging
	if (verbose){
		print("Upper Size Limit: " + size_u);
		print("Lower Size Limit: " + size_d);
	
		print("Upper Circularity Limit: " + circ_u);
		print("Lower Circularity Limit: " + circ_d);

		print("% Offset of Center: " + centOff);
		print("% Offset of Corners: " + cornOff);

		Array.print(bins);

		print("Convert pixels to Units: " + convertVolume);
	}
	volu = "";	// Volume units
	areau = "";	// Area units
	volb = newArray(1);
	areab = newArray(1);

	type_choice = Dialog.getChoice();

	start_time = getTime(); // Time how long the macro takes to execute.
	
	setBatchMode(true);
	run("Set Measurements...", "area mean standard min centroid center perimeter bounding fit shape display redirect=None decimal=4");
	
	//Open Images
	inDir = getDirectory("Choose Input Directory");	// The directory that holds the input images.
	imglist = getFileList(inDir);				// The list of files in the inDir.

	// Check if the conv.txt file exists.
	if (!File.exists(inDir + File.separator + "conv.txt") && convertVolume){
		exit("Error: If \"Convert area to volume\" is selected then a conv.txt file must be placed in the input directory.");
	}

	if (!precropped){
		houghDir = inDir + "hough" + File.separator;	// The directory where the hough transforms will be saved.
		cropDir = inDir + "cropped" + File.separator;	// The directory where the cropped images will be saved.
		binDir = inDir + "binary" + File.separator;
		if (!File.exists(houghDir)){
			File.makeDirectory(houghDir);
		}

		if (!File.exists(cropDir)){
			File.makeDirectory(cropDir);
		}
	
		if (!File.exists(binDir)){
			File.makeDirectory(binDir);
		}

		// Check to see if the inDir contains the file used to convert urine spots to real units
		convDir = inDir + File.separator + "conv.txt";
		if (convertVolume){
			if (!File.exists(convDir)){
				exit("Convert was selected but no conv.txt file was found in the in the selected directory.");
			} 
		}

		// Isolate the largest spot from the image.
		j = 0;
		for (i = 0; i < imglist.length; i++){
			curr_img = imglist[i];
			if (endsWith(curr_img, "TIF") || endsWith(curr_img, "tif") || endsWith(curr_img, "png")){
				run("Bio-Formats Importer", "open=[" + inDir + File.separator + curr_img + "] color_mode=Default open_files rois_import=[ROI manager] view=[Standard ImageJ] stack_order=Default");
				preprocess(curr_img);
				isolateLargestSpot(curr_img);
				run("Select None");
				run("Fill Holes");
				run("Outline");
				run("Options...", "iterations=2 count=1 black do=Dilate");
				run("Select None"); // TODO Can This be removed?
				saveAs("PNG", houghDir + "bin" + j + ".png");
				selectWindow("bin" + j + ".png");
				run("Close");
				j++;
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
				if (isOpen("Console")){
					selectWindow("Console");
					run("Close");
				}
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
				if (verbose){
					print("bin" + j + " Index: " + intsec_idxs[j]);	 // Debugging
					print("bin" + j + " Length: " + intsec_lens[j]); // Debugging
				}
				j++;
			}
		}

		for (i = 0; i < imglist.length; i++){
			curr_img = imglist[i];
			k = 0;
			if (endsWith(curr_img, "TIF") || endsWith(curr_img, "tif") || endsWith(curr_img, "png")){
				run("Bio-Formats Importer", "open=[" + inDir + File.separator + curr_img + "] color_mode=Default open_files rois_import=[ROI manager] view=[Standard ImageJ] stack_order=Default");
				pts = Array.getSequence(intsec_lens[k]);
				for (j = 0; j < pts.length; j++){
					pts[j] += intsec_idxs[k];
				}

				arr = newArray(1);
				arr = getCorners(getTitle(), pts);
				if (verbose){
					Array.print(arr);
					print("---");
				}
				roiManager("Select", arr);
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
				run("Close");
				IJ.deleteRows(res_idx, nResults - 1);
				k++;
			}
		}
		//roiManager("Save", cropDir + "RoiSet.zip");
	} else {
		cropDir = inDir;
		binDir = inDir + File.separator + "binary" + File.separator;
		if (!File.exists(binDir)){
			File.makeDirectory(binDir);
		}
	}

	croplist = getFileList(cropDir);
	for (i = 0; i < croplist.length; i++){
		curr_img = croplist[i];
		if (endsWith(curr_img, "TIF") || endsWith(curr_img, "tif")){
			run("Bio-Formats Importer", "open=[" + cropDir + curr_img + "] color_mode=Default open_files rois_import=[ROI manager] view=[Standard ImageJ] stack_order=Default");
			run("16-bit");
			process(croplist[i], type_choice);
			saveAs("Tiff", binDir + curr_img);
			run("Close");
		}
	}

	a = 0;
	b = 0;
	convDir = inDir + File.separator + "conv.txt";
	
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

	convResults = false;
	if (convertVolume || convertPixel) {
		convResults = true;
	}

	initAnalysisTable("Summary");
	//initAnalysisTable("RAW");
	i = 0;
	for (t = 0; t < imglist.length; t++){ /* */
		curr_img = imglist[t];
		if (endsWith(curr_img, "TIF") || endsWith(curr_img, "tif") || endsWith(curr_img, "png")){
			//run("Bio-Formats Importer", "open=[" + binDir + File.separator + curr_img + "] color_mode=Default open_files rois_import=[ROI manager] view=[Standard ImageJ] stack_order=Default");
			open(binDir + File.separator + curr_img);
			
			c = nResults;
			run("Measure");
			if (getResult("Mean", c) == 0 || isNaN(getResult("Mean", c))){
				selectWindow("Results");
				selectWindow("Results");
				run("Close");

				totBins = newArray(bins.length);
				
				IJ.renameResults("Analysis Summary Results", "Results");

				label = getTitle();
				setResult("Label", i, label);
				setResult("Count", i, 0);	
				setResult("Total Area (" + paperUnits + "^2)", i, 0);
				if (convertVolume){
					setResult("Total Volume (" + paperUnitsV + ")", i, 0);
				}
				setResult("Percent area in center", i, 0);
				setResult("Percent area in corners", i, 0);
	
				for (j = 0; j < totBins.length - 1; j++){
					setResult(bins[j] + "--" + bins[j+1] + " " + paperUnits, i, 0);
				}
				setResult(bins[bins.length-1] + "+ " + paperUnits, i, 0);
			
				IJ.renameResults("Results", "Analysis Summary Results");
				i++;
			} else { /* */
				selectWindow("Results");
				selectWindow("Results");
				run("Close");
				
				analyzeSpots(curr_img, convResults, paperWidth, paperHeight, paperUnits);
				
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
				totBinsLength = bins.length;
				totBins = newArray(totBinsLength);
				
	
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
								if (currArea > bins[j] && currArea <= bins[j+1]){
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
					setResult("Total Volume (" + paperUnitsV + ")", i, totVolume);
				}

				if (totArea == 0){
					setResult("Percent area in center", i, 0);
					setResult("Percent area in corners", i, 0);
				} else {
					setResult("Percent area in center", i, (areaCenter / totArea) * 100);
					setResult("Percent area in corners", i, (areaCorners / totArea) * 100);
				}

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
				selectWindow(curr_img);
				selectWindow(curr_img);
				run("Close");
				i++;
			}
		}
	}

	k = 0;
	do {
		wait(1000);
		selectWindow("Analysis Summary Results");
		saveAs("Analysis Summary Results", inDir + File.separator + "Summary.csv");
		wait(1000);
		k++;
	} while (!File.exists(inDir + File.separator + "Summary.csv") && k < 4);

	// Create overlay files
	binOverFiles = getFileList(binDir);
	roist = roiManager("Count");
	for (p = 0; p < binOverFiles.length; p++){
		roist = roiManager("Count");
		open(binDir + File.separator + binOverFiles[p]);
		co = nResults;
		run("Measure");
		if (getResult("Mean", co) != 0){
			selectWindow("Results");
			selectWindow("Results");
			run("Close");
			
			saveZip = getTitle() + ".zip";
			run("Ellipse Split", "binary=[Use standard watershed] add_to_manager merge_when_relativ_overlap_larger_than_threshold overlap=95 major=0-Infinity minor=0-Infinity aspect=1-Infinity");
			
			if (roist != roiManager("Count")) {
				ovselc = roiSelect(roist, roiManager("Count"));
				roiManager("Select", ovselc);
				roiManager("Save", binDir + File.separator + saveZip);
				roiManager("Select", ovselc);
				roiManager("Delete");
			}
		} else {
			selectWindow("Results");
			selectWindow("Results");
			run("Close");
		}
	}
	
	waitForUser("Void Whizzard", "The Void Whizzard has finished executing.");
	
	setBatchMode("Exit and Display");
	
	stop_time = getTime();
	if (verbose){
		print("Time: " + (stop_time - start_time) / 1000); // Print how long it took to execute the macro.
		print("---------------------------------------------");
	}
}

/*
 * Converts a cropped image to a binary image.
 */
function process(img, type){
	selectWindow(img);
	imgID = getImageID();
	if (type == "Ninhydrin"){
		gmmVSA_N(imgID);
	} else {
		gmmVSA_UV(imgID);
	}
}

function analyzeSpots(img, convA, pWidth, pHeight, pUnits){
	cent_idx = initCenter(img, centOff);
	corn_idx = initCorners(img, cornOff);

	if (convA){
		setScale(img, pWidth, pHeight, pUnits);
	} else{
		run("Set Scale...", "distance=0 known=0 pixel=1 unit=pixel");
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
	run("8-bit");
	oldcount = roiManager("Count");
	run("Ellipse Split", "binary=[Use standard watershed] add_to_manager merge_when_relativ_overlap_larger_than_threshold overlap=95 major=0-Infinity minor=0-Infinity aspect=1-Infinity");
	newcount = roiManager("Count");

	if (newcount > oldcount){
		sels = roiSelect(e_idx, roiManager("Count"));
		roiManager("Select", sels);
		roiManager("Measure");
	
		for (i = 0; i < sels.length; i++){
			roiManager("Select", i + e_idx);
			run("Add Selection...");
		}

		IJ.renameResults("Results", "Ellipses");

		return roiManager("Count") - e_idx;
	} else {
		run("Measure");
		IJ.deleteRows(0,1);
		IJ.renameResults("Results", "Ellipses");
		return 0;
	}
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

function arraySubsample(array, s, e){
	if (s < 0 || e < 0)
		exit("Array Subsample argument less than zero.");

	if (s >= array.length || e >= array.length)
		exit("Array Subsample argument greater than array length.");

	if (e < s)
		exit("Array Subsample start greater than end.");

	retArray = newArray((e - s) + 1);

	for (i = 0; i < retArray.length; i++){
		retArray[i] = array[i + s];
	}

	return retArray;
}

function gmmVSA_UV(img){
	/* Partition indicies. */
	p1_idx = 0;
	p2_idx = 0;

	/* Partition boundaries. */
	p1l = 1000;	// Lower.
	p1u = 6000;	// Upper.
	p2l = 12000;
	p2u = 20000;

	/* Get histogram data */
	selectImage(img);

	run("Despeckle");
	run("Kuwahara Filter", "sampling=5");

	nbins = 256;
	getHistogram(values, counts, nbins);
	getStatistics(dummy, dummy, min, max);

	if (max <= 3000){
		selectImage(img);
		setThreshold(min,max);
		run("Convert to Mask");
		resetThreshold();
		run("Invert");
		run("8-bit");
		return 0;
	}

	// Ignore any saturation, if present.
	if (max == 65535){
		counts[counts.length - 1] = counts[counts.length - 2];
	}

	if (min == 0){
		counts[0] = counts[2];
	}

	/* Convert the partition boundary values into indicies. */
	p1l_idx = 0;	// Index of lower bound.
	p1u_idx = 0;	// Index of upper bound.
	p2l_idx = 0;
	p2u_idx = 0;

	p1lSET = false;	// Flags.
	p1uSET = false;
	p2lSET = false;
	p2uSET = false;

	if (p1l <= min){
		p1lSET = true;
	}

	if (p2u >= max){
		p2u_idx = nbins - 1;
		p2uSET = true;
	}

	for (i = 0; i < values.length; i++){
		if (!p1lSET && p1l <= values[i]){
			p1l_idx = i;
			p1lSET = true;
		}

		if (!p1uSET && p1u <= values[i]){
			p1u_idx = i;
			p1uSET = true;
		}

		if (!p2lSET && p2l <= values[i]){
			p2l_idx = i;
			p2lSET = true;
		}

		if (!p2uSET && p2u <= values[i]){
			p2u_idx = i;
			p2uSET = true;
		}
	}
	
	/*// Debugging
	print("Min: " + min + ", Max: " + max);
	Array.print(values);
	print("P1_Lower: " + p1l_idx + "[" + values[p1l_idx] + "]");
	print("P1_Upper: " + p1u_idx + "[" + values[p1u_idx] + "]");
	print("P2_Lower: " + p2l_idx + "[" + values[p2l_idx] + "]");
	print("P2_Upper: " + p2u_idx + "[" + values[p2u_idx] + "]");
	*/

	minError = 99999999999;
	minErr1 = 0;
	minErr2 = 0;
	minErr3 = 0;
	p1min = newArray(1);
	p2min = newArray(1);
	p3min = newArray(1);
	p1min_idx = 0;
	p2min_idx = 0;
	for (p1_idx = p1l_idx; p1_idx <= p1u_idx; p1_idx++){
		for (p2_idx = p2l_idx; p2_idx <= p2u_idx; p2_idx++){
			p1 = fitGaussian(counts, 0, p1_idx);
			p2 = fitGaussian(counts, p1_idx, p2_idx);
			p3 = fitGaussian(counts, p2_idx, 255);

			err1 = calcError(counts, p1[0], p1[1], p1[2]);
			err2 = calcError(counts, p2[0], p2[1], p2[2]);
			err3 = calcError(counts, p3[0], p3[1], p3[2]);
			totErr = err1 + err2 + err3;
			if (totErr < minError){
				minErr = totErr;
				minErr1 = err1;
				minErr2 = err2;
				minErr3 = err3;

				p1min = Array.copy(p1);
				p2min = Array.copy(p2);
				p3min = Array.copy(p3);

				p1min_idx = p1_idx;
				p2min_idx = p2_idx;
			}
		}
	}

	/*
	print("P1: " + p1min_idx + "[" + values[p1min_idx] + "]" + ", P2: " + p2min_idx + "[" + values[p2min_idx] + "]");
	print("");
	print("Max: " + p1min[0] + ", Mu: " + p1min[1] + ", Variance: " + p1min[2]);
	print("Max: " + p2min[0] + ", Mu: " + p2min[1] + ", Variance: " + p2min[2]);
	print("Max: " + p3min[0] + ", Mu: " + p3min[1] + ", Variance: " + p3min[2]);
	*/
	gy1 = newArray(256);
	for (i = 0; i < 256; i++){
		gy1[i] = gamma(p1min[0], p1min[1], p1min[2], i);
	}

	gy2 = newArray(256);
	for (i = 0; i < 256; i++){
		gy2[i] = gamma(p2min[0], p2min[1], p2min[2], i);
	}

	gy3 = newArray(256);
	for (i = 0; i < 256; i++){
		gy3[i] = gamma(p3min[0], p3min[1], p3min[2], i);
	}
	/*
	Plot.create("Histogram", "Pixel Value", "Count");
	Plot.setColor("black");
	Plot.add("line", values, counts);
	Plot.setLimitsToFit();
	Plot.setColor("blue");
	Plot.add("line", values, gy1);
	Plot.setColor("green");
	Plot.add("line", values, gy2);
	Plot.setColor("red");
	Plot.add("line", values, gy3);
	Plot.show();
	*/

	thresh = calcThreshold(p2min[0], p2min[1], p2min[2], p3min[0], p3min[1], p3min[2]);
	//print("Threshold: " + thresh);

	selectImage(img);
	setThreshold(values[thresh],65535);
	run("Convert to Mask");
	resetThreshold();
	//print("---------------");

	return minError;
}

function gmmVSA_N(img){
	/* Partition index. */
	p_idx = 0;

	/* Partition boundary. */
	pl = 2000;
	pu = 16000;

	/* Get histogram data */
	selectImage(img);

	run("Despeckle");
	run("Kuwahara Filter", "sampling=5");

	nbins = 256;
	getHistogram(values, counts, nbins);
	getStatistics(dummy, dummy, min, max);

	if (max <= 3000){
		selectImage(img);
		setThreshold(min,max);
		run("Convert to Mask");
		resetThreshold();
		run("Invert");
		run("8-bit");
		return 0;
	}

	// Ignore any saturation, if present.
	if (max == 65535){
		counts[counts.length - 1] = counts[counts.length - 2];
	}

	if (min == 0){
		counts[0] = counts[2];
	}

	/* Convert the partition boundary values into indicies. */
	pl_idx = 0;	// Index of lower bound.
	pu_idx = 0;	// Index of upper bound.

	plSET = false;	// Flags.
	puSET = false;

	if (pl <= min){
		plSET = true;
	}
	
	if (pu >= max){
		pu_idx = nbins - 1;
		puSET = true;
	}

	for (i = 0; i < values.length; i++){
		if (!plSET && pl <= values[i]){
			pl_idx = i;
			plSET = true;
		}

		if (!puSET && pu <= values[i]){
			pu_idx = i;
			puSET = true;
		}
	}
	/*
	print("Min: " + min + ", Max: " + max);
	Array.print(values);
	print("P1_Lower: " + pl_idx + "[" + values[pl_idx] + "]");
	print("P1_Upper: " + pu_idx + "[" + values[pu_idx] + "]");
	*/

	minError = 9999999999999;
	minErr1 = 0;
	minErr2 = 0;
	p1min = newArray(1);
	p2min = newArray(1);
	pmin_idx = 0;
	for (p_idx = pl_idx; p_idx <= pu_idx; p_idx++){
		p1 = fitGaussian(counts, 0, p_idx);
		p2 = fitGaussian(counts, p_idx, 255);
		
		err1 = calcError(counts, p1[0], p1[1], p1[2]);
		err2 = calcError(counts, p2[0], p2[1], p2[2]);
		
		totErr = err1 + err2;
		if (totErr < minError){
			minError = totErr;
			
			minErr1 = err1;
			minErr2 = err2;
			
			p1min = Array.copy(p1);
			p2min = Array.copy(p2);
			
			pmin_idx = p_idx;
		}
	}

	/*
	print("P: " + pmin_idx + "[" + values[pmin_idx] + "]");
	print("");
	print("Max: " + p1min[0] + ", Mu: " + p1min[1] + ", Variance: " + p1min[2]);
	print("Max: " + p2min[0] + ", Mu: " + p2min[1] + ", Variance: " + p2min[2]);
	*/
	
	gy1 = newArray(256);
	for (i = 0; i < 256; i++){
		gy1[i] = gamma(p1min[0], p1min[1], p1min[2], i);
	}

	gy2 = newArray(256);
	for (i = 0; i < 256; i++){
		gy2[i] = gamma(p2min[0], p2min[1], p2min[2], i);
	}

	/*
	Plot.create("Histogram", "Pixel Value", "Count");
	Plot.setColor("black");
	Plot.add("line", values, counts);
	Plot.setLimitsToFit();
	Plot.setColor("blue");
	Plot.add("line", values, gy1);
	Plot.setColor("green");
	Plot.add("line", values, gy2);
	*/

	thresh = calcThreshold(p1min[0], p1min[1], p1min[2], p2min[0], p2min[1], p2min[2]);
	//print("Threshold: " + thresh);

	selectImage(img);
	setThreshold(values[thresh],65535);
	run("Convert to Mask");
	resetThreshold();
	//print("---------------");

	return minError;
}

function fitGaussian(y, s, e){
	mu = 0;
	sigma = 0;
	max = 0;
	cardinal = 0;
	variance = 0;

	for (i = s; i <= e; i++){
		cardinal += y[i];
		mu += i*y[i];
	}

	if (cardinal == 0){
		mu = 0;
		sigma = 0;
	} else {
		mu /= cardinal;
		mu = round(mu);
	}

	if (mu != 0){
		for (i = s; i < e; i++){
			sigma += y[i]*pow(i - mu, 2);
		}
		sigma /= cardinal;
		
		idx = mu;
		sum = y[idx];
		num = 1;
		if (idx - 1 >= 0){
			sum += y[idx-1];
			num++;
		}
		if (idx + 1 <= 255){
			sum += y[idx+1];
			num++;
		}
		max = sum/num;

		variance = 2*sigma;
	}

	ret = newArray(max, mu, variance);

	return ret;
}

function gamma(max, mu, variance, x){
	if (variance == 0){
		return 0;
	}
	return (max * exp(-(pow(x - mu, 2))/variance));
}

function calcError(count, max, mu, variance){
	error = 0;

	for (i = 0; i < 256; i++){
		error += pow(gamma(max, mu, variance, i) - count[i], 2);
	}

	return error / 256;
}

function calcThreshold(max1, mu1, var1, max2, mu2, var2){
	minErr = 99999999;
	threshold = 0;

	for (i = mu1; i < mu2; i++){
		val = pow(gamma(max1, mu1, var1, i) - gamma(max2, mu2, var2, i), 2);
		if (minErr > val){
			minErr = val;
			threshold = i;
		}
	}
	return threshold;
}
