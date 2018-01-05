/*
 * This is the source code for the Void Whizzard.
 * 
 * Author: Steven Royal Oakes (soakes@wisc.edu)
 * 
 * Version: v1.0
 * 
 * Date: 2018/01/05
 */

macro "Void Whizzard"{
	Dialog.create("User Settings");
	Dialog.addString("Spot Size: ", "0-infinity", 12);
	Dialog.addString("Circularity: ", "0-1", 12);
	Dialog.addString("Bins: ", "0-0.1-0.25-0.5-1-2-3-4", 12);
	Dialog.addNumber("% Offset Center: ", 30, 0, 6, "%");
	Dialog.addNumber("% Offset Corners: ", 5, 0, 6, "%");
	Dialog.addCheckbox("Convert area to volume", true);
	Dialog.addMessage("If \"Convert area to volume\" is selected,\ngive the width and height of the paper in real units,\notherwise leave the boxes blank.");
	Dialog.addNumber("Width: ", 10.875, 3, 12, "");
	Dialog.addNumber("Height: ", 6.375, 3, 12, "");
	Dialog.addString("Area Units: ", "inch", 12);
	Dialog.addString("Volume Units: ", "uL", 12);
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
	
	convertVolume = Dialog.getCheckbox();	// Convert the area to volume

	paperWidth  = Dialog.getNumber();
	paperHeight = Dialog.getNumber();
	paperUnits  = Dialog.getString();
	paperUnitsV = Dialog.getString();

	if (!convertVolume){
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

	start_time = getTime(); // Time how long the macro takes to execute.
	
	setBatchMode(true);
	run("Set Measurements...", "area mean standard min centroid center perimeter bounding fit shape display redirect=None decimal=4");
	
	//Open Images
	inDir = getDirectory("Choose Input Directory");	// The directory that holds the input images.
	imglist = getFileList(inDir);				// The list of files in the inDir.

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
				open(inDir + File.separator + curr_img);
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
				open(inDir + File.separator + curr_img);
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
			open(cropDir + curr_img);
			run("16-bit");
			process(croplist[i]);
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

	initAnalysisTable("Summary");
	//initAnalysisTable("RAW");
	i = 0;
	for (t = 0; t < imglist.length; t++){
		curr_img = imglist[t];
		if (endsWith(curr_img, "TIF") || endsWith(curr_img, "tif") || endsWith(curr_img, "png")){
			open(binDir + File.separator + curr_img);

			c = nResults;
			run("Measure");
			if (getResult("Mean", c) == 0 || isNaN(getResult("Mean", c))){
				selectWindow("Results");
				selectWindow("Results");
				run("Close");
				
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
			} else {
				selectWindow("Results");
				selectWindow("Results");
				run("Close");
				analyzeSpots(curr_img, convertVolume, paperWidth, paperHeight, paperUnits);
				
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
	wait(500);
	saveAs("Analysis Summary Results", inDir + File.separator + "Summary.csv");
	wait(500);

	// Create overlay files
	binOverFiles = getFileList(binDir);
	roist = roiManager("Count");
	for (p = 0; p < binOverFiles.length; p++){
		roist = roiManager("Count");
		open(binDir + File.separator + binOverFiles[p]);
		saveZip = getTitle() + ".zip";
		run("Ellipse Split", "binary=[Use standard watershed] add_to_manager merge_when_relativ_overlap_larger_than_threshold overlap=95 major=0-Infinity minor=0-Infinity aspect=1-Infinity");
		ovselc = roiSelect(roist, roiManager("Count"));
		roiManager("Select", ovselc);
		roiManager("Save", binDir + File.separator + saveZip);
		roiManager("Select", ovselc);
		roiManager("Delete");
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
function process(img){
	selectWindow(img);
	imgID = getImageID();
	gmmVSA(imgID);
}

function gmmVSA2(img){
	/* Partition indicies. */
	p1_idx = 0;
	p2_idx = 0;

	/* Partition boundaries. */
	p1l = 1000;	// Lower.
	p1u = 6000;	// Upper.
	p2l = 12000;
	p2u = 16000; 

	/* Get histogram data */
	selectImage(img);

	run("Despeckle");
	run("Kuwahara Filter", "sampling=5");

	nbins = 256;
	getHistogram(values, counts, nbins);
	getStatistics(dummy, dummy, min, max);

	if (max <= 32768){
		selectImage(img);
		setThreshold(max,max);
		run("Convert to Mask");
		resetThreshold();
		return;
	}

	// Ignore any saturation, if present.
	if (max == 65535){
		counts[counts.length - 1] = counts[counts.length - 2];
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
	/*
	// Debugging
	print("Min: " + min + ", Max: " + max);
	Array.print(values);
	print("P1_Lower: " + p1l_idx + "[" + values[p1l_idx] + "]");
	print("P1_Upper: " + p1u_idx + "[" + values[p1u_idx] + "]");
	print("P2_Lower: " + p2l_idx + "[" + values[p2l_idx] + "]");
	print("P2_Upper: " + p2u_idx + "[" + values[p2u_idx] + "]");
	*/

	/* Fit Gaussian to partitions. */
	maxError = 0;
	totError = 0;
	g1Err = 0;	// Error of the individual gaussian curves.
	g2Err = 0;
	g3Err = 0;
	g1MinErr = 0;	// Minimum error of the individual gaussian curves.
	g2MinErr = 0;
	g3MinErr = 0;
	p1max_idx = 0;
	p2max_idx = 0;

	curr_idx = 0;
	end_idx = (p1u_idx - p1l_idx) * (p1u_idx - p1l_idx);

	for (p1_idx = p1l_idx; p1_idx <= p1u_idx; p1_idx++){
		for (p2_idx = p2l_idx; p2_idx <= p2u_idx; p2_idx++){
			y1 = arraySubsample(counts, 0, p1_idx);
			x1 = arraySubsample(values, 0, p1_idx);
			y2 = arraySubsample(counts, p1_idx, p2_idx);
			x2 = arraySubsample(values, p1_idx, p2_idx);
			y3 = arraySubsample(counts, p2_idx, counts.length - 1);
			x3 = arraySubsample(values, p2_idx, counts.length - 1);

			Fit.doFit(21, x1, y1);
			g1Err = abs(Fit.rSquared);
			Fit.doFit(21, x2, y2);
			g2Err = abs(Fit.rSquared);
			Fit.doFit(21, x3, y3);
			g3Err = abs(Fit.rSquared);

			totError = (0.10 * g1Err) + (0.70 * g2Err) + (0.20 * g3Err);
			if (totError > maxError){
				maxError = totError;
				p1max_idx = p1_idx;
				p2max_idx = p2_idx;
				g1MinErr = g1Err;
				g2MinErr = g2Err;
				g3MinErr = g3Err;

				x1max = Array.copy(x1);
				y1max = Array.copy(y1);
				x2max = Array.copy(x2);
				y2max = Array.copy(y2);
				x3max = Array.copy(x3);
				y3max = Array.copy(y3);
			}

			
		}
	}

	selectImage(img);
	setThreshold(values[p2max_idx],65535);
	run("Convert to Mask");
	resetThreshold();
	run("Options...", "iterations=5 count=7 black do=Erode");
	
	/* TODO
	selectImage(img);
	run("Duplicate...", "title=Urine");
	run("Duplicate...", "title=Paper");
	run("Duplicate...", "title=Holes");
	setThreshold(0,values[p1max_idx]);
	run("Convert to Mask");
	resetThreshold();
	selectWindow("Urine");
	setThreshold(values[p2max_idx],65535);
	run("Convert to Mask");
	resetThreshold();
	selectWindow("Paper");
	setThreshold(values[p1max_idx],values[p2max_idx]);
	run("Convert to Mask");
	resetThreshold();
	*/
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
 * This function accepts the path to a hough transform of an image, and returns the intersections
 * of the lines derived from the input hough transform. The intersections are saved as point selections 
 * in the roiManager and the index of the first intersection is returned.
 * 
 * bin - path to binary image
 * hough - path to hough transform image.
 */
function processHough(bin, hough){ 
	open(hough);
	thetaAxisSize = getWidth();
	rAxisSize = getHeight();
	open(bin);
	width = getWidth();
	height = getHeight();
	hypotenuse = sqrt((width*width) + (height*height));
	selectWindow(File.getName(hough));
	run("8-bit"); // Convert RGB to 8-bit.
	run("Find Maxima...", "noise=25 output=[Point Selection]"); 
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

	d = 15;		// Arbitrary constant used to detect intersections. Must be greater than 1.
	xSec = newArray(150);	// The x value of the intersection points.
	ySec = newArray(150); 	// The y value of the intersection points.
	n = 0;							// The number of intersections for this hough transform.
	
	for (i = 0; i < xPos.length; i++){
		for (j = i + 1; j < yPos.length; j++){
			dx1 = d * cos(aPos[i]);
			dy1 = -1 * d * sin(aPos[i]);
			dx2 = d * cos(aPos[j]);
			dy2 = -1 * d * sin(aPos[j]);
			val = findIntersection(xPos[i], yPos[i], xPos[i] + dx1, yPos[i] + dy1, xPos[j], yPos[j], xPos[j] + dx2, yPos[j] + dy2);
			if (!isNaN(val)){
				xSec[n] = val[0];
				ySec[n] = val[1];
				n++;
			}
		}
	}

	selectWindow(File.getName(bin));

	ret_idx = roiManager("Count"); // The start of the intersections of the current paper.
	ret_count = 0;

	for (i = 0; i < n; i++){
		//print(File.getName(bin) + "-" + i + " (" + xSec[i] + ", " + ySec[i] + ")"); // Debugging
		if (xSec[i] < width && xSec[i] > 0 && ySec[i] < height && ySec[i] > 0){
			makePoint(xSec[i], ySec[i]);
			roiManager("Add");
			roiManager("Select", ret_idx + ret_count);
			roiManager("Rename", File.getName(bin) + "-" + i); //Debugging.
			ret_count++;
		}
	}

	IJ.deleteRows(res_idx, nResults - 1);

	selectWindow(File.getName(hough));
	run("Close");

	selectWindow(File.getName(bin));
	run("Close");

 	return ret_idx;
}

/*
 * Given a binary image, this function will find the largest spot in an image and return an image containing only
 * the largest spot.
 */
function isolateLargestSpot(img){
	man_idx = roiManager("Count");
	setThreshold(254,255);
	run("Create Selection");
	resetThreshold();
	roiManager("Add");
	roiManager("Select", man_idx);
	if (selectionType() != 9){ // Makes sure that the selection is a compsite selection.
		roiManager("Delete");
		roiManager("Deselect");
		return;
	}
	roiManager("Split");
	roiManager("Select", man_idx);
	roiManager("Delete");

	num = roiManager("Count") - man_idx;
	sels = Array.getSequence(roiManager("Count"));
	sels = Array.slice(sels, man_idx);
	roiManager("Select", sels);
	res_idx = nResults;
	roiManager("Measure");

	max = 0;
	lgst_idx = 0;
	for (i = 0; i < num; i++){
		area = getResult("Area", i + res_idx);
		if (area > max){
			lgst_idx = i + man_idx;
			max = area;
		}
	}

	roiManager("Select", lgst_idx);
	run("Make Inverse");
	setForegroundColor(0, 0, 0);
	run("Fill", "slice");

	roiManager("Select", sels);
	roiManager("Delete");
	roiManager("Deselect");

	IJ.deleteRows(res_idx, nResults - 1);
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
function getCorners(img, points){
	if (verbose){
		print("Fitting " + img + "[" + points.length + "]");
	}
	if (points.length <= 4){
		if (verbose){
			print("No removal\n---");
		}
		return points;
	}
	
	hs_o = getHullSolidity(img, points);	// The original hull solidity.
	hs_c = 0;						// The hull solidity of the current set of points.

	if (verbose){
		print("Original: " + hs_o);
	}

	// The number of combinations of 4 unique points from points array =
	// factorial(points.length) / (factorial(4) * factorial(points.length - 4));

	minArea = 0.5 * areaFromPoints(points);
	imax = 0;
	jmax = 0;
	kmax = 0;
	lmax = 0;
	max = 0;
	for (i = 0; i < points.length - 4; i++){
		for (j = (i + 1); j < points.length - 3; j++){
			for (k = (j + 1); k < points.length - 2; k++){
				for (l = (k + 1); l < points.length - 1; l++){
					arr = newArray(points[i], points[j], points[k], points[l]);
					hs_c = getHullSolidity(img, arr);
					if (hs_c > max && areaFromPoints(arr) > minArea){
						max = hs_c;
						imax = i;
						jmax = j;
						kmax = k;
						lmax = l;
					}
				}
			}
		}
	}
	
	if (verbose){
		print("Max: " + max);
	}
	
	arr = newArray(points[imax], points[jmax], points[kmax], points[lmax]);
	return arr;
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

/*
 * Given a set of indices that point to point selections in the ROImanager
 * caluculates the area that is contained by the convex hull of those points.
 * Assumes that there is an image open. 
 */
function areaFromPoints(points){
	roiManager("Select", points);
	roiManager("Combine");
	run("Convex Hull");
	res_idx = nResults;
	run("Measure");
	area = getResult("Area", res_idx);
	IJ.deleteRows(res_idx, nResults - 1);
	run("Select None");
	return area;
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

function gmmVSA(img){
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

	if (max <= 32768){
		selectImage(img);
		setThreshold(max,max);
		run("Convert to Mask");
		resetThreshold();
		return 0;
	}

	// Ignore any saturation, if present.
	if (max == 65535){
		counts[counts.length - 1] = counts[counts.length - 2];
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
