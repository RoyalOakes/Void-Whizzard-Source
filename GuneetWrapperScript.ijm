extension = ".TIFF";
dir1 = getDirectory("Choose Source Directory ");
setBatchMode(true);
n=0;
processFolder(dir1);

function processFolder(dir1) {
     list = getFileList(dir1);
     for (i=0; i<list.length; i++) {
          if (endsWith(list[i], "/"))
              //processFolder(dir1+list[i]);
              a=1;
          else if (endsWith(list[i], extension))
             print("in");
             processImage(dir1, list[i]);
      }
  }
function processImage(dir1, name) {
     open(dir1+name);
     print(n++, name);
     run("8-bit");

     run("Duplicate...", "title="+"spots");
	 run("Duplicate...", "title="+"paper");
	 
	 selectWindow("paper");
     setAutoThreshold("Default dark");
	 setThreshold(10, 255);
	 run("Threshold");
	 run("Convert to Mask");
	 run("Invert");
	 run("Open");
	 run("Fill Holes");
	 saveAs("Tiff", dir1+"paper_"+name);
	 
	 selectWindow("spots");
	 setAutoThreshold("Default dark");
	 setThreshold(70, 255);
	 run("Threshold");
	 run("Convert to Mask");
	 run("Open");
	 run("Fill Holes");
	 saveAs("Tiff", dir1+"spots_"+name);
	 run("Ellipse Split", "binary=[Use standard watershed] add_to_manager add_to_results_table remove merge_when_relativ_overlap_larger_than_threshold overlap=95 major=0-Infinity minor=0-Infinity aspect=1-Infinity");
	 roiManager("Measure");
	 saveAs("Results", dir1+n+".xls");

	 //saving rois in roi manager
	 roiManager("Save", dir1+"RoiSet_"+name+".zip");
	 nROIs=roiManager("count");
	 //wait(5000);
	 
	 if(nROIs!=0){
	 	run("Clear Results");
	 	run("Select All");
	 	roiManager("Delete");	
	 }
	 //wait(5000);
	 close();
	 close();
	 close();
	 
  }
