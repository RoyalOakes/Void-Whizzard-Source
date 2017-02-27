macro "Medial Axis Transform"{
	setBatchMode(true);

	MAT_st_time = getTime();

	run("Set Measurements...", "area mean standard min perimeter shape redirect=None decimal=3");
	run("Set Scale...", "distance=0 known=0 pixel=1 unit=pixel global");
	
	orig_name = getTitle();
	run("Select None");

	makeDistanceMap(orig_name);
	makeBoundaryMap(orig_name);
	makeVoronoi(orig_name);

	selectWindow("Voronoi");
	setThreshold(1, 255);
	run("Convert to Mask");

	//pruneBranches("Voronoi", "Distance");

	imageCalculator("AND create", "Voronoi","Distance");
	setThreshold(1, 255);
	run("Convert to Mask");

	selectWindow("Voronoi");
	run("Close");
	selectWindow("Result of Voronoi");
	rename("MAT");
	

	MAT_en_time = getTime();
	print(((MAT_en_time - MAT_st_time) / 1000) + " sec.");
	
	setBatchMode("exit and display");
}

/* 
 * Creates an image containing the distance map from bin_name.
 */
function makeDistanceMap(bin_name){
	selectWindow(bin_name);
	run("Duplicate...", "title=Distance");
	run("Distance Map");
	run("Select None");
}

/*
 * Creates an image containing the boundaries of bin_name
 */
function makeBoundaryMap(bin_name){
	selectWindow(bin_name);
	run("Duplicate...", "title=Boundary");
	run("Outline");
	run("Select None");
}

/*
 * Creates an image containing the internal vornoi diagrams of all spots within an image.
 * 
 * Each spot is isolated from the image and stored in 'Voronoi_t'. The selections 
 * are interpolated and a voronoi diagram is computed for the selection. The 
 * edges of the voronoi that are outside the selection are trimmed, and the edges
 * within the selection are transfered to 'Voronoi.' Spots with perimeter less 
 * than 50 pixels are converted into ultimate points.
 *
 */
function makeVoronoi(bin_name){
	st_idx = nResults;
	selectWindow(bin_name);
	newImage("Voronoi", "8-bit black", getWidth(), getHeight(), 1);

	selectWindow(bin_name);
	run("Find Maxima...", "noise=0 output=[Point Selection]");
	run("Measure");
	circ_idx = nResults;
	for (i = 0; i < circ_idx - st_idx; i++){
		newImage("Voronoi_t", "8-bit black", getWidth(), getHeight(), 1);

		selectWindow(bin_name);
		doWand(getResult("X", st_idx + i), getResult("Y", st_idx + i));
		selectWindow("Voronoi_t");
		run("Restore Selection");
		run("Measure");
		if ((getResult("Circ.", circ_idx + i) < 0.73)){
			run("Interpolate", "interval=5 adjust");
			getSelectionCoordinates(x, y);
			for (j = 0; j < x.length; j++){
				setPixel(x[j], y[j], 255);
			}
			run("Voronoi");

			run("Make Inverse");
			run("Cut");
			run("Select None");
		} else {
			setForegroundColor(255, 255, 255);
			run("Fill", "slice");
			run("Ultimate Points");	
		}

		imageCalculator("OR create", "Voronoi","Voronoi_t");

		selectWindow("Voronoi_t");
		run("Close");

		selectWindow("Voronoi");
		run("Close");

		selectWindow("Result of Voronoi");
		rename("Voronoi");
	}
	run("Select None");

	IJ.deleteRows(st_idx, nResults - 1);
}

function pruneBranches(bin_name, dist_name){
	same = false;
	do {
		selectWindow(bin_name);
		run("Duplicate...", "title=Copy");
		pruneBranchLayer(bin_name, dist_name);
		imageCalculator("Difference create", "Copy","Voronoi");
		
		selectWindow("Result of Copy");
		cpy_idx = nResults;
		run("Measure");
		if (getResult("Mean", cpy_idx) == 0){
			same = true;
		}

		selectWindow("Copy");
		run("Close");
		selectWindow("Result of Copy");
		run("Close");

		IJ.deleteRows(cpy_idx, cpy_idx);
	} while (same == false);
}

function pruneBranchLayer(bin_name, dist_name){
	selectWindow(bin_name);
	
	run("Duplicate...", "title=Junctions");
	
	run("Duplicate...", "title=Ends");
	run("Convolve...", "text1=[0 1 0\n1 10 1\n0 1 0\n] normalize");
	setThreshold(200, 200);
	run("Convert to Mask");

	selectWindow("Junctions");
	run("Convolve...", "text1=[0 1 0\n1 10 1\n0 1 0\n] normalize");
	setThreshold(237, 255);
	run("Convert to Mask");

	imageCalculator("XOR create", bin_name,"Junctions");
	rename("Branches");

	selectWindow("Ends");
	st_idx = nResults;
	run("Find Maxima...", "noise=0 output=[Point Selection]");
	run("Measure");

	selectWindow("Ends");
	run("Close");

	selectWindow("Branches");
	run("Duplicate...", "title=Branches-1");
	imageCalculator("AND create", "Branches-1", dist_name);

	selectWindow("Branches-1");
	run("Close");
	selectWindow("Result of Branches-1");
	rename("Weighted Branches");
	
	setForegroundColor(0, 0, 0);
	count = nResults;
	for (i = 0; i < count - st_idx; i++){
		selectWindow("Branches");
		doWand(getResult("X", i + st_idx), getResult("Y", i + st_idx), 0.0, "4-connected");
		selectWindow("Weighted Branches");
		run("Restore Selection");
		run("Measure");
		if ((getResult("StdDev", nResults - 1) / getResult("Area", nResults - 1)) > 0.20){
			selectWindow("Branches");
			run("Fill", "slice");
		}
	}

	IJ.deleteRows(st_idx, nResults - 1);

	imageCalculator("OR create", "Branches","Junctions");

	selectWindow("Branches");
	run("Close");
	selectWindow("Weighted Branches");
	run("Close");
	selectWindow("Junctions");
	run("Close");
	selectWindow(bin_name);
	run("Close");

	selectWindow("Result of Branches");
	rename(bin_name);
}

/*
 * Returns the number of 4 connected neighbors a pixel has.
 */
function neighborCount_4(x, y){
	if (!is("binary")){
		exit("8-bit Binary Image Required.");
	}

	if (getPixel(x, y) == 0){
		return 0;
	}

	u = getPixel(x, y - 1);
	d = getPixel(x, y + 1);
	l = getPixel(x - 1, y);
	r = getPixel(x + 1, y);

	return (u + d + l + r) / 255;
}