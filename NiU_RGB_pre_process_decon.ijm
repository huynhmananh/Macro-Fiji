clear_everything();
defaut_setting();

#@ File (label = "Input directory", style = "directory") input
#@ String (label="Number of end number", choices={"2", "1", "3", "4"}) end_num
#@ boolean (label="Deconvolution") decon_check

// parameter
down_scale = 0.5;
list = getFileList(input);
list = Array.sort(list);
NMJ_list = create_NMJ_list(list);
psf_dir = getDirectory("imagej");
PSF_HRP_input = psf_dir + File.separator + "PSF-file" + File.separator + "PSF_HRPFITC.tif";
PSF_DLG_input = psf_dir + File.separator + "PSF-file" + File.separator + "PSF_DLG594.tif";
end_num = parseInt(end_num);
suffix = ".nd2";

for (NMJ_index = 0; NMJ_index < NMJ_list.length; NMJ_index++) {
	NMJ_name = NMJ_list[NMJ_index];
	HRP_name = NMJ_name + "_HRP";
	DLG_name = NMJ_name + "_DLG";
	if (decon_check == 1) {
		open(PSF_HRP_input);
		PSF_HRP = getTitle();
		open(PSF_DLG_input);
		PSF_DLG = getTitle();
		create_RG_stack(NMJ_name);		
		scale_down(HRP_name, down_scale);
		selectImage(HRP_name);	
		getPixelSize(unit, pw, ph, pd);		
		decon(HRP_name,PSF_HRP, 8);
		selectImage(HRP_name);	
		setVoxelSize(pw, ph, pd, unit);
		scale_down(DLG_name, down_scale);		
		decon(DLG_name,PSF_DLG, 12);
		selectImage(DLG_name);	
		setVoxelSize(pw, ph, pd, unit);		
		create_Zstack(NMJ_name);
	} else {
		create_RG_stack(NMJ_name);	
		scale_down(HRP_name, down_scale);
		scale_down(DLG_name, down_scale);
		create_Zstack(NMJ_name);
	}
	save_image(input, NMJ_name);
	clear_everything();	
}

function create_RG_stack(NMJ_name) { 		
	count_G = 0;
	count_R = 0;		
	for (file_index = 0; file_index < list.length; file_index++) {
		if (indexOf(list[file_index], NMJ_name)>=0 && endsWith(list[file_index], suffix)) {
			openfile(input, list[file_index]);
			chan_num = detect_channel(list[file_index]);
			if (chan_num==2) {
				if (count_G == 0) {
					selectImage(list[file_index]);
					HRP_name = NMJ_name + "_HRP";					
					rename(HRP_name);
					count_G++;
				} else {									
					append_stack(HRP_name, list[file_index]);
				}				
		}	else {
				if (count_R == 0) {
					selectImage(list[file_index]);
					DLG_name = NMJ_name + "_DLG";					
					rename(DLG_name);
					count_R++;
				} else {
					append_stack(DLG_name, list[file_index]);					
				}			
			}
		}
	}
}

function create_Zstack(NMJ_name) { 	
	//create Z maximum stack	
	rolling_ball = round(10/pw);
	selectImage(HRP_name);
	run("Subtract Background...", "rolling="+ rolling_ball +" stack");
	if (nSlices>1) {
		run("Z Project...", "projection=[Max Intensity]");
	}
	c1= getTitle();
	selectImage(DLG_name);		
	run("Subtract Background...", "rolling="+ rolling_ball +" stack");	
	if (nSlices>1) {
		run("Z Project...", "projection=[Max Intensity]");
	}
	c2= getTitle();	
	run("Merge Channels...", "c1="+c1+" c2="+c2+" create");
	Stack.setDisplayMode("color");	
	run("32-bit");
	Stack.setChannel(1);
	setMinAndMax(0, 1024);
	Stack.setChannel(2);
	setMinAndMax(0, 1024);
	setOption("ScaleConversions", true);
	run("16-bit");
	Stack.setChannel(1);
	run("Green");
	run("Enhance Contrast", "saturated=0.15");
	Stack.setChannel(2);
	run("Magenta");	
	run("Enhance Contrast", "saturated=0.15");
	Stack.setDisplayMode("composite");
	rename(NMJ_name);	
	
}

function openfile(input, file) { 
	// Open file use bioformat
	filename = input + File.separator + file;
	run("Bio-Formats Importer", "open=["+filename+"] autoscale color_mode=Default rois_import=[ROI manager] view=Hyperstack stack_order=XYCZT");
}

function decon(image_input, PSF_input, RL) {	
	num_image = nImages;
	image = " -image platform " + image_input;
	psf = " -psf platform " + PSF_input;
	algorithm = " -algorithm RL " + RL;
	parameters = "";
	run("DeconvolutionLab2 Run", image + psf + algorithm + parameters);
	while(nImages == num_image) { 
		//system waits until the deconvolved image pops up 
		wait(50);
	}
	selectImage(image_input);
	close();
	selectImage("Final Display of RL");
	rename(image_input);
	run("Collect Garbage");	
}

function detect_channel(image) {
	// detect channel have maximum signal
	run("Clear Results");
	mean_C = newArray();	
	for (chan = 1; chan < 4; chan++) {
		selectImage(image);
		Stack.setChannel(chan);
		run("Measure");
	    mean_C[chan-1] = getResult("Mean", (chan-1));    
	}
	run("Clear Results");
	maxValue = mean_C[0];
	maxIndex = 0;	
	for (pos = 0; pos < lengthOf(mean_C); pos++) {	    
	    if (mean_C[pos] >= maxValue) { 
	    	maxValue = mean_C[pos];
	        maxIndex = pos+1;
	    }	
	}
	run("Arrange Channels...", "new=" + maxIndex);
	return maxIndex;
}

function append_stack(stack, new_image) {  
	// append stack with new image
    selectImage(stack);
    setSlice(nSlices);
    run("Add Slice");    
    selectImage(new_image);
    run("Copy");
    selectImage(stack);
    setSlice(nSlices);
    run("Paste"); 
    run("Select None");
    selectImage(new_image);
    close();
}

function clear_everything() { 
// clear everything 
	run("Clear Results");
	roiManager("reset");
	run("Close All");
	run("Collect Garbage");
}

function defaut_setting() {		
	run("Options...", "iterations=1 count=1 black");
	run("Set Measurements...", "mean display redirect=None decimal=4");
}

function create_NMJ_list(file_list) { 
	suffix = ".nd2";
	dum_list =newArray();
	NMJ_list= newArray();	
	for (i = 0; i < file_list.length; i++) {
			if(endsWith(list[i], suffix)) {
			dum_list[i] = replace(file_list[i], suffix, "");
			dum_list[i] = substring(dum_list[i], 0, lengthOf(dum_list[i])-1-end_num);
		}
	}	
	dum_count = 0;	
	while (dum_list.length>0) {
		NMJ_list[dum_count] = dum_list[0];
		dum_list = Array.deleteValue(dum_list, dum_list[0]);	
		dum_count++;
	} return NMJ_list;
}

function save_image(input, save_name) { 
	save_name = input + File.separator + save_name + "_NMJ.tif";
	saveAs("Tiff", save_name);
}

function scale_down(image_input, down_scale) { 
	selectImage(image_input);
	rename("dummy");
	run("Scale...", "x="+down_scale+" y="+down_scale+" z=1.0 interpolation=Bilinear average process create");
	rename(image_input);
	selectImage("dummy");
	close();
}
