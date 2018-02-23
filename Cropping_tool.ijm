macro "Straight_Line_Cropping_Tool"{
	inDir = getDirectory("Select_Input");
	outDir = getDirectory("Select_Ouptut");

	list = getFileList(inDir);

	dimW = "0";
	diaX = 0;
	diaY = 0;
	
	k = 0;
	for (i = 0; i < list.length; i++){
		if (ofImageType(list[i])){
			//Get the name of the image without the extention.
			name = substring(list[i], 0, indexOf(list[i], "."));
			
			run("Bio-Formats Importer", "open=[" + inDir + list[k] + "] color_mode=Default open_files rois_import=[ROI manager] view=[Standard ImageJ] stack_order=Default");
			waitForUser("Create Selection", "Click OK to continue");
			
			setBatchMode(true);

			setMinAndMax(0, 65535);
			
			run("Straighten...");
			setMinAndMax(0, 65535);
			run("16-bit");
			setMinAndMax(0, 65535);
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
