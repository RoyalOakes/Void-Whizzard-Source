macro "Segment Particles"{
	setBatchMode(true);

	if (!is("binary")){
		exit("Requires Binary Image.");
	}

	// Variable declaration.
	binName = getTitle(); 	// The title of the original image.
	RAD_INT = 3;		// The interval the radius will decrease by when growing/seeding blobs.
	RAD_MIN = 4;		// The smallest radius that will be used.
	MAX_SPOT_IN_BLOB = 50;	// The maximum number of spots that can be within a blob.
	MIN_SEED_AREA    = 2;	// The minimum area a possible new spot must have to be considered a new spot.
	MIN_ERODE_DIST   = 11;	// The minimum value of the ultimate point of a spot for it to be eroded.
	ERODE_COEFF      = 0.95;	// The coefficent applied to derive the number of pixels eroded from the selection.
	CUT_MAP_DIST     = 0.2;	// The distance from the watershed cuts that the cut map will be at.
	ROI_SAVE = "C:\\Users\\Steven\\Desktop\\roizip.zip";	// Where the spots will be saved.

	startTime = getTime();	// Starts the timer.

	run("Set Measurements...", "area mean redirect=None decimal=3");
	run("Set Scale...", "distance=0 known=0 pixel=1 unit=pixel global");
	run("Select None");

	// Create a selection of all the binary objects in the image. This is done
	// by finding the maxima of the image and using the ROI manager and the 
	// doWand tool to save the slections of the objects.
	run("Find Maxima...", "noise=10 output=List");
	numBlobs = nResults;
	for (i = 0; i < numBlobs; i++){
		doWand(getResult("X", i), getResult("Y", i));
		roiManager("Add");
		roiManager("Select", i);
		roiManager("Rename", "Blob-" + (i + 1));
	}
	run("Select None");

	// Close the results window from the find maxima during the find blob step.
	selectWindow("Results");
	run("Close");

	// Create a distance map of the binary image. The distance map will be
	// used to determine the radius of the embedded circles.
	run("Duplicate...", "title=Distance_Map.tif"); 
	run("Distance Map");

	// Create an array to track the number of spots in each blob.
	numSpotsInBlob = newArray(numBlobs);
	for (i = 0; i < numBlobs; i++){
		numSpotsInBlob[i] = 0;
	}
	totalSpotNum = 0; // The total number of spots in an image. 

	// Split the blobs.
	prevSpotNum = 0;
	print("  ----- Segmenting Blobs -----  ");
	for (n = 0; n < numBlobs; n++){
		if (n > 0){
			prevSpotNum += numSpotsInBlob[n - 1];
		}
		
		print("Blob: " + (n + 1));
		selectWindow("Distance_Map.tif");
		roiManager("Select", n);
		run("Find Maxima...", "noise=0 output=[Point Selection]");	// Find the absolute maxima.
		run("Measure");
		
		radius = getResult("Mean", 0);	// The initial radius is the value of the absolute maxima.
		
		IJ.deleteRows(0, nResults - 1);

		// Create two new arrays to hold the starting positions of the spots within a blob.
		xPos = newArray(MAX_SPOT_IN_BLOB);
		yPos = newArray(MAX_SPOT_IN_BLOB);

		for (r = radius; r >= RAD_MIN; r = r - RAD_INT){
			print("    Radius: " + r);	//!
			selectWindow("Distance_Map.tif");
			run("Duplicate...", "title=Temp.tif");	// Duplicate the distance map so it may be modified.

			selectWindow("Temp.tif");
			setThreshold(0, r - 1);		// Threshold the distance map
			run("Convert to Mask");		
			run("Invert");
			run("Watershed");			// Split overlapping areas.
			run("Ultimate Points");		// Find the positions of the blobs.
			roiManager("Select", n);
			run("Find Maxima...", "noise=0 output=[Point Selection]");	// Get a point selection of the blobs.
			run("Undo");				// Get the binary image back.
			run("Measure");
			// Detects if a new spot needs to be seeded.
			if (nResults > numSpotsInBlob[n]){	// If there are more maxima than spots, see if they can be added.
				print("        Additional maxima detected.");
				newSpots = findNewSpots(xPos, yPos, numSpotsInBlob[n]);	// Detect new spots.
				for (i = 0; i < newSpots.length; i++){	// Iterate over all the new spots and see if they can be added.
					if (newSpots[i] == 0){
						doWand(getResult("X", i), getResult("Y", i));
						st_idx = nResults;
						run("Measure");
						if (getResult("Area", st_idx) > MIN_SEED_AREA){	//If the possible new spot has a great enough area, add it.
							print("            Added spot.");
							IJ.deleteRows(st_idx, nResults - 1);
							xPos[numSpotsInBlob[n]] = getResult("X", i);
							yPos[numSpotsInBlob[n]] = getResult("Y", i);
							roiManager("Add");
							roiManager("Select", numBlobs + totalSpotNum);
							roiManager("Rename", "Blob-" + (n + 1) + ", Spot-" + (numSpotsInBlob[n] + 1));
							numSpotsInBlob[n]++;
							totalSpotNum++;
							run("Restore Selection");
						} else {	// Else do nothing.
							print("            Ignored.");
							IJ.deleteRows(st_idx, nResults - 1); 
						}
					}
				}
			}

			// Calculate the order the spots will be grown, and the indexes in the ROI manager. 
			growOrder = matchPointToSpot(xPos, yPos, numSpotsInBlob[n]);

			// Grow the blobs.
			selectWindow("Temp.tif");
			run("Close");
			selectWindow("Distance_Map.tif");
			cutMap(r - 1, CUT_MAP_DIST);

			idx = roiManager("Count");
			for (i = 0; i < numSpotsInBlob[n]; i++){
				doWand(xPos[i], yPos[i]);	// Select the area that will be grown.
				roiManager("Add");
			}
			
			run("Ultimate Points");
			delSel = newArray(numSpotsInBlob[n]);
			st_idx = nResults;

			for (i = 0; i < numSpotsInBlob[n]; i++){
				print("        Growing Spot: " + (i + 1));
				curr = idx + growOrder[i];
				roiManager("Select", curr);
				run("Find Maxima...", "noise=0 output=[Point Selection]");
				run("Measure");
				mean = getResult("Mean", st_idx + i);
				run("Restore Selection");
				if (mean > MIN_ERODE_DIST){
					print("            Eroding selection by " + round(ERODE_COEFF * (r/radius) * mean) + " pixels.");
					erodeDilate(round(ERODE_COEFF * (r/radius) * mean));
				}
				print("            Index: " + (numBlobs + prevSpotNum + growOrder[i]));
				print("                numBlobs: " + numBlobs);
				print("                prevSpotNum: " + prevSpotNum);
				print("                growOrder[i]: " + growOrder[i]);
				
				growEmbeddedCirclesFromSelection(r - 1, numBlobs + prevSpotNum + growOrder[i]);	// Grow the blobs.
				delSel[i] = curr;
			}

			IJ.deleteRows(st_idx, nResults - 1);
			
			run("Undo");
			if (delSel.length > 0){
				print("        Deleting selections: " + delSel[0] + "-" + delSel[delSel.length - 1]);
				roiManager("Select", delSel);
				roiManager("Delete");
			}

			selectWindow("Cut Distance Map");
			run("Close");
			
			IJ.deleteRows(0, nResults - 1);
		}
	}

	// Close the distance map.
	selectWindow("Distance_Map.tif");
	run("Close");

	selectWindow("Results");
	run("Close");

	// Open the Blobs in the ROI Manager
	roiManager("Save", ROI_SAVE);
	setBatchMode("exit and display");
	roiManager("Open", ROI_SAVE);

	// Print the time it took to process the image.
	endTime = getTime();
	print("Time taken: " + ((endTime - startTime) / 1000));
}

/*
 * Makes a Circle from the given centroid and radius
 */
function makeCircleFromCentroid(x, y, r){
	makeOval(x - r, y - r, 2*r, 2*r);
}

/*
 * Makes several circles from a selection and a radius. Assumes the selection is already
 * selected. curr is the index of the spot being added to.
 */
function growEmbeddedCirclesFromSelection(r, curr){
	if (selectionType == -1){
		print("No Selection present for 'makeEmbededCirclesFromSelection'");
		exit();
	}
	
	circIndex = roiManager("Count"); // The index of where the first circle will be.
	if (Roi.getProperty("Area") > 5){
		run("Interpolate", "interval=3");
	}
	getSelectionCoordinates(xCoordinates, yCoordinates);
	
	//Makes lots of circles on the boundary of the selection.
	for (i = 0; i < xCoordinates.length; i++){
		makeCircleFromCentroid(xCoordinates[i], yCoordinates[i], r);
		roiManager("Add");
	}

	// Creates an array holding the indexes of all the circles created prior to this.
	roiIndexes = newArray(xCoordinates.length);
	for (i = 0; i < xCoordinates.length; i++){
		roiIndexes[i] = circIndex + i;
	}

	roiManager("Select", roiIndexes); // Selects all the circles
	roiManager("Combine");  // Combines all the circles
	roiManager("Add");      // Adds the amalgamation of circles to the ROIManager
	roiManager("Delete");   // Deletes all the circles. Causes console to appear. 
	roiManager("Select", newArray(curr, circIndex));
	roiManager("Combine");  // Combines the amalgamation and the curr.
	roiManager("Update");   // Updates the curr to the new selection.
	roiManager("Deselect"); 
	roiManager("Select", circIndex);
	roiManager("Delete");   // Deletes the amalgamation.
}

/*
 * This function erodes and dilates a selection by a given number of pixels.
 */
function erodeDilate(val){
	run("Enlarge...", "enlarge=-" + val);
	run("Enlarge...", "enlarge=" + val);
}

/*
 * Given a measured point selection this function returns an array holding the order the points
 * should be added to the selections.
 */
function matchPointToSpot(xPos, yPos, num){
	order = newArray(num);
	
	for (i = 0; i < nResults; i++){
		max = 2147483647;
		for (j = 0; j < num; j++){
			dist = euclidDist(getResult("X", i), getResult("Y", i), xPos[j], yPos[j]);
			if (dist < max){
				max = dist;
				order[i] = j;
			}
		}
	}
	return order;
}

/*
 * Given a point selection and the positions of existing spots, this function 
 * determines the positions of new spots.
 */
function findNewSpots(xPos, yPos, num){
	order = newArray(nResults);

	for (i = 0; i < num; i++){
		for (j = 0; j < nResults; j++){
			dist = euclidDist(xPos[i], yPos[i], getResult("X", j), getResult("Y", j));
			if (dist < 5.6568){
				order[j] = 1;
			}
		}
	}
	return order;
}

/*
 * Returns the euclidean distance between two points 
 */
function euclidDist(x1, y1, x2, y2){
	return sqrt(pow(x1 - x2, 2) + pow(y1 - y2, 2));
}

function cutMap(threshold, distance){
	run("Duplicate...", "title=Temp");
	setThreshold(0, threshold);
	run("Convert to Mask");	
	run("Invert");
	run("Duplicate...", "title=Water");
	run("Watershed");

	/*
	stidx = roiManager("Count");
	run("Find Maxima...", "noise=0 output=[Point Selection]");
	getSelectionCoordinates(xPos, yPos);
	selec = newArray(xPos.length);
	for (i = 0; i < xPos.length; i++){
		doWand(xPos[i], yPos[i]);
		roiManager("Add");
		selec[i] = stidx + i;
	}
	*/
	
	imageCalculator("XOR create", "Temp","Water");
	selectWindow("Result of Temp");
	run("Invert");
	run("Distance Map");
	imageCalculator("AND create", "Result of Temp","Temp");
	selectWindow("Result of Result of Temp");
	rename("Cut Distance Map");

	selectWindow("Result of Temp");
	run("Close");
	selectWindow("Temp");
	run("Close");
	selectWindow("Water");
	run("Close");

	selectWindow("Cut Distance Map");
	setThreshold(0, threshold * distance);
	run("Convert to Mask");	
	run("Invert");
}