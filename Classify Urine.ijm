var rect_x = 0;	// X-position of center.
var rect_y = 0;	// Y-position of center.
var rect_r = 0; // The aspect ratio of the rectangle (width/height).
var rect_d = 0; // The distance between a corner and the center of the rectangle (rads).
var rect_a = 0; // Angle between the principle axis of the rectangle
				//   and the x-axis of the image (rads).
var rect_corners  = newArray(4);
var rect_outliers = newArray(1, 1, 1, 1);


macro "Classify Urine"{
	setBatchMode(true);
	run("Set Measurements...", "area mean standard min centroid center perimeter bounding fit shape redirect=None decimal=3");
	
	//Open Images
	inDir = getDirectory("Choose a Directory");
	imglist = getFileList(inDir);

	for (i = 0; i < imglist.length; i++){
		curr_img = imglist[i];
		if (endsWith(curr_img, "TIF") || endsWith(curr_img, "tif")){
			open(inDir + "\\" + curr_img);
			preprocess(curr_img);
			fitrect(curr_img, 1.65);
		}
	}
	setBatchMode("Exit and Display");
}

function findOutliers(threshold){
	sum = 0;
	for (i = 0; i < 4; i++){
		sum += rect_outliers[i];
	}

	if (sum <= 2){
		return;
	}

	array_sort = Array.copy(rect_corners);
	Array.sort(array_sort);
	
	for (i = 0; i < 4; i++){
		if (abs(rect_corners[i] - array_sort[3]) > threshold){
			rect_outliers[i] = 0;
		}
	}
}

function fitrect(img, ar){
	selectWindow(img);
	run("Select None");
	run("Duplicate...", "title=temp");
	run("Fill Holes");
	res_idx = nResults;
	run("Measure");
	doWand(getResult("XM", res_idx), getResult("YM", res_idx));
	run("To Bounding Box");
	run("Select None");
	run("Gaussian Blur...", "sigma=5 slice");
	run("Restore Selection");
	run("Measure");
	
	xc = getResult("BX", res_idx + 1) + (getResult("Width", res_idx + 1) / 2); 
	yc = getResult("BY", res_idx + 1) + (getResult("Height", res_idx + 1) / 2);
	IJ.deleteRows(res_idx, nResults - 1);
	
	/* Initial rectangle properties */
	rect_init(xc, yc, ar, 100, 0);
	COARCE_GROWTH = 30;
	FINE_GROWTH = 3;
	FINE_ROTATE = 0.5 * (3.14 / 180);
	
	selectWindow("temp");
	rect_update_corners(70, 70);
	rect_adj_size(200, COARCE_GROWTH, 15);
	rect_adj_size(200, FINE_GROWTH, 15);
	rect_adj_angle(FINE_ROTATE, 10);
	rect_adj_angle((-1) * FINE_ROTATE, 10);

	//rect_adj_location(2, 0, 10);
	//rect_adj_location(2, 0, 10);
	
	selectWindow("temp");
	run("Close");
	selectWindow(img);
	rect_select();
}

function isolateLargestSpot(img){
	man_idx = roiManager("Count");
	setThreshold(254,255);
	run("Create Selection");
	resetThreshold();
	roiManager("Add");
	roiManager("Select", man_idx);
	if (selectionType() != 9){
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

function rect_adj_angle(rot, threshold){
	c_avg = rect_avg_corners();

	do {
		c_avg_old = c_avg;
		rect_rotate(rot);
		rect_update_corners(70, 70);
		findOutliers(threshold);
		c_avg = rect_avg_corners();
	} while (c_avg >= c_avg_old);

	rect_rotate((-1) * rot);
}

function rect_adj_location(dx, dy, threshold){
	c_avg_o = rect_avg_corners();
	c_avg = 0;

	x_o = rect_x;
	y_o = rect_y;

	do {
		rect_axis_translate(dx, dy);
		findOutliers(threshold);
		c_avg = rect_avg_corners();
	} while (c_avg >= c_avg_o);

	rect_set_position(((rect_x - x_o) + x_o) / 2, ((rect_y - y_o) + y_o) / 2);
}

function rect_adj_size(ideal, grow, threshold){
	c_avg = rect_avg_corners();
	diff = c_avg - ideal;

	do {
		rect_enlarge(grow);
		rect_update_corners(70, 70);
		findOutliers(threshold);
		c_avg = rect_avg_corners();
		diff = c_avg - ideal;
	} while (diff >= 0);

	rect_enlarge((-1) * grow);
}

function rect_avg_corners(){
	sum = 0;
	num = 0;
	for (i = 0; i < 4; i++){
		sum += rect_outliers[i] * rect_corners[i];
		num += rect_outliers[i];
	}
	return sum / num;
}

function rect_enlarge(dist){
	rect_d += dist;
}

function rect_init(x, y, ar, dist, ang){
	rect_x = x;
	rect_y = y;
	rect_r = ar;
	rect_d = dist;
	rect_a = ang;
}

function rect_measure(){
	rect_select();
	run("Measure");
}

function rect_update_corners(width, height){
	box_x = newArray(4);
	box_y = newArray(4);
	ret = newArray(4);
	phi = atan(1/rect_r);
	idx = nResults;
	
	box_x[0] = rect_x + (rect_d * cos(phi + rect_a));
	box_y[0] = rect_y - (rect_d * sin(phi + rect_a));
	box_x[1] = box_x[0] - (width * cos(rect_a));
	box_y[1] = box_y[0] + (width * sin(rect_a));
	box_x[2] = box_x[1] + (height * sin(rect_a));
	box_y[2] = box_y[1] + (height * cos(rect_a));
	box_x[3] = box_x[2] + (width * cos(rect_a));
	box_y[3] = box_y[2] - (width * sin(rect_a));

	makeSelection("polygon", box_x, box_y);
	run("Measure");
	rect_corners[0] = getResult("Mean", idx);

	box_x[0] = rect_x + (rect_d * cos(phi - rect_a));
	box_y[0] = rect_y + (rect_d * sin(phi - rect_a));
	box_x[1] = box_x[0] - (height * sin(rect_a));
	box_y[1] = box_y[0] - (height * cos(rect_a));
	box_x[2] = box_x[1] - (width * cos(rect_a));
	box_y[2] = box_y[1] + (width * sin(rect_a));
	box_x[3] = box_x[2] + (height * sin(rect_a));
	box_y[3] = box_y[2] + (height * cos(rect_a));

	makeSelection("polygon", box_x, box_y);
	run("Measure");
	rect_corners[1] = getResult("Mean", idx + 1);

	box_x[0] = rect_x - (rect_d * cos(phi + rect_a));
	box_y[0] = rect_y + (rect_d * sin(phi + rect_a));
	box_x[1] = box_x[0] - (height * sin(rect_a));
	box_y[1] = box_y[0] - (height * cos(rect_a));
	box_x[2] = box_x[1] + (width * cos(rect_a));
	box_y[2] = box_y[1] - (width * sin(rect_a));
	box_x[3] = box_x[2] + (height * sin(rect_a));
	box_y[3] = box_y[2] + (height * cos(rect_a));

	makeSelection("polygon", box_x, box_y);
	run("Measure");
	rect_corners[2] = getResult("Mean", idx + 2);
	
	box_x[0] = rect_x - (rect_d * cos(phi - rect_a));
	box_y[0] = rect_y - (rect_d * sin(phi - rect_a));
	box_x[1] = box_x[0] + (height * sin(rect_a));
	box_y[1] = box_y[0] + (height * cos(rect_a));
	box_x[2] = box_x[1] + (width * cos(rect_a));
	box_y[2] = box_y[1] - (width * sin(rect_a));
	box_x[3] = box_x[2] - (height * sin(rect_a));
	box_y[3] = box_y[2] - (height * cos(rect_a));

	makeSelection("polygon", box_x, box_y);
	run("Measure");
	rect_corners[3] = getResult("Mean", idx + 3);
	
	IJ.deleteRows(idx, nResults - 1);
}

function rect_rotate(ang){
	rect_a += ang;
}

function rect_select(){
	phi = atan(1/rect_r);
	x1 = rect_x + (rect_d * cos(phi + rect_a));
	y1 = rect_y - (rect_d * sin(phi + rect_a));
	x2 = rect_x + (rect_d * cos(phi - rect_a));
	y2 = rect_y + (rect_d * sin(phi - rect_a));
	x3 = rect_x - (rect_d * cos(phi + rect_a));
	y3 = rect_y + (rect_d * sin(phi + rect_a));
	x4 = rect_x - (rect_d * cos(phi - rect_a));
	y4 = rect_y - (rect_d * sin(phi - rect_a));
	makePolygon(x1, y1, x2, y2, x3, y3, x4, y4);
}

function rect_set_position(x, y){
	rect_x = x;
	rect_y = y;
}

function rect_translate(dx, dy){
	rext_x += dx;
	rect_y += dy;
}

function rect_axis_translate(dx, dy){
	rect_x += (dx * cos(rect_a)) + (dy * sin(rect_a));
	rect_y += ((-1) * dx * sin(rect_a)) + (dy * cos(rect_a));
}
