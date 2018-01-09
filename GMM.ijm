macro "VSA_GMM"{
	img = getImageID();
	//gmmVSA_UV(img);
	gmmVSA_N(img);
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

	print("Min: " + min + ", Max: " + max);
	Array.print(values);
	print("P1_Lower: " + pl_idx + "[" + values[pl_idx] + "]");
	print("P1_Upper: " + pu_idx + "[" + values[pu_idx] + "]");

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

	print("P: " + pmin_idx + "[" + values[pmin_idx] + "]");
	print("");
	print("Max: " + p1min[0] + ", Mu: " + p1min[1] + ", Variance: " + p1min[2]);
	print("Max: " + p2min[0] + ", Mu: " + p2min[1] + ", Variance: " + p2min[2]);

	gy1 = newArray(256);
	for (i = 0; i < 256; i++){
		gy1[i] = gamma(p1min[0], p1min[1], p1min[2], i);
	}

	gy2 = newArray(256);
	for (i = 0; i < 256; i++){
		gy2[i] = gamma(p2min[0], p2min[1], p2min[2], i);
	}

	Plot.create("Histogram", "Pixel Value", "Count");
	Plot.setColor("black");
	Plot.add("line", values, counts);
	Plot.setLimitsToFit();
	Plot.setColor("blue");
	Plot.add("line", values, gy1);
	Plot.setColor("green");
	Plot.add("line", values, gy2);

	thresh = calcThreshold(p1min[0], p1min[1], p1min[2], p2min[0], p2min[1], p2min[2]);
	print("Threshold: " + thresh);

	selectImage(img);
	setThreshold(values[thresh],65535);
	run("Convert to Mask");
	resetThreshold();
	print("---------------");

	return minError;
}

function gmmVSA1(img){
	/* Partition index. */
	p_idx = 0;

	/* Partition boundary. */
	pl = 12000;
	pu = 20000;

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

	// Debugging
	print("Min: " + min + ", Max: " + max);
	Array.print(values);
	print("P_Lower: " + pl_idx + "[" + values[pl_idx] + "]");
	print("P_Upper: " + pu_idx + "[" + values[pu_idx] + "]");


	/* Fit Gaussian to partitions. */
	maxError = 0;
	totError = 0;
	g1Err = 0;	// Error of the individual gaussian curves.
	g2Err = 0;
	g1MinErr = 0;	// Minimum error of the individual gaussian curves.
	g2MinErr = 0;
	pmax_idx = 0;

	curr_idx = 0;
	end_idx = (pu_idx - pl_idx);

	for (p_idx = pl_idx; p_idx <= pu_idx; p_idx++){
		y1 = arraySubsample(counts, 0, p_idx);
		x1 = arraySubsample(values, 0, p_idx);
		y2 = arraySubsample(counts, p_idx, counts.length - 1);
		x2 = arraySubsample(values, p_idx, counts.length - 1);

		Fit.doFit(21, x1, y1);
		g1Err = abs(Fit.rSquared);
		Fit.doFit(21, x2, y2);
		g2Err = abs(Fit.rSquared);

		if (g1Err == 1){
			g1Err = 0;
		}
			
		if (g2Err == 1){
			g2Err = 0;
		}

		totError = (0.5 * g1Err) + (0.5 * g2Err) ;
		if (totError > maxError){
			maxError = totError;
			pmax_idx = p_idx;
			g1MinErr = g1Err;
			g2MinErr = g2Err;
			
			x1max = Array.copy(x1);
			y1max = Array.copy(y1);
			x2max = Array.copy(x2);
			y2max = Array.copy(y2);
		}

		showProgress(curr_idx++, end_idx);
	}

	print("Total Error: " + maxError);
	print("P: " + values[pmax_idx]);
	print("Gaussian Error: " + g1MinErr + ", " + g2MinErr);
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

	Plot.create("Histogram", "Pixel Value", "Count");
	Plot.setColor("black");
	Plot.add("line", values, counts);
	Plot.setLimitsToFit();
	Plot.setColor("blue");
	Plot.add("line", values, gy1);
	Plot.setColor("green");
	Plot.add("line", values, gy2);
	Plot.show();
	

	selectImage(img);
	setThreshold(values[pmax_idx],65535);
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

	return maxError;
}

function gmmVSA2(img){
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

	return maxError;
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
	
	// Debugging
	print("Min: " + min + ", Max: " + max);
	Array.print(values);
	print("P1_Lower: " + p1l_idx + "[" + values[p1l_idx] + "]");
	print("P1_Upper: " + p1u_idx + "[" + values[p1u_idx] + "]");
	print("P2_Lower: " + p2l_idx + "[" + values[p2l_idx] + "]");
	print("P2_Upper: " + p2u_idx + "[" + values[p2u_idx] + "]");

	minError = 9999999999999;
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

	print("P1: " + p1min_idx + "[" + values[p1min_idx] + "]" + ", P2: " + p2min_idx + "[" + values[p2min_idx] + "]");
	print("");
	print("Max: " + p1min[0] + ", Mu: " + p1min[1] + ", Variance: " + p1min[2]);
	print("Max: " + p2min[0] + ", Mu: " + p2min[1] + ", Variance: " + p2min[2]);
	print("Max: " + p3min[0] + ", Mu: " + p3min[1] + ", Variance: " + p3min[2]);

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

	thresh = calcThreshold(p2min[0], p2min[1], p2min[2], p3min[0], p3min[1], p3min[2]);
	print("Threshold: " + thresh);

	selectImage(img);
	setThreshold(values[thresh],65535);
	run("Convert to Mask");
	resetThreshold();
	print("---------------");

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