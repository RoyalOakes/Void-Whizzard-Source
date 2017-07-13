macro "VSA_GMM"{
	img = getImageID();
	gmmVSA2(img);
}

function gmmVSA1(){
	
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
	
	// Debugging
	print("Min: " + min + ", Max: " + max);
	Array.print(values);
	print("P1_Lower: " + p1l_idx + "[" + values[p1l_idx] + "]");
	print("P1_Upper: " + p1u_idx + "[" + values[p1u_idx] + "]");
	print("P2_Lower: " + p2l_idx + "[" + values[p2l_idx] + "]");
	print("P2_Upper: " + p2u_idx + "[" + values[p2u_idx] + "]");
	

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

			if (g1Err == 1){
				g1Err = 0;
			}
			
			if (g2Err == 1){
				g2Err = 0;
			}
			
			if (g3Err == 1 || g3Err >= 0.9){
				g3Err = 0;
			}

			totError = (0.10 * g1Err) + (0.45 * g2Err) + (0.45 * g3Err);
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

			showProgress(curr_idx++, end_idx);
		}
	}

	print("Total Error: " + maxError);
	print("P1: " + values[p1max_idx] + ", P2: " + values[p2max_idx]);
	print("Gaussian Error: " + g1MinErr + ", " + g2MinErr + ", " + g3MinErr);
	print("----------------------------------------------------------------");
	
	Fit.doFit(21, x1max, y1max);
	gy1 = newArray(nbins);	//gaussian y
	for (i = 0; i < nbins; i++){
		gy1[i] = Fit.f(values[i]);
	}

	Fit.doFit(21, x2max, y2max);
	gy2 = newArray(nbins);	//gaussian y
	for (i = 0; i < nbins; i++){
		gy2[i] = Fit.f(values[i]);
	}

	Fit.doFit(21, x3max, y3max);
	gy3 = newArray(nbins);	//gaussian y
	for (i = 0; i < nbins; i++){
		gy3[i] = Fit.f(values[i]);
	}

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
	

	selectImage(img);
	setThreshold(values[p2max_idx],65535);
	run("Convert to Mask");
	resetThreshold();
	
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