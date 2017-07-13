process();

function process(){
	run("Despeckle");
	run("Kuwahara Filter", "sampling=5");
	run("Median...", "radius=1");
	//run("Enhance Contrast...", "saturated=0.5 normalize");

	getHistogram(values, counts, 256);
	max  = Array.findMaxima(counts, 15000);
	mins = Array.findMinima(counts, 25);
	max = Array.sort(max);
	max = Array.reverse(max);
	mins = Array.sort(mins);

	threshold = 0;

	print("Max: " + values[max[0]]);
	for(i = 0; i < mins.length; i++){
		print(values[mins[i]]);
	}
	print("--");

	for (i = 0; i < mins.length; i++){
		if (mins[i] > max[0]){
			print("Threshold: " + mins[i]);
			setThreshold(values[mins[i]], 65535);
			run("Convert to Mask");
			return;
		}
	}
}
