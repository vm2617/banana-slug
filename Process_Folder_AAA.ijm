/*
 * Macro template to process multiple images in a folder
 */

//~USER INPUT~
//input_dir must be a directory containing images of either flash responses or grating responses
input_dir = "D:/Image_files/Tm3_ER210+RGECO/moving_light_bars/medulla/"; 
//output_dir must be a 'grating' or 'flashes' folder 
output_dir = "C:/Users/vymak_i7/Desktop/New_ER/Screen/Tm3/moving_light_bars/medulla/" 
//target_channel must be either 'ER210' or 'RGECO'
target_channel = "RGECO"
//press Ctrl+R to run the entire code 

//set global variable (counter) to 0 outside of macro; this is target_list's counter for processFolder macro
var counter=0
//run Macro
processFolder(input_dir, output_dir, target_channel);

// function to scan folders/subfolders/files to find files with correct suffix
function processFolder(input, output, channel) {
	//list files in your input and output directories
	source_list = getFileList(input);
	source_list = Array.sort(source_list);
	target_list = getFileList(output);
	target_list = Array.sort(target_list);
	//run the AAA code for ea/ .tif file in your input directory 
	for (i = 0; i < source_list.length; i++) {
		if (endsWith(source_list[i], "/")){
	    	print((counter+1) + ") " + source_list[i]); 
	    	print("Processing: " + input+source_list[i]);
	    	print("Saving to: " + output+target_list[counter]);
	    	Align_Apply_Align(input+source_list[i], output+target_list[counter], channel); 
	    	counter++; //counter++ -> counter = counter + 1
	    }
	    else {
	    	print("Current file "+input+source_list[i]+" is not a folder.");
	    	debug("break");
	    }
	}
}

function Align_Apply_Align(source_dir, target_dir, Channel_A) {
//(Section 1) OPEN SELECTED IMAGE & AVERAGE PIXEL INTENSITY OF CHANNEL W/ STRONGEST SIGNAL
	//open raw image data
	open(source_dir+"ER210.tif");
	open(source_dir+"RGECO.tif");
	if(Channel_A=="ER210"){
		Channel_B = "RGECO";
		rename(Channel_B+"_Raw");
		run("Put Behind [tab]");
		rename(Channel_A+"_Raw");
	}
	else if(Channel_A=="RGECO"){
		rename(Channel_A+"_Raw");
		Channel_B = "ER210";
		run("Put Behind [tab]");
		rename(Channel_B+"_Raw");
	}
	//compute average pixel intensity of Channel_A video, output window is titled 'AVG_A_Raw'
	selectWindow(Channel_A+"_Raw");
	run("Z Project...", "projection=[Average Intensity]"); 
	
//(Section 2) ALIGN FIRST CHANNEL W/ STRONGEST SIGNAL (for TurboReg instructions, visit this website: http://bigwww.epfl.ch/thevenaz/turboreg/)
	setBatchMode(true); //true -> hides newly opened images; streamlines TurboReg more quickly
	//create a registered Channel_A window
	selectWindow(Channel_A+"_Raw");
	setSlice(1); 
	run("Duplicate...", "title=currentFrame");
	width = getWidth();
	height = getHeight();
	run("TurboReg ","-align " 
		 + "-window currentFrame 0 0 "+(width-1)+" "+(height-1)+" "
		 + "-window AVG_"+Channel_A+"_Raw 0 0 "+(width-1)+ " "+(height-1)+" "
		 + "-rigidBody "
		 + (width/2)+" "+(height/2)+" "+(width/2)+" "+(height/2)+" "//1st landmarks of source & target (gives overall translation)
		 + (width/2)+" "+round(0.15625*height)+" "+(width/2)+" "+round(0.15625*height)+" "//2nd landmarks of source & target (determines rotation angle)
		 + (width/2)+" "+round(0.84375*height)+" "+(width/2)+" "+round(0.84375*height)+" "//3rd landmarks of source & target (determines rotation angle)
		 + "-showOutput"); //"showOutput" in TurboReg triggers "Refined Landmarks" and "Log" windows
	selectWindow("Output"); //output = 2 sequential images for each frame in 'Channel_A': (1) raw data; (2) mask/black background
	setSlice(2); 
	run("Delete Slice"); //delete mask/black background frame, which is the 2nd frame of the output window
	run("Duplicate...", "title=Registered_"+Channel_A); 
	selectWindow("Output");
	close(); 
	selectWindow("currentFrame");
	close();
	//calculate alignment values of Channel A [first frame]
	sourceX0 = getResult("sourceX", 0); // First line of the "Refined Landmarks" table.
	sourceY0 = getResult("sourceY", 0);
	targetX0 = getResult("targetX", 0);
	targetY0 = getResult("targetY", 0);
	sourceX1 = getResult("sourceX", 1); // Second line of the "Refined Landmarks" table.
	sourceY1 = getResult("sourceY", 1);
	targetX1 = getResult("targetX", 1);
	targetY1 = getResult("targetY", 1);
	sourceX2 = getResult("sourceX", 2); // Third line of the "Refined Landmarks" table.
	sourceY2 = getResult("sourceY", 2);
	targetX2 = getResult("targetX", 2);
	targetY2 = getResult("targetY", 2);
	tdx = targetX0 - sourceX0; // translated offset of x-coordinate
	tdy = targetY0 - sourceY0; // translated offset of y-coordinate
	//calculate rotation offset
	dx = sourceX2 - sourceX1;
	dy = sourceY2 - sourceY1;
	sourceAngle = atan2(dy, dx);
	dx = targetX2 - targetX1;
	dy = targetY2 - targetY1;
	targetAngle = atan2(dy, dx);
	rotation = (targetAngle - sourceAngle)*(180.0/ PI); //rotation offset in degrees
	//create an array containing x offset, y offset, and rotation values of the first frame of Channel A
	source_array = newArray(tdx,tdy,rotation); 
	
	//Calculate alignment of entire Channel_A window
	selectWindow(Channel_A+"_Raw");
	for (i=2; i<=nSlices; i++) { //nSlices = total number of frames in selected Window
		setSlice(i);
		run("Duplicate...", "title=currentFrame"); 
		width = getWidth();
		height = getHeight();
		run("TurboReg ","-align " 
			 + "-window currentFrame 0 0 "+(width-1)+" "+(height-1)+" "
			 + "-window AVG_"+Channel_A+"_Raw 0 0 "+(width-1)+ " "+(height-1)+" "
			 + "-rigidBody "
			 + (width/2)+" "+(height/2)+" "+(width/2)+" "+(height/2)+" "//1st landmarks of source & target (gives overall translation)
			 + (width/2)+" "+round(0.15625*height)+" "+(width/2)+" "+round(0.15625*height)+" "//2nd landmarks of source & target (determines rotation angle)
			 + (width/2)+" "+round(0.84375*height)+" "+(width/2)+" "+round(0.84375*height)+" "//3rd landmarks of source & target (determines rotation angle)
			 + "-showOutput"); //"showOutput" in TurboReg triggers "Refined Landmarks" and "Log" windows
		selectWindow("Output"); //output = 2 sequential images for each frame in 'Channel_A': (1) raw data; (2) mask/black background
		setSlice(2); 
		run("Delete Slice"); //delete mask/black background frame, which is the 2nd frame of the output window
		run("Concatenate...", " title='Registered_"+Channel_A+"' image1='Registered_"+Channel_A+"' image2=Output image3=[-- None --]");
		selectWindow("currentFrame");
		close();
	//Alignment Calculations
		sourceX0 = getResult("sourceX", 0); // First line of the "Refined Landmarks" table.
		sourceY0 = getResult("sourceY", 0);
		targetX0 = getResult("targetX", 0);
		targetY0 = getResult("targetY", 0);
		sourceX1 = getResult("sourceX", 1); // Second line of the "Refined Landmarks" table.
		sourceY1 = getResult("sourceY", 1);
		targetX1 = getResult("targetX", 1);
		targetY1 = getResult("targetY", 1);
		sourceX2 = getResult("sourceX", 2); // Third line of the "Refined Landmarks" table.
		sourceY2 = getResult("sourceY", 2);
		targetX2 = getResult("targetX", 2);
		targetY2 = getResult("targetY", 2);
		tdx = targetX0 - sourceX0; // translated offset of x-coordinate
		tdy = targetY0 - sourceY0; // translated offset of y-coordinate
		//calculate rotation offset
		dx = sourceX2 - sourceX1;
		dy = sourceY2 - sourceY1;
		sourceAngle = atan2(dy, dx);
		dx = targetX2 - targetX1;
		dy = targetY2 - targetY1;
		targetAngle = atan2(dy, dx);
		rotation = (targetAngle - sourceAngle)*(180.0/ PI); //rotation offset in degrees
		//extract 3 values: x offset, y offset, and rotation offset
		fin_array = newArray(tdx,tdy,rotation); 
		//add aforementioned values to existing array of alignment calculations
		source_array = Array.concat(source_array,fin_array);
		selectWindow(Channel_A+"_Raw");
	} 
	selectWindow("AVG_"+Channel_A+"_Raw");
	close();
	//Registered_A image sequence is too bright; must align raw Channel A window instead
	selectWindow("Registered_"+Channel_A);
	close();
	//create an aligned Channel A window
	selectWindow(Channel_A+"_Raw");
	for (i = 1; i<=nSlices; i++) {
		setSlice(i);
		x_offset = source_array[3*i-3];
		y_offset = source_array[3*i-2];
		rotation_angle = source_array[3*i-1];
		run("Translate...", "x="+x_offset+" y="+y_offset+" interpolation=None");
		run("Rotate... ", "angle="+rotation_angle+" grid=1 interpolation=None");
	}
	selectWindow(Channel_A+"_Raw"); 
	rename(Channel_A+"_Aligned");

//(Section 3) ALIGN SECOND CHANNEL W/ ALIGNMENT CALCULATIONS OF FIRST CHANNEL
	selectWindow(Channel_B+"_Raw");
	//create an aligned Channel B window
	for (i = 1; i<=nSlices; i++) {
		setSlice(i);
		x_offset = source_array[3*i-3];
		y_offset = source_array[3*i-2];
		rotation_angle = source_array[3*i-1];
		run("Translate...", "x="+x_offset+" y="+y_offset+" interpolation=None");
		run("Rotate... ", "angle="+rotation_angle+" grid=1 interpolation=None");
	}
	selectWindow(Channel_B+"_Raw"); 
	rename(Channel_B+"_Aligned");

//(Section 4) SAVE ENTIRE IMAGE SEQUENCE OF FIRST CHANNEL
	selectWindow(Channel_A+"_Aligned");
	//convert 32-bit data into 8-bit 
	run("8-bit");
	//create folder for saving Channel A's image sequence into
	File.makeDirectory(target_dir+File.separator+Channel_A); 
	//hide images produced by 'for' loop for faster results
	for (i = 1; i <= nSlices; i++) {
		setSlice(i);
		//Saving images 0000 to 0009
		if (i<=10){
			run("Duplicate...","title="+Channel_A+"-000"+(i-1));
			saveAs("Tiff", target_dir+File.separator+Channel_A+File.separator+"000"+(i-1)+".tif"); 
		}
		//Saving images 0010 to 0099
		else if (i>10 && i<=100) {
			run("Duplicate...","title="+Channel_A+"-00"+(i-1));
			saveAs("Tiff", target_dir+File.separator+Channel_A+File.separator+"00"+(i-1)+".tif");
		}
		//Saving images 0100 to 0999
		else if (i>100 && i<=1000){
			run("Duplicate...","title="+Channel_A+"-0"+(i-1));
			saveAs("Tiff", target_dir+File.separator+Channel_A+File.separator+"0"+(i-1)+".tif");
		}
		//Saving images 1000 to 9999
		else if (i>1000){
			run("Duplicate...","title="+Channel_A+"-"+(i-1));
			saveAs("Tiff", target_dir+File.separator+Channel_A+File.separator+(i-1)+".tif");
		}
		close();
		selectWindow(Channel_A+"_Aligned");
	}
	//exit batch mode

//(Section 5) SAVE ENTIRE IMAGE SEQUENCE OF SECOND CHANNEL
	selectWindow(Channel_B+"_Aligned");
	//convert 32-bit data into 8-bit
	run("8-bit");
	//create folder for saving Channel B's image sequence into
	File.makeDirectory(target_dir+File.separator+Channel_B); 
	//hide images produced by 'for' loop for faster results
	for (i = 1; i <= nSlices; i++) {
		setSlice(i);
		//Saving images 0000 to 0009
		if (i<=10){
			run("Duplicate...","title="+Channel_B+"-000"+(i-1));
			saveAs("Tiff", target_dir+File.separator+Channel_B+File.separator+"000"+(i-1)+".tif"); 
		}
		//Saving images 0010 to 0099
		else if (i>10 && i<=100) {
			run("Duplicate...","title="+Channel_B+"-00"+(i-1));
			saveAs("Tiff", target_dir+File.separator+Channel_B+File.separator+"00"+(i-1)+".tif");
		}
		//Saving images 0100 to 0999
		else if (i>100 && i<=1000){
			run("Duplicate...","title="+Channel_B+"-0"+(i-1));
			saveAs("Tiff", target_dir+File.separator+Channel_B+File.separator+"0"+(i-1)+".tif");
		}
		//Saving images 1000 to 9999
		else if (i>1000){
			run("Duplicate...","title="+Channel_B+"-"+(i-1));
			saveAs("Tiff", target_dir+File.separator+Channel_B+File.separator+(i-1)+".tif");
		}
		close();
		selectWindow(Channel_B+"_Aligned");
	}
	//exit batch mode
	setBatchMode(false);

//(Section 6) MAKE DIRECTORES FOR PLOTS & MEASUREMENTS
//	File.makeDirectory(target_dir+File.separator+"binned_images-ER210");
//	File.makeDirectory(target_dir+File.separator+"binned_images-RGECO");
	File.makeDirectory(target_dir+File.separator+"plots");
	File.makeDirectory(target_dir+File.separator+"measurements");

//(Section 7) SAVE AVERAGE PROJECTION OF TWO ALIGNED CHANNELS
	//concatenate the two aligned 8-bit videos, output will be 'Untitled' window
	run("Concatenate...", "  image1='"+Channel_A+"_Aligned' " 
		+ "image2='"+Channel_B+"_Aligned'"); 
	//retreive and save average pixel intensity of the entire concatenated registered data
	run("Z Project...", "projection=[Average Intensity]"); 
	saveAs("Tiff", target_dir+File.separator+"average_projection.tif"); 
	//EXIT ALL IMAGE WINDOWS
	run("Close All");
}
 