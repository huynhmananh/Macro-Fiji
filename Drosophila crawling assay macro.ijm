requires("1.53t");
print("\\Clear");
clear_everything();
// Input parameter
#@ File    (label = "Input directory", style = "directory") input
#@ Integer (label="Frame per second",value =30) fps_avi
#@ String  (choices= {"Default", "Huang", "Intermodes", "IsoData","IJ_IsoData","Li","MaxEntropy","Mean","MinError","Minimum","Moments","Otsu","Percentile","RenyiEntropy","Shanbhag","Triangle","Yen"},value="Yen", label = "Threshold Method", style="listBox") threshold_method
#@ Integer (label="Set scale lenght (cm)",value =5) scale_lenght
#@ boolean (label="Automated detect crawling arena") auto_arena_detect
#@ Integer (label="Crawling arena diameter (cm)",value = 15) arena_diameter
#@ boolean (label="Light Background") light_bg
#@ Integer (label="Time begin (second)", value =3) time_begin
#@ Integer (label="Time end (second)", value =53) time_end
#@ Double  (label="Minimum larvae size (mm^2)", style="slider", min=0, max=10, value =3.0,stepSize=0.1, style="slider,format:0.0") min_size
#@ Double  (label="Maximum larvae size (mm^2)", style="slider", min=0, max=10, value =4.5,stepSize=0.1, style="slider,format:0.0") max_size

// Defaut setting
defaut_setting();
filelist = getFileList(input);

// input review frame for set scale
frame_review = fps_avi*20;
for (i = 0; i < lengthOf(filelist); i++) {
    if (endsWith(filelist[i], ".avi")) { 
        input_avi(input, filelist[i], frame_review, frame_review);
        i = lengthOf(filelist);
    } 
}
setScale(scale_lenght);

// Calculation some parameter
	getVoxelSize(width, height, depth, unit);
	pixel_area = width*height;
	larvae_pixel_min = round(min_size/pixel_area/1.5);
	larvae_pixel_max = round((max_size/pixel_area)*1.5);
	time_track = (time_end-time_begin)/2;
	num_frame_track = round(time_track*10);
	sub_bg_roll = round(3/width);
	sharpen_roll = round(sub_bg_roll/2);
	frame_begin = fps_avi*time_begin +1;
	frame_end = fps_avi*time_end;
	reduction_factor = fps_avi/10;	
	arena_area = round(Math.sqr(arena_diameter*10/2-10)*3.14);
	
// Processing video
clear_everything();
processFolder(input);
print("Finish");

// Define some function
function processFolder(input) {
	// process folder
	list = getFileList(input);
	list = Array.sort(list);
		for (file_order = 0; file_order < list.length; file_order++) {
			if(File.isDirectory(input + File.separator + list[file_order]))
				processFolder(input + File.separator + list[file_order]);
			if(endsWith(list[file_order], ".avi"))
				processFile(input, list[file_order], frame_review, time_begin, time_end);
	}
}

function processFile(input, file, frame_review, time_begin, time_end) { 
// input for select arena	
	print("Processing: "+ file);
	input_avi(input, file, frame_review, frame_review);
	title = getTitle();
	title = replace(title, ".avi", "");
	//auto select arena
	if (auto_arena_detect == 1) {
		auto_select_arena(arena_area);
	}
	//manual select arena
	if (auto_arena_detect == 0) {
		manual_select_arena();
	}
	run("Close All");
	nROIs = roiManager("count");
	if (nROIs == 1) {			
		input_avi(input, file, frame_begin, frame_end);
		roiManager("Select", 0);
		run("Crop");		
		run("Reduce...", "reduction="+ reduction_factor);
		if (light_bg == 1) {
			run("Invert", "stack");		
		}
		rename("image");
		run("Z Project...", "projection=[Average Intensity]");
		imageCalculator("Subtract stack", "image","AVG_image");
		selectWindow("AVG_image");
		close();
		selectWindow("image");
		run("Gaussian Blur...", "sigma=0.15 scaled stack");
		run("Z Project...", "projection=[Max Intensity]");
		selectWindow("MAX_image");
		setBackgroundColor(0, 0, 0);
		setAutoThreshold(threshold_method +" dark");
		getThreshold(lower, upper);
		close();
		selectWindow("image");		
		setOption("BlackBackground", true);
		setThreshold(lower, upper);		
		run("Convert to Mask", "method=Yen background=Dark black");		
		selectWindow("image");	
		select_ROI(arena_diameter);
		run("Crop");
		run("Clear Outside", "stack");		
		run("Clear Results");
		run("Remove Outliers...", "radius=1 threshold=50 which=Bright stack");
		run("Median 3D...", "x=1 y=1 z=4");		
		run("Select None");		
		rename(title);
		run("wrMTrck ", "minsize="+ larvae_pixel_min +" maxsize="+ larvae_pixel_max +" maxvelocity=10 maxareachange=100 mintracklength="+num_frame_track+" bendthreshold=2 binsize=0 showpathlengths showlabels showpositions showpaths showsummary smoothing rawdata=0 benddetect=2 fps=10 backsub=0 threshmode=Otsu fontsize=16");
		selectWindow("Paths");
		savename = input+ File.separator + title + "_crawling-path.tif";
		saveAs("Tiff", savename);
		saveResult = input+ File.separator + title + "_Results.csv";
		saveAs("Results", saveResult);
		clear_everything();		
	}
	if (nROIs != 1) {
		print("FAIL: "+ file);
		clear_everything();		
	}
}

function manual_select_arena() { 
//  manual select crawling arena by user draw
	setTool("oval");
	waitForUser("Please draw a round to detect arena");
	roiManager("add");	
}

function auto_select_arena(arena_area) { 
// auto  select crawling arena using diameter and round shape
	if (light_bg == 1) {
		run("Invert");		
	}
	run("Subtract Background...", "rolling="+sub_bg_roll);	
	run("Unsharp Mask...", "radius="+ sharpen_roll +" mask=0.60");
	run("Gaussian Blur...", "sigma=0.6 scaled");
	setAutoThreshold("Li dark");
	run("Create Mask");
	run("Dilate");
	run("Fill Holes");
	run("Watershed");
	setAutoThreshold("Otsu dark");
	run("Analyze Particles...", "size="+arena_area+"-Infinity circularity=0.60-1.00 clear add");	
}

function clear_everything() { 
// clear everything 
	run("Clear Results");
	roiManager("reset");
	run("Close All");
	run("Collect Garbage");
}

function defaut_setting() {
// defaut for binary and measurements
	run("Options...", "iterations=1 count=1 black");
	run("Set Measurements...", "area standard modal centroid center perimeter bounding fit shape feret's integrated median skewness kurtosis area_fraction stack display redirect=None decimal=4");
}

function input_avi(input, file, begin, end) {
// input one frame in a video for set scale or auto select crawling arena
  	filename = input + File.separator + file;
    run("AVI...", "avi=["+filename+"] use convert first="+ begin +" last="+end);
} 

function setScale(scale_lenght) {
// set scale
	setTool("line");
	run("Set Scale...", "distance=1 known=1 unit=pixel global");
	waitForUser("Set scale", "Please draw a line "+ scale_lenght +"cm");
	run("Clear Results");
	run("Measure");
    pixel_lenght = getResult('Length', 0);
    known_lenght = scale_lenght*10;
	run("Set Scale...", "distance="+ pixel_lenght +" known=" + known_lenght + " unit=mm global");
	run("Select None");
}

function select_ROI(arena_diameter) {
// Select same area for export crawling path 
	export_size = arena_diameter*10 - 10;
	width_center = getWidth()/2*width;
	height_center = getHeight()/2*height;
	run("Specify...", "width="+ export_size +" height="+ export_size +" x="+ width_center +" y="+ height_center +" oval constrain centered scaled");
}
