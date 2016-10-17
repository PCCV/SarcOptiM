/*//////////////////////////////////////////////////////////////////////
// SarcOptiM - High Frequency Online Sarcomere Length Measurement V1.1
// Author: Côme PASQUALIN, François GANNIER
//
// Signalisation et Transport Ionique (STIM)
// CNRS ERL 7368, Groupe PCCV - Université de Tours
//
// Report bugs to authors
// come.pasqualin@gmail.com
// gannier@univ-tours.fr
//
//  This file is part of SarcOptiM.
//  Copyright 2015-2016 Côme PASQUALIN, François GANNIER	
//
//  SarcOptiM is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  SarcOptiM is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with SarcOptiM.  If not, see <http://www.gnu.org/licenses/>.
////////////////////////////////////////////////////////////////// */

var Debug = 0 ;

/*	TIPS
	openning AVI
		if 8-bits check "convert to grayscale"
		if speed of analysis is a priority uncheck "Use virtual stack"
		if speed of openning is a priority or file is big check "Use virtual stack"
*/

macro "Calibration Action Tool - C000D12D1aD1bD1cD1dD1eD21D22D23D24D25D26D2cD3cD4cD54D55D56D5cD66D6cD74D75D76D7cD8cD95D96D9cDa4DacDb5Db6DbcDc4DccDd5Dd6DdcDeaDebDecDedDeeC000C111D57D58D59C111C222C333C444C555C666C777C888C999CaaaCbbbCcccCdddCeeeCfff" {
	TPIX = call("ij.Prefs.get", "SarcOptix.VideoCalibPixSiz",0);
	Dialog.create("Calibration");
		// Dialog.addMessage("Pixel size was: "+TPIX+" "+fromCharCode(0x00B5)+"m");
	if (TPIX != 0)
		Dialog.addNumber("Pixel size was: ", TPIX, 4, 6, ""+fromCharCode(0x00B5)+"m");
	else Dialog.addNumber("Pixel size: ", 0, 4, 6, ""+fromCharCode(0x00B5)+"m");
	items = newArray(" Use above calibration", " New calibration line (line length below)");
	Dialog.addRadioButtonGroup("Choose: ", items, 2, 1, items[0]);
	Dialog.addNumber("Line length ", 100, 2, 6, ""+fromCharCode(0x00B5)+"m");
	Dialog.addMessage("Copyright@2015-2016 F.GANNIER - C.PASQUALIN");
	Dialog.show();
	TPIX = Dialog.getNumber();
	chargerCalib = Dialog.getRadioButton();
	CalTool = Dialog.getNumber();
	if (chargerCalib == items[0]) {
		run("Properties...", "unit=um pixel_width="+TPIX+" pixel_height="+TPIX+"");
	} else {
		run("Line Width...", "line=1"); setTool("line");
		getLine(x1, y1, x2, y2, lineWidth);
		while (x1 == -1) {
			waitForUser( "Calibration","Please draw a line corresponding to "+CalTool+" "+fromCharCode(0x00B5)+"m and then click OK");
			getLine(x1, y1, x2, y2, lineWidth);
		}
		lineLength = sqrt (((y2-y1)*(y2-y1))+((x2-x1)*(x2-x1)));
		TPIX = CalTool / lineLength;
		run("Properties...", "unit=um pixel_width="+TPIX+" pixel_height="+TPIX+"");
	}
	call("ij.Prefs.set", "SarcOptix.VideoCalibPixSiz",TPIX);
}

macro "Online_FFT_spectrum Action Tool - C000C111D0dD1dD2cD2dD3aD3bD3cD3dD47D48D49D4aD4bD4cD4dD50D51D52D53D54D55D56D57D58D59D5aD5bD5cD5dD65D66D67D68D69D6aD6bD6cD6dD79D7aD7bD7cD7dD8bD8cD8dD9cD9dDadDbdDcdDddDedDfdC111C222C333C444C555C666C777C888C999CaaaCbbbCcccCdddCeeeCfff" {
	
	requires("1.49v");

	xCumul = 3;
	Nframes = 0;
	ScH = screenHeight;
	ScW = screenWidth;
	
	if ( !startsWith(getInfo("window.type"), "Image"))
			exit("<html>"
			 +"<h1>SarcOptiM</h1>"
			 +"<u>Warning:</u> Selected window is not an image !"
			 +"<ul>"
			 +"<li>tip: SarcOptiM works only on calibrated images"
			 +"</ul>");
			 
	img = getTitle();
	if (startsWith(img, "FFT Spectrum"))
		showMessageWithCancel("Are you sure ?","Selected image seems to be FFT Spectrum! continue ?");	
	SLmin = parseFloat(call("ij.Prefs.get", "OVA.SLmin","1.2"));
	SLmax = parseFloat(call("ij.Prefs.get", "OVA.SLmax","2.1"));

	getDimensions(largeur, hauteur, channels, slices, frames);
	getPixelSize(unit, pixelW, pixelH);
	if (unit=="pixels") 
		exit("<html>"
			 +"<h1>SarcOptiM</h1>"
			 +"<u>Warning:</u> Video doesn't seem to be calibrated!"
			 +"<ul>"
			 +"<li>tip: use <b>Ctl-Maj-P</b> or calibration button"
			 +"</ul>");
	factor=1;
	if (unit=="nm") { factor = 0.001;	unit = fromCharCode(0x00B5)+"m"; }
	if (unit=="cm") { factor = 10000;	unit = fromCharCode(0x00B5)+"m"; }
	if (unit=="mm") { factor = 1000;	unit = fromCharCode(0x00B5)+"m"; }
	
	pixelW = roundn(pixelW, 7)*factor;
	pixelH = roundn(pixelH, 7)*factor;
	videoid = getImageID();

	var VFreq=false;
	if (call("ij.Prefs.get", "OVA.VFreq","false")=="true") VFreq = true;
	TimeOut =  parseFloat(call("ij.Prefs.get", "OFS.TO","10"));
	Dialog.create("On-line video FFT"); {
		Dialog.addNumber("Min Sarcomere length ("+fromCharCode(0x00B5)+"m)", SLmin);
		Dialog.addNumber("Max Sarcomere length ("+fromCharCode(0x00B5)+"m)", SLmax);
		Dialog.addCheckbox("Limit to Video Freq.", VFreq);
		Dialog.addNumber("VFreq time out (ms)",TimeOut);
		Dialog.addMessage("WARNING:\nTo avoid Java error, DO NOT RESIZE the\nFFT Spectrum window during acquisition.");
		Dialog.addHelp("http://pccv.univ-tours.fr/ImageJ/SarcOptiM/Online.html");
		Dialog.addMessage("Copyright@2015-2016 F.GANNIER - C.PASQUALIN");
		Dialog.show();
		SLmin = Dialog.getNumber();
		SLmax = Dialog.getNumber();
		VFreq = Dialog.getCheckbox();
		TimeOut = Dialog.getNumber();
		
		OVA = "false"; if (VFreq) OVA = "true";
		call("ij.Prefs.set", "OVA.VFreq",OVA);
		call("ij.Prefs.set", "OFS.TO",toString(TimeOut));
		call("ij.Prefs.set", "OVA.SLmin",toString(SLmin));
		call("ij.Prefs.set", "OVA.SLmax",toString(SLmax));
	}
	
	LineLengthForCell = getCellLine("Cell Selection", videoid);
	puis2 = Puis2_fft(LineLengthForCell,LineLengthForCell);
	fftwin = pow(2,puis2);
	xmin = Posdansfft(fftwin,pixelW,SLmin);
	xmax = Posdansfft(fftwin,pixelW,SLmax);
	FRtab = newArray(10);
	HRTimeOut = TimeOut*1000;
	HRwait = 250;
	zoom = 1;
	xCumul = 3;
	if (isOpen(videoid)) {
		selectImage(videoid);
		profile = getProfile();
		fftprofile = Array.fourier(profile, "Hann");
		ZoneiFFTprofile = Array.slice(fftprofile,xmax,xmin);
		Array.getStatistics(ZoneiFFTprofile, Zimin, Zimax, Zimean, ZistdDev);
		PositionDuMax = Array.findMaxima(ZoneiFFTprofile, Zimax-Zimean);
		if (PositionDuMax.length > 0) { 
			PDM = PositionDuMax[0];
			zoom = ZoneiFFTprofile[PDM] / 200;
		}
	}
	nomW = "FFT Spectrum of "+img;
	// call("ij.gui.ImageWindow.setNextLocation", 0, ScH-382)
	newTime = parseInt(call("HRtime.gettime"));
	lastTime = newTime;
	Plot.create(nomW, "Spatial Freq.", "Energy (UA)");
	Plot.show();
	plotid = getImageID();
	while (!isKeyDown("space")) {
	temps = parseInt(call("HRtime.gettime"));
		if (VFreq) {
			while (call("ij.Prefs.get", "Cam.newImage","false") == "false") {
				temps = parseInt(call("HRtime.sleep",d2s(temps,16), d2s(HRwait,16)));
				if ((temps - newTime) >= HRTimeOut) break;
			}
			call("ij.Prefs.set", "Cam.newImage","false");
		} else if (HRTimeOut > 0) {
			temps = parseInt(call("HRtime.sleep",d2s(temps,16), d2s((HRTimeOut - (temps - newTime)),16)));
		}

		lastTime = newTime;
		newTime = temps;
		laps = (newTime - lastTime)/1000.0;
 
		if (!isOpen(videoid)) 	break;
		if (!isOpen(plotid)) break;
 setBatchMode(true);
		selectImage(videoid);
		type = selectionType();
		if (type < 0) { showMessage("WARNING", "No more selected line,\n process halted!"); break;}
		profile = getProfile();
		fftprofile = Array.fourier(profile, "Hann");
		ZoneiFFTprofile = Array.slice(fftprofile,xmax,xmin);
		Array.getStatistics(ZoneiFFTprofile, Zimin, Zimax, Zimean, ZistdDev);
		PositionDuMax = Array.findMaxima(ZoneiFFTprofile, Zimax-Zimean);
		if (PositionDuMax.length < 1) { showStatus("Warning: No peak found, check calibration - press SPACE to halt"); continue; }
		PDM = PositionDuMax[0]; 
		XMax = xmax+PDM;
		if (PDM >= xCumul && PDM < lengthOf(ZoneiFFTprofile)-xCumul )
		{
			cumul1 = 0; cumul2 = 0;
			for(ii=-xCumul;ii<xCumul;ii++)
			{
				cumul1 += (ZoneiFFTprofile[PDM+ii]);
				cumul2 += (ZoneiFFTprofile[PDM+ii]*(XMax+ii));
			}
			rapport = cumul2 / cumul1;
			SLtemp = pixelW*fftwin/(rapport);
		} else 
		{
			SLtemp = pixelW*fftwin/(xmax+PDM);
		}

		if (isKeyDown("shift"))
			if (is("Caps Lock Set"))
				zoom*=1.2;
			else 
				zoom/=1.2;

		frameRate = 1 / laps;
		FRtab[Nframes % 10] = frameRate;

		ecart += laps;
		if (ecart > 50) {
			Plot.create(nomW, "Spatial Freq.", "Energy (UA)");
			zz = zoom*200;
			Plot.setLimits(0, fftwin/2-1, 0, zz);
			Plot.add("lines", fftprofile);

			Plot.setColor("red");
			Plot.drawLine(xmax, 0, xmax, zz);
			Plot.drawLine(xmin, 0, xmin, zz);
			
			Plot.update();
			totalFR = FRtab[0];
			for(ii=1; ii <10; ii++)	totalFR += FRtab[ii];
			st = "FR : " + d2s(totalFR * 100,1) + " fps ";
			st += "SL : " + d2s(SLtemp,2) + "um ";
			st += " SPACE to stop";
			showStatus(st);
			ecart = 0;
		}
setBatchMode(false);
		Nframes++;
	}
	showStatus("Online FFT Spectrum stopped");
}

macro "Online_Video_Ana Action Tool - C000C111D00D01D02D03D04D05D06D07D08D09D0aD0bD0cD0dD0eD0fD12D18D1eD22D28D2eD30D31D32D33D34D35D36D37D38D39D3aD3bD3cD3dD3eD3fD40D4cD50D53D54D5cD60D62D65D6cD70D73D74D7cD80D86D87D88D89D8aD8cD90D9aD9cDa0DaaDacDb0DbcDc0Dc1Dc2Dc3Dc4Dc5Dc6Dc7Dc8Dc9DcaDcbDccDcdDceDcfDd2Dd8DdeDe2De8DeeDf0Df1Df2Df3Df4Df5Df6Df7Df8Df9DfaDfbDfcDfdDfeDffC111C222C333C444C555C666C777C888C999CaaaCbbbCcccCdddCeeeCfff" {
	requires("1.49v");
	
	if ( !startsWith(getInfo("window.type"), "Image"))
			exit("<html>"
			 +"<h1>SarcOptiM</h1>"
			 +"<u>Warning:</u> Selected window is not an image !"
			 +"<ul>"
			 +"<li>tip: SarcOptiM works only on calibrated images"
			 +"</ul>");
	 
	img = getTitle();
	id = getImageID();
	if (startsWith(img, "FFT Spectrum"))
		showMessageWithCancel("Are you sure ?","Selected image seems to be FFT Spectrum! continue ?");			
	getPixelSize(unit, pixelW, pixelH);
	if (unit=="pixels") 
		exit("<html>"
			 +"<h1>SarcOptiM</h1>"
			 +"<u>Warning:</u> Video doesn't seem to be calibrated!"
			 +"<ul>"
			 +"<li>tip: use <b>Ctl-Maj-P</b> or calibration button"
			 +"</ul>");
	type = selectionType();
	if (type != 5) {
		run("Select None");
		getCellLine("Cell Selection", id);
	}
	run("FFT OnLine");
}

macro "Offline Video_Ana Action Tool - C953T0a08AT8a08VTga08I" {
	requires("1.49v");
	
	ScH = screenHeight; 	ScW = screenWidth;
	var largeur; var hauteur; var unit; var nom; var nom_ori; var fftwin;	var pixelW; var pixelH; var Nbits;
	var channels;  var sensispe; var fps; var slices; var LLFCx1; var LLFCy1; var LLFCx2; var LLFCy2; var LLFClineWidth;

	if ( !startsWith(getInfo("window.type"), "Image"))
			exit("<html>"
			 +"<h1>SarcOptiM</h1>"
			 +"<u>Warning:</u> Selected window is not an image !"
			 +"<ul>"
			 +"<li>tip: SarcOptiM works only on calibrated images"
			 +"</ul>");

	nom_ori = getTitle();
	videoid = getImageID();
	if (startsWith(nom_ori, "FFT Spectrum"))
		showMessageWithCancel("Are you sure ?","Selected image seems to be FFT Spectrum! continue ?");	
	
	getDimensions(largeur, hauteur, channels, slices, frames);
	FI = Stack.getFrameInterval();
	if (FI==0)
		fps = Stack.getFrameRate();
	if (frames>1)
		if (FI==0)
			exit("<html>"
			 +"<h1>SarcOptiM</h1>"
			 +"<u>Warning:</u> Frames found but frame interval is 0 !"
			 +"<ul>"
			 +"<li>tip: use <b>Ctl-Maj-P</b> to correct"
			 +"</ul>");
	if (fps==0 && FI>0)	
		fps=1/FI;	
	if (fps==0)
		exit("<html>"
			 +"<h1>SarcOptiM</h1>"
			 +"<u>Warning:</u> framerate is 0 fps !"
			 +"<ul>"
			 +"<li>tip: use <b>Ctl-Maj-P</b> to correct"
			 +"</ul>");
		
	getPixelSize(unit, pixelW, pixelH);
	if (unit=="pixels") 
		exit("<html>"
			 +"<h1>SarcOptiM</h1>"
			 +"<u>Warning:</u> Video doesn't seem to be calibrated!"
			 +"<ul>"
			 +"<li>tip: use <b>Ctl-Maj-P</b> or calibration button"
			 +"</ul>");

	InfMess = call("ij.Prefs.get", "SCOPTM.InfMess",0);
	if (!InfMess)
		if (is("Virtual Stack"))
			showMessage("Information","<html>"
				+"<h1>SarcOptiM</h1>"
				+"<u>Warning:</u> this video is loaded with <b>virtual stack</b> enabled.<br> Videos are loaded faster but analysis with SarcOptiM will be  slower."
				+"<ul>"
				+"<li>tip: Use menu <b>Image\\type\\8-bit\</b> or uncheck <b>Use virtual stack</b> when opening a video."
				+"<li>The better is opening a video with <b>Convert to Grayscale</b> checked and <b>Use virtual stack</b> unchecked."
				+"</ul>"
				+"<center><b>ESC</b> to quit, <b>OK/Enter</b> to continue</center>");

	factor=1;
	if (unit=="nm") { factor = 0.001;	unit = fromCharCode(0x00B5)+"m"; }
	if (unit=="cm") { factor = 10000;	unit = fromCharCode(0x00B5)+"m"; }
	if (unit=="mm") { factor = 1000;	unit = fromCharCode(0x00B5)+"m"; }
	
	pixelW = roundn(pixelW, 7)*factor;
	pixelH = roundn(pixelH, 7)*factor;
	
	Nbits = bitDepth();
	getLine(tex1, tey1, tex2, tey2, telineWidth); 
	dx = tex2-tex1;
	Dialog.create("Analysis Parameters"); {
		items = newArray("Cell axis", "Entire image");
		if (dx != 0) Dialog.addRadioButtonGroup("Analysis mode:", items, 2, 1, "Cell axis");
		else Dialog.addRadioButtonGroup("Analyses mode:", items, 2, 1, "Entire image");
		Dialog.addMessage("Analysis parameters: ");
		Dialog.addNumber("Min Sarcomere length ("+fromCharCode(0x00B5)+"m)", 1.2);
		Dialog.addNumber("Max Sarcomere length ("+fromCharCode(0x00B5)+"m)", 2.2);
		Dialog.addMessage("----------INFORMATION ABOUT VIDEO----------");
		Dialog.addMessage("title: "+nom_ori);
		Dialog.addMessage("pixel size: "+pixelW+" "+unit);
		Dialog.addMessage("frame rate: "+fps+" fps");
		Dialog.addCheckbox("Do not warn about \"virtual stack videos\"", InfMess);
		Dialog.addHelp("http://pccv.univ-tours.fr/ImageJ/SarcOptiM/Online.html");
		Dialog.addMessage("Copyright@2015-2016 F.GANNIER - C.PASQUALIN");
		Dialog.show();
		AnalyseType = Dialog.getRadioButton;
		SLmin = Dialog.getNumber();
		SLmax = Dialog.getNumber();
		InfMess = Dialog.getCheckbox();
		call("ij.Prefs.set", "SCOPTM.InfMess",InfMess);
		DispAna = 0;
		highRes = 1;
		sarcomo = 0;
		SLpreci = 0;
	}
	if (!DispAna) setBatchMode(true);

	tpsimg = 1 / fps;
	time = newArray(slices);
	for (i=0; i<slices; i++) time[i] = (i)*tpsimg;

	SL = newArray(slices);
	if (sarcomo) SH = newArray(slices);
	if (SLpreci){
		SLPRMax = newArray(slices);
		SLPRMin = newArray(slices);
	}
	if (AnalyseType=="Cell axis") {
		selectWindow(nom_ori);
		LineLengthForCell = getCellLine("Cell Selection", videoid);
		getLine(LLFCx1, LLFCy1, LLFCx2, LLFCy2, LLFClineWidth);
		puis2 = Puis2_fft(LineLengthForCell,LineLengthForCell);
		fftwin = pow(2,puis2);
		xmin = Posdansfft(fftwin,pixelW,SLmin)+3;
		xmax = Posdansfft(fftwin,pixelW,SLmax)-3;
		xCumul = 3;

		for (i=1; i<=slices; i++) {
			if (!isOpen(nom_ori)) 	break;
			selectWindow(nom_ori);
			setSlice(i);
			makeLine(LLFCx1, LLFCy1, LLFCx2, LLFCy2);
			profile = getProfile();
			fftprofile = Array.fourier(profile, "Hann");
			ZoneiFFTprofile = Array.slice(fftprofile,xmax,xmin);
			Array.getStatistics(ZoneiFFTprofile, Zimin, Zimax, Zimean, ZistdDev);
			Zi=0;
			PositionDuMax = Array.findMaxima(ZoneiFFTprofile, Zimax-Zimean);
			while ((PositionDuMax.length <= 0) && ((Zimax-Zimean-Zi) > 2)) {
				PositionDuMax = Array.findMaxima(ZoneiFFTprofile, Zimax-Zimean-Zi);
				Zi = Zi + 1;
			}
			if (PositionDuMax.length < 1) { beep(); IJ.log("error"); showStatus("Error : press SPACE"); continue; }
			PDM = PositionDuMax[0];
			ValeurDuMax = ZoneiFFTprofile[PDM];
			SL[i-1] = calcOptmizedSL(PDM, 8);
			if (sarcomo) SH[i-1] = ValeurDuMax;
			if (SLpreci) {
				SLPRMax[i-1] = pixelW*fftwin/(xmax+PDM+1);
				SLPRMin[i-1] = pixelW*fftwin/(xmax+PDM-1);
			}
		}
	} else {
		puis2 = Puis2_fft(largeur,hauteur);
		fftwin = pow(2,puis2);
		xmin = Posdansfft(fftwin,pixelH,SLmin);
		xmax = Posdansfft(fftwin,pixelH,SLmax); //CP
		nom = "hanning";
		newImage(nom, Nbits+"-bit black", fftwin, fftwin, 1);
		Hanning_name = Hanning_window(fftwin);
		run("Line Width...", "line=5");
		for (i=1; i<=slices; i++) {
			if (!isOpen(nom_ori)) 	break;
			selectWindow(nom_ori);
			setSlice(i);
			run("Select All");  run("Copy");
			selectWindow(nom);
			run("Paste");
			imageCalculator("Multiply create 32-bit", nom, Hanning_name);
			newname = getTitle();
			run(8+"-bit");
			run("FFT");
			run("Subtract Background...", "rolling=30 sliding");
			run("Enhance Contrast...", "saturated=0.1");
			tor(fftwin/2-xmin,fftwin/2-xmin,xmin*2,fftwin/2-xmax,fftwin/2-xmax,xmax*2);
			getStatistics(TORarea, TORmean, TORmin, TORmax, TORstd, TORhistogram);
			sensispe = floor(TORmax-TORmean);
			if (isNaN(sensispe)) waitForUser("Analysis failed. Please press 'Escape' and check video calibration");
 			run("Find Maxima...", "noise="+sensispe+" output=[Point Selection]");
			getSelectionCoordinates(xx, yy);
			while ( selectionType() != 10) {
				sensispe -= 4;
				if (sensispe <= 1) { beep(); IJ.log("error"); continue; }
				tor(fftwin/2-xmin,fftwin/2-xmin,xmin*2,fftwin/2-xmax,fftwin/2-xmax,xmax*2);				
				run("Find Maxima...", "noise="+sensispe+" output=[Point Selection]");
				getSelectionCoordinates(xx, yy);
			}
			x = xx[0]; y = yy[0];
			if (sarcomo) sh = SarcoH(x,y);
			MAX=1; MIN=-1;
			if (SLpreci){
				slprMax = SarcoPreci(x,y, fftwin, MAX);
				slprMin = SarcoPreci(x,y, fftwin, MIN);
			}
			//CloseW("FFT of " + nom_ori);
			
			angleD = (calcAngleSegm(fftwin/2, fftwin/2, x, y));
			angle = (angleD+90) / (180/PI);
			if (angleD>=45) {
				run("Rotate... ", "angle="+(angleD-90)+" grid=0 interpolation=Bicubic");
				makeLine((fftwin/2), (fftwin/2) + xmax , (fftwin/2), (fftwin/2) + xmin);
			} else if (abs(angleD)<45) {
				run("Rotate... ", "angle="+angleD+" grid=0 interpolation=Bicubic");
				makeLine((fftwin/2) + xmax, (fftwin/2) , (fftwin/2) + xmin, (fftwin/2));
			} else {
				run("Rotate... ", "angle="+(90+angleD)+" grid=0 interpolation=Bicubic");
				makeLine((fftwin/2), (fftwin/2) + xmax , (fftwin/2), (fftwin/2) + xmin);
			}
			ZoneiFFTprofile = getProfile();
			Array.getStatistics(ZoneiFFTprofile, Zimin, Zimax, Zimean, ZistdDev);
			PositionDuMax = Array.findMaxima(ZoneiFFTprofile, Zimax-Zimean);
			if (PositionDuMax.length < 1) { beep(); IJ.log("error"); showStatus("Error : press SPACE"); continue; }
			PDM = PositionDuMax[0];
			xCumul = 3;
			SL[i-1] = calcOptmizedSL(PDM, 8); 
			if (sarcomo) {
				SH[i-1] = sh;
			}
			if (SLpreci) {
				SLPRMax[i-1] = slprMax;
				SLPRMin[i-1] = slprMin;
			}
			CloseW(newname);
			CloseW("FFT of " + newname);
		}
		CloseW(Hanning_name);
		CloseW(nom);
	}

	if (!DispAna) setBatchMode(false);
	if (SLpreci) {
		Plot.create("Sarcomere measurement", "time (s)", "Sarcomere length ("+unit+")", time, SL);
		Plot.add("crosses", time, SLPRMax);
		Plot.add("crosses", time, SLPRMin);
		Plot.setLineWidth(2);
		Plot.setColor("red");
		Plot.show();
	} else {
		Plot.create("Sarcomere measurement", "time (s)", "Sarcomere length ("+unit+")",time, SL);
		Plot.setLineWidth(1);
		Plot.setColor("black");
		Plot.show();
	}

	if (sarcomo) {
		Plot.create("Sarcomere space homogeneity", "time (s)", "Sarcomere homogeneity index", time, SH);
		Plot.show();
	}
	setBatchMode(false);
}

macro "Offline_fullFrame_MultiCell Video_Ana Action Tool - C953T0808AT8808VTg808IT8f08mTgf08c" {
// C953T0a08mT8a08TTga08r" {
	requires("1.49v");
	
	ScH = screenHeight; 	ScW = screenWidth;
	var largeur; var hauteur; var unit; var nom; var nom_ori; var fftwin;	var pixelW; var pixelH; var Nbits;
	var channels;  var sensispe; var fps; var slices;	var LLFCx1; var LLFCy1; var LLFCx2; var LLFCy2; var LLFClineWidth;
	var numCell;
	
	if ( !startsWith(getInfo("window.type"), "Image"))
			exit("<html>"
			 +"<h1>SarcOptiM</h1>"
			 +"<u>Warning:</u> Selected window is not an image !"
			 +"<ul>"
			 +"<li>tip: SarcOptiM works only on calibrated images"
			 +"</ul>");
			 
	nom_ori = getTitle();
	videoid = getImageID();
	if (startsWith(nom_ori, "FFT Spectrum"))
		showMessageWithCancel("Are you sure ?","Selected image seems to be FFT Spectrum! continue ?");	

	getDimensions(largeur, hauteur, channels, slices, frames);
	FI = Stack.getFrameInterval();
	if (FI==0)
		fps = Stack.getFrameRate();
	if (frames>1)
		if (FI==0)
			exit("<html>"
			 +"<h1>SarcOptiM</h1>"
			 +"<u>Warning:</u> Frames found but frame interval is 0 !"
			 +"<ul>"
			 +"<li>tip: use <b>Ctl-Maj-P</b> to correct"
			 +"</ul>");
	if (fps==0 && FI>0)	
		fps=1/FI;	
	if (fps==0)
		exit("<html>"
			 +"<h1>SarcOptiM</h1>"
			 +"<u>Warning:</u> framerate is 0 fps !"
			 +"<ul>"
			 +"<li>tip: use <b>Ctl-Maj-P</b> to correct"
			 +"</ul>");

	getPixelSize(unit, pixelW, pixelH);
	if (unit=="pixels") 
		exit("<html>"
			 +"<h1>SarcOptiM</h1>"
			 +"<u>Warning:</u> Video doesn't seem to be calibrated!"
			 +"<ul>"
			 +"<li>tip: use <b>Ctl-Maj-P</b> or calibration button"
			 +"</ul>");
	InfMess = call("ij.Prefs.get", "SCOPTM.InfMess",0);
	if (!InfMess)
		if (is("Virtual Stack"))
			showMessage("Information","<html>"
				+"<h1>SarcOptiM</h1>"
				+"<u>Warning:</u> this video is loaded with <b>virtual stack</b> enabled.<br> Videos are loaded faster but analysis with SarcOptiM will be  slower."
				+"<ul>"
				+"<li>tip: Use menu <b>Image\\type\\8-bit\</b> or uncheck <b>Use virtual stack</b> when opening a video."
				+"<li>The better is opening a video with <b>Convert to Grayscale</b> checked and <b>Use virtual stack</b> unchecked."
				+"</ul>"
				+"<center><b>ESC</b> to quit, <b>OK/Enter</b> to continue</center>");
	factor=1;
	if (unit=="nm") { factor = 0.001;	unit = fromCharCode(0x00B5)+"m"; }
	if (unit=="cm") { factor = 10000;	unit = fromCharCode(0x00B5)+"m"; }
	if (unit=="mm") { factor = 1000;	unit = fromCharCode(0x00B5)+"m"; }
	
	pixelW = roundn(pixelW, 7)*factor;
	pixelH = roundn(pixelH, 7)*factor;
	
	Nbits = bitDepth();
	getLine(tex1, tey1, tex2, tey2, telineWidth); 
	dx = tex2-tex1;
	
	Dialog.create("Analysis Parameters"); {
		Dialog.addMessage("Analysis parameters: ");
		Dialog.addNumber("Min Sarcomere length ("+fromCharCode(0x00B5)+"m)", 1.2);
		Dialog.addNumber("Max Sarcomere length ("+fromCharCode(0x00B5)+"m)", 2.2);
		Dialog.addNumber("Angular tolerance ("+fromCharCode(0x00B0)+")", 5);
		Dialog.addNumber("Number of cells to select: ", 2);
		Dialog.addMessage("----------INFORMATION ABOUT VIDEO----------");
		Dialog.addMessage("title: "+nom_ori);
		Dialog.addMessage("pixel size: "+pixelW+" "+unit);
		Dialog.addMessage("frame rate: "+fps+" fps");
		Dialog.addCheckbox("Do not show warning message about \"virtal stack videos\"", InfMess);
		Dialog.addHelp("http://pccv.univ-tours.fr/ImageJ/SarcOptiM/Online.html");
		Dialog.addMessage("Copyright@2015-2016 F.GANNIER - C.PASQUALIN");
		Dialog.show();
		SLmin = Dialog.getNumber();
		SLmax = Dialog.getNumber();
		toleranceAngleDeg = Dialog.getNumber();
		numCell = Dialog.getNumber();
		InfMess = Dialog.getCheckbox();
		call("ij.Prefs.set", "SCOPTM.InfMess",InfMess);
		DispAna = 0;
		highRes = 1;
		sarcomo = 0;
		SLpreci = 0;
	}
	if (!DispAna) setBatchMode(true);
	
	tpsimg = 1 / fps;
	time = newArray(slices);
	setTool("line");
	angleOfCells = multiLineAngleSelect(numCell); // recup de l'array contenant les angles des cellules
	puis2 = Puis2_fft(largeur,hauteur);
	fftwin = pow(2,puis2);
	xmin = Posdansfft(fftwin,pixelH,SLmin);
	xmax = Posdansfft(fftwin,pixelH,SLmax); //CP
	Hanning_name = Hanning_window(fftwin);
	for (i=0; i<slices; i++) time[i] = (i)*tpsimg;
	for (i=0; i<slices; i++)  setResult("Time", i, i*tpsimg);
	nom = "hanning";
	newImage(nom, Nbits+"-bit black", fftwin, fftwin, 1);
	
	for (i=1; i<=slices; i++) {
		if (!isOpen(nom_ori)) 	break;
		selectWindow(nom_ori);
		setSlice(i);
		run("Select All");  run("Copy");
		selectWindow(nom);
		run("Paste");
		imageCalculator("Multiply create 32-bit", nom, Hanning_name);
		newname = getTitle();
		run(8+"-bit");
		run("FFT");
		run("Subtract Background...", "rolling=30 sliding");
		run("Enhance Contrast...", "saturated=0.1");
		FFTid = getImageID();
		tor(fftwin/2-xmin,fftwin/2-xmin,xmin*2,fftwin/2-xmax,fftwin/2-xmax,xmax*2);

// setBatchMode(false);
// waitForUser("check");
			getStatistics(TORarea, TORmean, TORmin, TORmax, TORstd, TORhistogram);
			sensispe = floor(TORmax-TORmean);
			if (isNaN(sensispe)) waitForUser("Analysis failed. Please press 'Escape' and check video calibration");
			//on boucle sur tous les angles sélectionnés			
			for (ii=0; ii<numCell; ii++) {
				selectTrapezoid(angleOfCells[ii],SLmin,SLmax,toleranceAngleDeg); // tracage de le ROI trapezoide
				run("Find Maxima...", "noise="+sensispe+" output=[Point Selection]");
				getSelectionCoordinates(xx, yy);
				while ( selectionType() != 10) {
					sensispe -= 4;
					if (sensispe <= 1) { beep(); IJ.log("error"); continue; }
					selectTrapezoid(angleOfCells[ii],SLmin,SLmax,toleranceAngleDeg);
					run("Find Maxima...", "noise="+sensispe+" output=[Point Selection]");
					getSelectionCoordinates(xx, yy);
				}
				x = xx[0]; y = yy[0];
				
				run("Duplicate...", " ");
				FFTiddup = getImageID();
				angleD = (calcAngleSegm(fftwin/2, fftwin/2, x, y));
				angle = (angleD+90) / (180/PI);
				if (angleD>=45) {
					run("Rotate... ", "angle="+(angleD-90)+" grid=0 interpolation=Bicubic");
					makeLine((fftwin/2), (fftwin/2) + xmax , (fftwin/2), (fftwin/2) + xmin);
				} else if (abs(angleD)<45) {
					run("Rotate... ", "angle="+angleD+" grid=0 interpolation=Bicubic");
					makeLine((fftwin/2) + xmax, (fftwin/2) , (fftwin/2) + xmin, (fftwin/2));
				} else {
					run("Rotate... ", "angle="+(90+angleD)+" grid=0 interpolation=Bicubic");
					makeLine((fftwin/2), (fftwin/2) + xmax , (fftwin/2), (fftwin/2) + xmin);
				}
				ZoneiFFTprofile = getProfile();
				Array.getStatistics(ZoneiFFTprofile, Zimin, Zimax, Zimean, ZistdDev);
				PositionDuMax = Array.findMaxima(ZoneiFFTprofile, Zimax-Zimean);
				if (PositionDuMax.length < 1) { beep(); IJ.log("error"); showStatus("Error : press SPACE"); continue; }
				PDM = PositionDuMax[0];
				xCumul = 3;
				
				// SL[i-1] = calcOptmizedSL(PDM, 8); //ecriture du resultat SL dans table
				setResult("Cell"+(ii+1), i-1, calcOptmizedSL(PDM, 8));
				
				selectImage(FFTiddup);
				run("Close");
				selectImage(FFTid);
			}
			CloseW(newname);
			CloseW("FFT of " + newname);
	}
	CloseW(nom);
	CloseW(Hanning_name);

	if (!DispAna) setBatchMode(false);
	for (ii=0; ii<numCell; ii++) {
		yValues=newArray(nResults);
		for(i=0;i<nResults;i++) {
			yValues[i]=getResult("Cell"+(ii+1),i);
		}
		Plot.create("Sarcomere measurement "+(ii+1), "time (s)", "Sarcomere length ("+unit+")",time, yValues);
		// Plot.setLineWidth(1);
		// Plot.setColor("black");
		Plot.show();
	}
}

macro "Video_Synthesis Action Tool - C000C111D00D01D02D03D04D05D06D07D08D09D0aD0bD0cD0dD0eD0fD12D18D1eD22D28D2eD30D31D32D33D34D35D36D37D38D39D3aD3bD3cD3dD3eD3fD40D4cD50D54D5aD5cD60D64D65D69D6aD6cD70D74D76D78D7aD7cD80D84D87D8aD8cD90D94D9aD9cDa0Da4Da5Da9DaaDacDb0DbcDc0Dc1Dc2Dc3Dc4Dc5Dc6Dc7Dc8Dc9DcaDcbDccDcdDceDcfDd2Dd8DdeDe2De8DeeDf0Df1Df2Df3Df4Df5Df6Df7Df8Df9DfaDfbDfcDfdDfeDffC111C222C333C444C555C666C777C888C999CaaaCbbbCcccCdddCeeeCfff" {
	ScH = screenHeight;
	ScW = screenWidth;
	speed = 1;	
	Sdirectory = getDirectory("Select a saving Directory");
	Wdirectory = getDirectory("temp") + "temp$som"+File.separator();
	if (File.isDirectory(Wdirectory) == 1) {
		// directory already exists
		if (File.delete(Wdirectory)==0) {
			exit("<html>"
				 +"<h1>SarcOptiM</h1>"
				 +"<u>Warning:</u> Problem with the working directory !"
				 +"<ul>"
				 +"<li>tip: manually delete <b>" + Wdirectory + "</b> to correct"
				 +"</ul>");
		}
	}
	File.makeDirectory(Wdirectory);
	if (File.isDirectory(Wdirectory) != 1) {
		exit("Cannot create Working directory!");
	}
	call("ij.Prefs.set", "SOM.amp",120); 
	call("ij.Prefs.set",  "SOM.level",-80); 
	call("ij.Prefs.set", "SOM.noise",10); 
	{
		Dialog.create("SynthVideo");
		Dialog.addMessage("Cell features Video synthesis parameters : ");
		Dialog.addNumber("cell length ("+fromCharCode(0x00B5)+"m)", 100);
		Dialog.addNumber("cell width ("+fromCharCode(0x00B5)+"m)", 20);
		Dialog.addNumber("Rest Sarcomere length (nm) ", 1800); 
		Dialog.addNumber("horizontal cell position", 0); 
		Dialog.addNumber("vertical cell position", 0); 
		Dialog.addNumber("cell angle", 30);
		Dialog.addNumber("Cont/relax speed factor", speed,1,6,"(>0.5)");
		Dialog.addNumber("Sarcomere shortening rate (percent)", 5);

		Dialog.addMessage("--------------------------------------------------------");
		Dialog.addMessage("Video features :");
		Dialog.addNumber("video square size (pixels)", 512);
		Dialog.addNumber("pixel size ("+fromCharCode(0x00B5)+"m)", 0.3);
		Dialog.addNumber("Frame rate (Hz)", 100);
		Dialog.addCheckbox("Rotative cell motion", 0);
		Dialog.addCheckbox("Horizontal cell motion", 0);
		Dialog.addCheckbox("Vertical cell motion", 0);
		Dialog.addMessage("--------------------------------------------------------");
		Dialog.addString("Video name", "CMShortening", 12);
		Dialog.addHelp("http://pccv.univ-tours.fr/ImageJ/SarcOptiM/");
		Dialog.addMessage("Copyright@2015-2016 F.GANNIER - C.PASQUALIN");
		
		Dialog.show();

		ivHCS = Dialog.getNumber();
		ivWCS = Dialog.getNumber();
		ivSL = Dialog.getNumber();
		ivLCP = Dialog.getNumber();
		ivHCP = Dialog.getNumber();
		ivAngle = Dialog.getNumber()+90;
		speed = Dialog.getNumber();
		ivShortRate = Dialog.getNumber();
		ivSquareSize = Dialog.getNumber();
		ivPixSize = Dialog.getNumber();
		ivFrameRate = Dialog.getNumber();
		ACellMotion = Dialog.getCheckbox();
		HCellMotion = Dialog.getCheckbox();
		VCellMotion = Dialog.getCheckbox();

		NomDeLaVideo = Dialog.getString() + ".avi";
	}
	setBatchMode(true);
	nImgs = 400 * ivFrameRate / 1000;
	initialSL = ivSL;
	initialHCS = ivHCS;
	initialWCS = ivWCS;
	ivMaxShortening = ( ivShortRate * ivSL / 100 ) / 1000;
	ivTime = 0;
	call("ij.Prefs.set", "SOM.path",Wdirectory);
	call("ij.Prefs.set", "SOM.angle",ivAngle);
	call("ij.Prefs.set", "SOM.LCP",ivLCP);
	call("ij.Prefs.set", "SOM.TCP",ivHCP);

	for (i=1;i<=nImgs;i++) {
		call("ij.Prefs.set", "SOM.size",ivSquareSize);
		call("ij.Prefs.set", "SOM.HCS",ivHCS);
		call("ij.Prefs.set", "SOM.WCS",ivWCS);
		call("ij.Prefs.set", "SOM.period",ivSL);
		call("ij.Prefs.set", "SOM.resol",ivPixSize);
		call("ij.Prefs.set", "SOM.name","SynVid_"+i);
		
		call("ij.Prefs.set", "SOM.video","true");
		
		run("Image_Cell_Contraction");
		if (ACellMotion) ivAngle = ivAngle + random * 2.5;
		if (ACellMotion) call("ij.Prefs.set", "SOM.angle",ivAngle);
		if (HCellMotion) ivHCP = ivHCP + random * 5;
		if (HCellMotion) call("ij.Prefs.set", "SOM.TCP",ivHCP);
		if (VCellMotion) ivLCP = ivLCP + random * 5;
		if (VCellMotion) call("ij.Prefs.set", "SOM.LCP",ivLCP);

		CloseW("SynVid_"+i+".tif");
		ivTimeT = ivTime + ( i * (1000 / ivFrameRate));
		ivSL = CalcSLVidSyn(ivTimeT,initialSL/1000,ivMaxShortening,speed);
		ivSL = ivSL * 1000;
		ivHCS = CalcLongCMVidSyn(initialHCS,initialWCS,initialSL,ivSL);
		ivWCS = CalcLargCMVidSyn(initialHCS,initialWCS,initialSL,ivSL);
		showProgress(i / nImgs);
	}
	firstimg = "SynVid_1.tif";
	ConcatImgVidSyn(Wdirectory,Sdirectory, ivFrameRate,"JPEG",NomDeLaVideo,firstimg);
	for (i=1;i<=nImgs;i++) { 
		ajeter = File.delete(Wdirectory + "SynVid_"+i+".tif");
	}
	if (File.isDirectory(Wdirectory) == 1) {
		if (File.delete(Wdirectory)==0) {
			exit("<html>"
			 +"<h1>SarcOptiM</h1>"
			 +"<u>Warning:</u> Problem with the working directory !"
			 +"<ul>"
			 +"<li>tip: manually delete <b>" + Wdirectory + "</b> to correct"
			 +"</ul>");
		}
	}
setBatchMode(false);
}

function SarcoPreci(x,y,fftwin, sens){
	e = correc_bug(x, y, fftwin);
	return pixelW * fftwin /(e+sens);
}

function SarcoH(x,y){
	return getPixel(x,y);;
}

function Puis2_fft(largeur,hauteur){
	if (largeur>=hauteur)
		taillefen =  largeur;
	else  taillefen =  hauteur;
	iii = 0;
	while(taillefen>1) { taillefen /= 2; iii++;}
	return iii;
}

function tor(x1,y1,d1, x2, y2, d2){
	imageid = getImageID();

	roiManager("reset");
	makeOval(x1, y1, d1, d1);
	roiManager("Add");
	makeOval(x2, y2, d2, d2);
	roiManager("Add");
	roiManager("XOR");
	roiManager("reset");
	CloseW("ROI Manager");

	selectImage(imageid);
}

function correc_bug(X, Y, psize) {
	center = psize/2;
	diffX = center - X;
	diffY = center - Y;
	ecart = sqrt(diffX*diffX+diffY*diffY);
	return (ecart);
}

function Hanning_window(fftsize){
	Hanning_name = "hanning"+fftsize+".tif";
	dir = getDirectory("temp");
	if (File.exists(dir+Hanning_name)) {
		open(dir+Hanning_name);
	} else {
		run("Create Hanning W...","fftsize="+fftsize);
		save(dir+Hanning_name);
	}
	return getTitle(); // correction for FIJI;
}

function init_Common_values() {
	getDimensions(largeur, hauteur, channels, slices, frames);
	fps = Stack.getFrameRate();
	getPixelSize(unit, pixelW, pixelH);
	pixelW = roundn(pixelW, 7);
	pixelH = roundn(pixelH, 7);
	nom_ori = getTitle();
	Nbits = bitDepth();
}

function roundn(num, n) {
	return parseFloat(d2s(num,n))
}

function CloseW(nom) {
	if (isOpen(nom)) {
		selectWindow(nom);
		run("Close");
		do { wait(10); } while (isOpen(nom));
	}
}

function Posdansfft(fftwin,pix,period){
	location = floor ( fftwin * pix / period );
	return location;
}

function CalcSLVidSyn(temps,SLini,SLdeltaMax,speed){
	departContraction = 120;
	vartempz = (temps - departContraction) * speed / 31.71;
	VidSLtempT = SLini - SLdeltaMax * exp(-exp(-vartempz)-vartempz+1);
	return VidSLtempT;
}

function CalcLargCMVidSyn(Longini,Largini,SLini,SLtempT){
nbsar = Longini / SLini;
Surfaceini = Longini * Largini;
LongueurTempsT = SLtempT * nbsar;
LargTempsT = Surfaceini / LongueurTempsT * 1;
return LargTempsT;
}

function CalcLongCMVidSyn(Longini,Largini,SLini,SLtempT){
nbsar = Longini / SLini;
Surfaceini = Longini * Largini;
LongueurTempsT = SLtempT * nbsar;
return LongueurTempsT;
}

function ConcatImgVidSyn(VidSynDirectory,SDir,FreqEch,Compression,VidName,firstImgName){
	run("Image Sequence...", "open=["+VidSynDirectory+firstImgName+"] sort");
	FR = 1000 / FreqEch;
	run("Properties...", "frame=["+FR+" ms]");
	run("Invert", "stack");
//	run("AVI... ", "compression="+Compression+" frame="+FreqEch+" save=["+VidSynDirectory+VidName+"]");
	run("AVI... ", "compression="+Compression+" frame="+FreqEch+" save=["+SDir+VidName+"]");
	rename(VidName);
}

function getCellLine(title, videoid) {
	type = selectionType();
	if (type == 0) {
		getSelectionCoordinates(xpoints, ypoints);
		return abs(xpoints[1]-xpoints[0]);
	} else {
		setTool("line");
		getLine(LLFCx1, LLFCy1, LLFCx2, LLFCy2, LLFClineWidth);
		dx = LLFCx2-LLFCx1; dy = LLFCy2-LLFCy1;
		while ((dx+dy) == 0) {
			waitForUser( title,"Trace a line along the cell and then click OK (ESC to cancel)\nlinewidth can be changed by double click on line tool");
			lastId = getImageID();
			selectImage(videoid);
			if(lastId != videoid)
				showMessageWithCancel("Warning!","Selected image was \"" + getTitle() + "\".\nUse the same image or cancel");
			getLine(LLFCx1, LLFCy1, LLFCx2, LLFCy2, LLFClineWidth);
			dx = LLFCx2-LLFCx1; dy = LLFCy2-LLFCy1;
		}
		return sqrt(dx*dx+dy*dy);
	}
}

// CETTE FONCTION NE SERT PLUS !!!
function calcCenterXY(x1,y1,x2,y2,xy){
if (xy=="x") return (x1+x2)/2;
if (xy=="y") return (y1+y2)/2;
}

// CETTE FONCTION NE SERT PLUS !!!
function calcLongueur(x1,y1,x2,y2){
longueur = sqrt(((y2-y1)*(y2-y1))+((x2-x1)*(x2-x1)));
return longueur;
}

function calcAngleSegm(x1,y1,x2,y2){
	if (x1>x2) {
		tmp = x1;
		x1 = x2;
		x2 = tmp;
		tmp = y1;
		y1 = y2;
		y2 = tmp;
	}
	angle=atan2((y2-y1),(x2-x1));
	angle *= (180/PI);
	return -angle;
}

// CETTE FONCTION NE SERT PLUS !!!
function traceSegment(Xcentre,Ycentre,angle,longueur,ID){
	IDactuelle = getImageID();
	hypoth = longueur/2;
	anglerad = angle / (180/PI);
	decallageX = cos(anglerad)*hypoth;
	decallageY = sin(anglerad)*hypoth;
	x1 = Xcentre - floor(decallageX);
	x2 = Xcentre + floor(decallageX);
	y1 = Ycentre + floor(decallageY);
	y2 = Ycentre - floor(decallageY);
	selectImage(ID);
	makeLine(x1, y1, x2, y2);
	selectImage(IDactuelle);
}

function calcOptmizedSL(PDM, correction) {
	XMax = xmax+PDM;
	calibre = pixelW*fftwin;
//	print(lengthOf(ZoneiFFTprofile));
	if (PDM >= xCumul && PDM < lengthOf(ZoneiFFTprofile)-xCumul )
	{
		cumul1 = 0; cumul2 = 0; cumul3 = 0;
		for(ii=-xCumul;ii<=xCumul;ii++)
		{
			cumul1 += (ZoneiFFTprofile[PDM+ii]);
			cumul2 += calibre*(ZoneiFFTprofile[PDM+ii]/(XMax+ii));
		}
		rapport = cumul2 / cumul1;
		if (correction!=0) {
			ecart = rapport-(pixelW*fftwin/XMax);
			// print(ecart);
			rapport += rapport * ecart/correction;
		}
		return (rapport);
	} else 
		return calibre/XMax;
} 

function multiLineAngleSelect(numCell) {
// fonction pour récupérer les angles de chaque cellule dans l'array "angleOfCells"
// fonctionne par selection des cellules une par une plusieurs fois d'affilées
// renvoie una array contenant les angles selectionnés

	angleOfCells = newArray(numCell);
	for (i=0; i<numCell; i++) {
		waitForUser( "Axis Selection","Selection ["+(i+1)+" on "+numCell+"]\r\nTrace a line along the cell axis and then click OK\n");
		getLine(x1, y1, x2, y2, lineWidth);
		angleOfCells[i] = calcAngleSegm(x1,y1,x2,y2);
	}

return angleOfCells;
// Array.show(angleOfCells);
}

function selectTrapezoid(angleCell,SLminCell,SLmaxCell,toleranceAngleDeg){
// selection de l'anneau
			xmin = Posdansfft(fftwin,pixelW,SLminCell);
			xmax = Posdansfft(fftwin,pixelW,SLmaxCell);
			
			tor(fftwin/2-xmin,fftwin/2-xmin,xmin*2,fftwin/2-xmax,fftwin/2-xmax,xmax*2);
			roiManager("Add");
			// selectWindow("ROI Manager");
			// setLocation(1, ScH-60);
			// selection de l'angle
			toleranceAngleRad = PI * toleranceAngleDeg / 180;
			toldist = tan(toleranceAngleRad) * fftwin/2;
			// makePolygon(fftwin/2,fftwin/2,1,fftwin/2-toldist,1,fftwin/2+toldist);
			AngleCell = -(PI * angleCell / 180);
			
			
			if (angleCell<=0) {
				coordYtrapezoida = fftwin/2-(sin(AngleCell+toleranceAngleRad)*fftwin/2);
				coordYtrapezoidb = fftwin/2-(sin(AngleCell-toleranceAngleRad)*fftwin/2);
			} else {
				coordYtrapezoida = fftwin/2-sin(AngleCell+toleranceAngleRad)*fftwin/2;
				coordYtrapezoidb = fftwin/2-sin(AngleCell-toleranceAngleRad)*fftwin/2;
			}

			makePolygon(fftwin/2+cos(AngleCell+toleranceAngleRad)*fftwin/2,
					coordYtrapezoida,
					fftwin/2,
					fftwin/2,
					fftwin/2+cos(AngleCell-toleranceAngleRad)*fftwin/2,
					coordYtrapezoidb);
			
			roiManager("Add");
			roiManager("Select", newArray(0,1));
			roiManager("AND");
			roiManager("Add");
			roiManager("Select", 2);
		
			nbmaxima = nResults;
}