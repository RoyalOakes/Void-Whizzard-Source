macro "Contour_Segmentation"{
	img = getTitle();	// Title of binary image.
	
	run("Select None");
	run("Find Maxima...", "noise=10 output=[Point Selection]");
	res_idx = nResults;
	run("Measure");
	for (i = 0; i < nResults - res_idx; i++){
		selectWindow(img);
		doWand(getResult("X", i + res_idx), getResult("Y", i + res_idx), 0.0, "8-connected");
		
		run("Interpolate", "interval=2 adjust");
		if (selectionType() != -1){
			getSelectionCoordinates(xx, yy);
			//run("Add Selection...");	//Debugging

			arm = 5;
			curvature = Array.getVertexAngles(xx, yy, arm);
			edgeMode = 2; //circular
			tolerance = 35;
			//maxPosArr = Array.findMaxima(curvature, tolerance, edgeMode);
			minPosArr = Array.findMinima(curvature, tolerance, edgeMode); // Concave points.

			
			
			// Debugging
			/*
			for(jj = 0; jj < maxPosArr.length; jj++){
				x = xx[maxPosArr[jj]];
				y = yy[maxPosArr[jj]];
				makeOval(x-1, y-2, 2, 2);
				run("Properties... ", "  fill=green");
				run("Add Selection...");
			}
			for(jj = 0; jj < minPosArr.length; jj++){
				x = xx[minPosArr[jj]];
				y = yy[minPosArr[jj]];
				makeOval(x-1, y-1, 2, 2);
				run("Properties... ", "  fill=red");
				run("Add Selection...");
			}
			*/
			
			run("Select None");
		}
	}

	IJ.deleteRows(res_idx, nResults - 1);
}

function 
