clear_everything();

#@ File    (label = "Input directory", style = "directory") inDir

// set Option measure
run("Options...", "iterations=1 count=1 black");
run("Set Measurements...", "area mean standard min centroid center perimeter bounding fit shape integrated median area_fraction redirect=None decimal=4");
pixe_size_std = 0.2071615;
suffix = "_decon.tif"
//get InDir
filelist = getFileList(inDir);
filelist = Array.sort(filelist);
number_of_NMJ = 0;
for (i=0; i < lengthOf(filelist); i++) {
	if (indexOf(filelist[i], suffix) >=0) {
		number_of_NMJ = number_of_NMJ + 1 ;
	}
}

name_list = newArray(number_of_NMJ);
area_list = newArray(number_of_NMJ);
total_lenght_list = newArray(number_of_NMJ);
number_of_islands_list = newArray(number_of_NMJ);
number_of_branch_list = newArray(number_of_NMJ);
number_of_bouton_list = newArray(number_of_NMJ);
mean_bouton_size_list = newArray(number_of_NMJ);
longest_branch_list = newArray(number_of_NMJ);
order_NMJ = -1;
for (i = 0; i < lengthOf(filelist); i++) {
    if (indexOf(filelist[i], suffix) >=0) {
    	order_NMJ = order_NMJ +1;
    	filename = inDir + File.separator + filelist[i];
    	run("Bio-Formats Importer", "open=["filename"] autoscale color_mode=Default rois_import=[ROI manager] view=Hyperstack stack_order=XYCZT");

//set name image
image = getTitle();
new_name = replace(image, suffix, "");
name_list[order_NMJ] = new_name;
selectImage(image);
rename(new_name);
image = new_name;
width = getWidth();
getPixelSize(unit, pixelWidth, pixelHeight);
scale_change = pixelWidth/pixe_size_std;

run("Scale...", "x=0"+scale_change+" y="+scale_change+" z=1.0 interpolation=Bilinear average create title=image");
selectWindow(image);
close();
selectWindow("image");
rename(image);
Stack.setDisplayMode("color");
run("Subtract Background...", "rolling=50 stack");
Stack.setChannel(1);
run("Green");
run("Enhance Contrast", "saturated=0.15");
Stack.setChannel(2);
run("Magenta");
run("Enhance Contrast", "saturated=0.15");
// Select ROIs
setTool("freehand");
waitForUser("Draw around DLG1 signal");
roiManager("Add");
run("Select None");
// Calib DLG1 signal
run("Duplicate...", "title=DLG duplicate channels=2");
run("Subtract Background...", "rolling=25 sliding disable");
run("Duplicate...", "title=DLG-1");
selectWindow("DLG-1");
run("Gaussian Blur...", "sigma=4 scaled");
run("Add...", "value=2000");
imageCalculator("Divide create 32-bit", "DLG","DLG-1");
selectWindow("DLG-1");
close;
selectWindow("DLG");
close;
// Area measure islands
selectWindow("Result of DLG");
run("16-bit");
run("Duplicate...", "title=area");
run("Unsharp Mask...", "radius=4 mask=0.6");
run("Gaussian Blur...", "sigma=0.8 scaled");
roiManager("Select", 0);
setAutoThreshold("Li dark");
run("Create Selection");
run("Create Mask");
rename(image);
run("Fill Holes");
roiManager("Select", 0);
setBackgroundColor(0, 0, 0);
run("Clear Outside");
run("Select None");
run("Erode");
setAutoThreshold("Otsu dark");
run("Analyze Particles...", "size=3-Infinity show=Masks display clear include in_situ");
run("Select None");
setAutoThreshold("Otsu dark");
run("Analyze Particles...", "size=3-Infinity show=Masks display clear include in_situ");
run("Remove Outliers...", "radius=2 threshold=50 which=Bright");
run("Create Selection");
roiManager("Add");
numIslands = nResults;
area = 0;
for (j = 0; j < nResults(); j++) {
        v = getResult('Area', j);
        area= area + v;
    }
run("Clear Results");
//measure length branch
run("Select None");
resetThreshold();
rename("length");
run("Close-");
run("Open");
run("Remove Outliers...", "radius=4 threshold=50 which=Bright");
run("Median...", "radius=10");
run("Dilate");
run("Dilate");
run("Dilate");
run("Dilate");
run("Median...", "radius=8");
run("Skeletonize");
run("Analyze Skeleton (2D/3D)", "prune=none calculate");
TotalBranch = 0;
length = 0;
longest_branch_length = 0;
for (j = 0; j < nResults(); j++) {
    triplepoint = getResult("# Triple points", j);
    meanlength = getResult("Average Branch Length", j);
    Branches = getResult("# Branches", j);
    length = length + meanlength*Branches;
    TotalBranch = TotalBranch + Branches - triplepoint;
    long_branch_length = getResult("Longest Shortest Path", j);
    if (long_branch_length > longest_branch_length) {
    	longest_branch_length = long_branch_length;
    }
}
selectWindow("length");
setAutoThreshold("Li dark");
run("Create Selection");
roiManager("Add");
selectWindow("Tagged skeleton");
close;
selectWindow("length");
close;
selectWindow("area");
close;
// bouton number
selectWindow(image);
if (nSlices > 2) {
	run("Z Project...", "projection=[Standard Deviation]");
	run("16-bit");
}
run("Arrange Channels...", "new=1");
run("Green");
rename("HRP");
run("Duplicate...", "title=HRP_bouton");
run("Unsharp Mask...", "radius=4 mask=0.60");
run("Gaussian Blur...", "sigma=0.6 scaled");
setAutoThreshold("Otsu dark");
run("Create Selection");
run("Create Mask");
roiManager("Select", 1);
setBackgroundColor(0, 0, 0);
run("Clear Outside");
run("Select None");
run("Close-");
run("Fill Holes");
run("Watershed");
run("Find Maxima...", "prominence=10 output=[Point Selection]");
roiManager("Add");
close();
close();
setOption("ScaleConversions", true);
run("Merge Channels...", "c2=HRP c6=[Result of DLG] create ignore");
//run("Brightness/Contrast...");
Stack.setDisplayMode("color");
run("Subtract Background...", "rolling=25");

run("Channels Tool...");
roiManager("Select", 3);
setTool("multipoint");
run("Point Tool...", "type=Dot color=Orange size=Small label show counter=0");
run("Clear Results");
run("Measure");
number_of_bouton = nResults;
waitForUser("There are: " + number_of_bouton + " boutons.\nPlease check.\nNote: ADD by Click or REMOVE by Ctrl + Click.");
run("Clear Results");
run("Measure");
roiManager("Add");
run("Select None");
number_of_bouton = nResults;
mean_bouton_size = area/number_of_bouton;
// print results
name_list[order_NMJ] = image;
area_list[order_NMJ] = area;
total_lenght_list[order_NMJ] = length;
number_of_islands_list[order_NMJ] = numIslands;
number_of_branch_list[order_NMJ] = TotalBranch;
number_of_bouton_list[order_NMJ] = number_of_bouton;
mean_bouton_size_list[order_NMJ] = mean_bouton_size;
longest_branch_list[order_NMJ] = longest_branch_length;
//print(image + " Area: " + area+ "; Number Of Islands: " + numIslands + "; Total Length: " + length + "; Number Branches: " +TotalBranch);
// Save image
selectWindow("Composite");
run("Unsharp Mask...", "radius=1 mask=0.4 stack");
run("Gaussian Blur...", "sigma=0.15 scaled stack");
Stack.setDisplayMode("color");

Stack.setChannel(2);
roiManager("Select", 1);
savename = inDir + File.separator + image +" area.tif";
saveAs("Tiff", savename);
roiManager("Select", 2);
savename = inDir + File.separator + image +" length.tif";
saveAs("Tiff", savename);
roiManager("Select", 4);
Stack.setChannel(2);
savename = inDir + File.separator + image +" bouton.tif";
saveAs("Tiff", savename);
run("Close All");
roiManager("Deselect");
roiManager("Delete");
run("Clear Results");
    }
}
Table.create("NMJ_results");
selectWindow("NMJ_results");
		Table.setColumn("File_name", name_list);
		Table.setColumn("DLG_area", area_list);
		Table.setColumn("Length", total_lenght_list);
		Table.setColumn("Num of Islands", number_of_islands_list);
		Table.setColumn("Num of Branch", number_of_branch_list);
		Table.setColumn("Num of Boutons", number_of_bouton_list);
		Table.setColumn("Mean_bouton_size", mean_bouton_size_list);
		Table.setColumn("Longest_branch_length", longest_branch_list);

saveresult = inDir + File.separator + "Result" + ".csv";
saveAs("Results", saveresult);
clear_everything();
print("Finish");
function clear_everything() { 
// clear everything 
	run("Clear Results");
	roiManager("reset");
	run("Close All");
	run("Collect Garbage");
}