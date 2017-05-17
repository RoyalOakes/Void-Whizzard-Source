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
			setAutoThreshold("Triangle dark");
			setOption("BlackBackground", true);
			run("Convert to Mask");
			resetThreshold();
		}
	}
	setBatchMode("Exit and Display");
}

function preprocess(img){
	selectWindow(img);
	run("Despeckle");
	run("Kuwahara Filter", "sampling=5");
	run("Subtract Background...", "rolling=50 sliding");
}
