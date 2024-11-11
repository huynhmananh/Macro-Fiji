clear_everything();
run("Options...", "iterations=1 count=1 black");
requires("1.53t");

direction_list = newArray("Vertical","Horizontal");
type_list = newArray("Height (mm)","Rank");
settime_type = newArray("Auto", "Manual");
// Request basis information of videos
	Dialog.create("Climbing set up");
		Dialog.addNumber("Time to review (second)", 15);
		Dialog.addNumber("Frame per second (FPS)", 30);
		Dialog.addNumber("Time flies climb (second)", 5);
		Dialog.addChoice("Set time to review:", settime_type);
		Dialog.addNumber("Interval time (second)", 60);
		Dialog.addNumber("Number of repeat:", 5);
		Dialog.addNumber("Number of strain:", 3);
		Dialog.addNumber("Vial climbing height (cm):", 12);
		Dialog.addChoice("Vial direction", direction_list);
		Dialog.addChoice("Export result type:", type_list);
		Dialog.show();
		SECOND_TO_REVIEW = Dialog.getNumber();
		FPS = Dialog.getNumber();
		SECOND_TO_CLIMB = Dialog.getNumber();
		SETTIME_TYPE = Dialog.getChoice();
		INTERVAL_TIME = Dialog.getNumber();
		NUM_REPEAT_TIME = Dialog.getNumber();
		NUM_STRAIN = Dialog.getNumber();
		MAX_HEIGHT = Dialog.getNumber();
		VIAL_DIRECTION = Dialog.getChoice();
		TYPE_RESULT = Dialog.getChoice();
	
	print("Time to review (second): " + SECOND_TO_REVIEW);
	print("Frame per second (FPS): " + FPS);
	print("Time flies climb (second): " + SECOND_TO_CLIMB);
	print("Interval time (second): " + INTERVAL_TIME);
	


// input video for set scale
	input_file = File.openDialog("Select a Climbing Video");
	setTool("line");
	run("AVI...", "open=["+input_file+"] use convert");
	length_of_video = nSlices;
	video_title = getTitle();
	print(video_title);
	input_dic = getInfo("image.directory");
	run("Set Scale...", "distance=1 known=1 unit=pixel global");
	waitForUser("SetScale", "Draw line 8 cm");
	run("Clear Results");
	run("Measure");
	for (i = 0; i < nResults(); i++) {
	    v = getResult('Length', i);
	    }
	updateResults();
	run("Set Scale...", "distance=v known=80 unit=mm global");
	print("Set scale");
	run("Select None");
	run("Clear Results");
	close();

// begin analyse
	
	strain_count=0;
	number_of_flies_pre_repeat = 0;
	time_push_down_array = newArray(10);
	newStrain_or_not = 1;
	// interval array
	INTERVAL_ARRAY = newArray(10);
	number_of_flies_array = newArray(10);
	for (i = 0; i < 10; i++) {
		INTERVAL_ARRAY[i] = i*INTERVAL_TIME;
	}
	
	if (SETTIME_TYPE== "Manual") {
		for (i = 0; i < NUM_REPEAT_TIME; i++) {
			INTERVAL_ARRAY[i] = ask_time(i);			
		}
	}

	while (newStrain_or_not) {
		total_time_repeat = 0;
		strain_count = strain_count + 1;
		name = ask_new_strain_nanme();
		time_repeat = 0;
		continue_or_not = 1;
		name_table = "Climbing Result " + name;
		Table.create(name_table);
		print("Name of strain: "+ name);
		while (continue_or_not) {
			total_time_repeat = total_time_repeat + 1;
			time_to_review = INTERVAL_ARRAY [time_repeat];
			time_repeat_in_analyse = time_repeat;
			time_repeat = time_repeat + 1;
			print("Repeat time: " + time_repeat);	
			print("     Time begin review: " + time_to_review);
			if (strain_count == 1) {
				input_video_review(time_to_review);
				setTool("hand");
				waitForUser("Find the time push down");				
				Dialog.create("Time push down");
					Dialog.addNumber("Time in second", time_push_down_array[time_repeat_in_analyse]);
					Dialog.show();
					time_to_count = Dialog.getNumber();
				time_push_down_array[time_repeat_in_analyse] = time_to_count;
				print("     Time push down: " + time_to_count);
				close();
			}
			time_to_count = time_push_down_array[time_repeat_in_analyse];
			count_time = time_to_count + SECOND_TO_CLIMB;
			if (strain_count != 1) {
			print("Time push down vial: " + time_to_count);
			}
			print("Time to count: " + count_time);
			input_video_analyse(count_time);	
			// Where to analyse
			count_slice = round((nSlices+1)/2);	
			setTool("rectangle");
			waitForUser("Draw select region.\n Note: Bottom of box: Bottom of vial.");
			roiManager("add");
			roiManager("select", recent_ROIs());
			roiManager("rename", "box_" + time_repeat);		
			run("Crop");
			run("Select None");
			title = getTitle();
			rename("stack");
			run("Invert", "stack");
			run("Z Project...", "projection=[Average Intensity]");
			imageCalculator("Subtract create stack", "stack","AVG_stack");
			selectWindow("Result of stack");
			setSlice(count_slice);
			run("Duplicate...", "title=count_slice");
			run("Unsharp Mask...", "radius=20 mask=0.6");
			run("Gaussian Blur...", "sigma=0.3 scaled");
			setAutoThreshold("Otsu dark");
			run("Create Mask");
			run("Watershed");
			run("Open");
			run("Clear Results");
			run("Analyze Particles...", "size=0.20-4.00 show=Masks display clear include in_situ");
			run("Find Maxima...", "prominence=10 output=[Point Selection]");
			roiManager("Add");
			roiManager("select", recent_ROIs());
			roiManager("rename", "flies_" + time_repeat);
			selectWindow("mask");
			close();
			selectWindow("count_slice");
			close();
			selectWindow("Result of stack");
			close();
			selectWindow("AVG_stack");
			close();			
			selectWindow("stack");
			rename(title);
			setSlice(count_slice);
			run("Invert", "stack");
			run("Enhance Contrast", "saturated=0.25");			
			roiManager("select", flies_ROIs(time_repeat));
			not_enough_flies = 1;	
			while (not_enough_flies) {
				roiManager("select", flies_ROIs(time_repeat));
				run("Clear Results");
				run("Set Measurements...", "area area_fraction invert redirect=None decimal=1");
				run("Measure");
				number_of_flies = nResults;
				number_of_flies_array[time_repeat_in_analyse] = nResults;
		
				setTool("multipoint");	
				run("Point Tool...", "type=Dot color=Green size=Small label show counter=0");
				
				waitForUser("Number of flies: " + number_of_flies + "\nADD by Click or REMOVE by Ctrl + Click.\nNote: Slice " + count_slice);
				roiManager("update");
				run("Clear Results");	
				run("Measure");
				number_of_flies = nResults;
				number_of_flies_array[time_repeat_in_analyse] = nResults;
				if (nResults != number_of_flies_pre_repeat && time_repeat!= 1) {
					not_enough_flies = getBoolean("Number of flies: " + number_of_flies + "\nNumber of previous count: " + number_of_flies_pre_repeat +"\nDo you want to continue to next repeat?", "Count again", "Continue next repeat");					
				}
				if (nResults == number_of_flies_pre_repeat) {
					not_enough_flies = 0;
					}
				if (time_repeat ==1) {
					not_enough_flies = 0;
				}
			}			
			run("Close All");
		// Finish a loop here
		number_of_flies_pre_repeat = nResults;
		if (VIAL_DIRECTION == "Horizontal") {
			location_result = get_X_result();
			location_result = Array.sort(location_result);
		}
		if (VIAL_DIRECTION == "Vertical") {
			location_result = get_Y_result();
			location_result = Array.sort(location_result);
		}
		selectWindow(name_table);
		Table.setColumn("Repeat " + time_repeat, location_result);		
		print("     Number of flies: " + nResults);
		end_of_next_repeat = time_repeat*INTERVAL_TIME*FPS + SECOND_TO_REVIEW*FPS;
		
		if ( end_of_next_repeat < length_of_video && total_time_repeat < NUM_REPEAT_TIME) {
			continue_or_not = 1;
		} 
		if ( end_of_next_repeat > length_of_video || total_time_repeat == NUM_REPEAT_TIME) {
			continue_or_not = 0;
		}
	}
	// check result and edit in here
	
	while (check_result(total_time_repeat)) {
		Dialog.create("Counting again");
		Dialog.addMessage("Number of flies:");
		for (i = 0; i < total_time_repeat; i++) {
			j = i + 1;
			Dialog.addMessage("		Repeat " + j + ": " + number_of_flies_array[i]);
		}
		
		Dialog.addNumber("The repeat time re-counting (1-" + total_time_repeat +")", 1);
		Dialog.show();
		time_repeat_edit = Dialog.getNumber();
		if (time_repeat_edit >0 && time_repeat_edit < (total_time_repeat + 1)) {
	// re-analyse here
			time_to_count = time_push_down_array[time_repeat_edit-1];
			count_time = time_to_count + SECOND_TO_CLIMB;
			if (strain_count != 1) {
			print("     Time push down: " + time_to_count);
			}
			print("     Time to count: " + count_time);
			input_video_analyse(count_time);	
			// Where to analyse
			count_slice = round((nSlices+1)/2);	
			roiManager("select", box_ROIs(time_repeat_edit));
			run("Crop");
			run("Select None");
			roiManager("select", flies_ROIs(time_repeat_edit));
				run("Clear Results");
				run("Set Measurements...", "area area_fraction invert redirect=None decimal=1");
				run("Measure");
				number_of_flies = nResults;
				number_of_flies_array[time_repeat_edit-1] = nResults;
				setTool("multipoint");	
				run("Point Tool...", "type=Dot color=Green size=Small label show counter=0");
				
				waitForUser("Number of flies: " + number_of_flies + "\nADD by Click or REMOVE by Ctrl + Click.\nNote: Slice " + count_slice);
				roiManager("update");
				run("Clear Results");	
				run("Measure");
				number_of_flies = nResults;
				number_of_flies_array[time_repeat_edit-1] = nResults;
	// update data here
		if (VIAL_DIRECTION == "Horizontal") {
			location_result = get_X_result();
			location_result = Array.sort(location_result);
		}
		if (VIAL_DIRECTION == "Vertical") {
			location_result = get_Y_result();
			location_result = Array.sort(location_result);
		}
		selectWindow(name_table);
		Table.setColumn("Repeat " + time_repeat_edit, location_result);	
	}
}
	
	selectWindow(name_table);
	save_name = input_dic + name_table +".csv";
	saveAs("Results", save_name);	
	if (strain_count == NUM_STRAIN) {
	newStrain_or_not = 0;
	}
	roiManager("reset");
}


print("Finish");



// def function 
function input_avi(input_file, begin, end) {
  	run("AVI...", "avi=["+input_file+"] use convert first="+ begin +" last="+end);
}
function clear_everything() { 
	// clear everything 
		run("Clear Results");
		roiManager("reset");
		run("Close All");
		run("Collect Garbage");
}
	
	// function input video
function input_video_review(second) { 
		begin = round(second*FPS);
		end = begin + round(SECOND_TO_REVIEW*FPS);
		input_avi(input_file, begin, end);		
}
	
function input_video_analyse(count_time) {
		frame_to_count = round(count_time*FPS);
		begin = frame_to_count - 50;
		end = frame_to_count + 50;
		input_avi(input_file, begin, end);
}
	
	// function return result in Y location
function get_Y_result() {		
		myArray = newArray(nResults);	
		for ( i=0; i<nResults; i++ ) { 
			a = getResult("Y", i);
			if (TYPE_RESULT == "RANK") {
				b = Math.floor(a/20);
				if (a>= MAX_HEIGHT*10) {
					b = Math.floor(MAX_HEIGHT*10/20);
				}
				myArray[i] = b;
			}
			if (TYPE_RESULT != "RANK") {
				if (a>= MAX_HEIGHT*10) {
					a = MAX_HEIGHT*10;					
				}
				myArray[i] = a;
			}
		}
		return myArray;
}
function get_X_result() {		
		myArray = newArray(nResults);	
		for ( i=0; i<nResults; i++ ) { 
			a = getResult("X", i);
			if (TYPE_RESULT == "RANK") {
				b = Math.floor(a/20);
				if (a>= MAX_HEIGHT*10) {
					b = Math.floor(MAX_HEIGHT*10/20);
				}
				myArray[i] = b;
			}
			if (TYPE_RESULT != "RANK") {
				if (a>= MAX_HEIGHT*10) {
					a = MAX_HEIGHT*10;					
				}
				myArray[i] = a;
			}
		}
		return myArray;
}
	// function ask strain name for save file
	
function ask_new_strain_nanme() {
	Dialog.create("Strain_nane");
	Dialog.addString("Strain_name:", "");
	Dialog.show();
	name= Dialog.getString();
	return name;	
}

function recent_ROIs() {
	n = roiManager("count") -1;
	return n
}
function flies_ROIs(time_repeat) {
	ROIs_name = time_repeat*2-1;
	return ROIs_name
}
function box_ROIs(time_repeat) {
	ROIs_name = (time_repeat-1)*2;
	return ROIs_name
}
function check_result(total_time_repeat) {
	result_check = 0;
	for (i = 0; i < total_time_repeat; i++) {
		for (j = 0; j < total_time_repeat; j++) {
			if (number_of_flies_array[i] != number_of_flies_array[j]) {
				result_check = 1;
			}
		}
	}
	return result_check
}
function get_loc() {
	if (VIAL_DIRECTION == "Horizontal") {
			location_result = get_X_result();
			location_result = Array.sort(location_result);
		}
	if (VIAL_DIRECTION == "Vertical") {
			location_result = get_Y_result();
			location_result = Array.sort(location_result);
		}
	return location_result
}
function ask_time(repeat_time) {
	count_list = newArray("1st", "2nd", "3rd","4th","5th","6th","7th","8th","9th","10th");
	Dialog.create("Time begin push down");
	Dialog.addNumber(count_list[repeat_time], INTERVAL_ARRAY[repeat_time]);
	Dialog.show();
	time= Dialog.getNumber();
	return time;	
}




