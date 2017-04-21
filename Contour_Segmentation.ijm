macro "Contour_Segmentation"{
	img = getTitle();	// Title of binary image.
	width = getWidth();
	height = getHeight();
	newImage("Temp", "8-bit black", width, height, 1);

	selectWindow(img);
	run("Select None");
	run("Find Maxima...", "noise=10 output=[Point Selection]");
	res_idx = nResults;
	run("Measure");
	for (i = 0; i < nResults - res_idx; i++){
		selectWindow(img);
		doWand(getResult("X", i + res_idx), getResult("Y", i + res_idx));
		
		run("Interpolate", "interval=5 smooth adjust");
		getSelectionCoordinates(x, y);
		con = concavity(x, y);
		Array.print(con);
		Array.getStatistics(con, dummy, max, dummy, dummy);
		print(max);
		selectWindow("Temp");
		for (j = 0; j < con.length; j++){
			setPixel(x[j], y[j], (con[j]/max) * 255);
		}
	}

	IJ.deleteRows(res_idx, nResults - 1);
}

function concavity(x, y){
	infin = 1.0/0.0;
	concav = newArray(x.length);
	xp = Array.concat(x[x.length-1], x, x[0]);
	yp = Array.concat(y[y.length-1], y, y[0]);
	for (i = 1; i < x.length + 1; i++){
		apre = atan((round(yp[i-1]) - round(yp[i]))/(xp[i-1] - xp[i]));
		anex = atan((yp[i+1] - yp[i])/(xp[i+1] - xp[i]));
		if (abs(apre - anex) < PI){
			concav[i-1] = abs(apre - anex);
		} else {
			concav[i] = PI - abs(apre - anex);
		}
	}
	return concav;
}

/*
 * Draws the points that make up a ROI. The ROI is interpolated by the given distance.
 */
function drawSelectionPoints(dist){
	run("Interpolate", "interval=" + dist + " smooth adjust");
	getSelectionCoordinates(x, y);
	makeSelection("points", x, y);
	setForegroundColor(255, 255, 255);
	run("Draw", "slice");
	run("Select None");
	for (i = 0; i < x.length; i++){
		print("(" + x[i] + ", " + y[i] + ")");
	}
}
