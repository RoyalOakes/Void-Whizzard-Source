macro "Straight_Line_Cropping_Tool"{
	inDir = getDirectory("Select Input");
	outDir = getDirectory("Select Ouptut");

	list = getFileList(inDir);

	dimW = "0";
	diaX = 0;
	diaY = 0;
	
	k = 0;
	for (i = 0; i < list.length; i++){
		if (ofImageType(list[i])){
			open(inDir + list[k]);
			waitForUser("Create Selection", "Click OK to continue");
			
			setBatchMode(true);
			run("Straighten...");
			run("16-bit");
			saveAs("Tiff", outDir + list[k]);
			k++;
			run("Close All");
			setBatchMode(false);
		}
	}

	showMessage("Finished.")
}

function ofImageType(str){
	if(endsWith(str, ".tif")){
		return true;
	} else if (endsWith(str, ".TIF")){
		return true;
	} else if (endsWith(str, ".png")){
		return true;
	} else if (endsWith(str, ".PNG")){
		return true;
	} else if (endsWith(str, ".jpg")){
		return true;
	} else if (endsWith(str, ".JPG")){
		return true;
	} else {
		return false;
	}
}
