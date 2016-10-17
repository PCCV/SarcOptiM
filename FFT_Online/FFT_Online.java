import ij.*; 

import ij.plugin.filter.PlugInFilter; // L'interface PlugInFilter

import ij.plugin.PlugIn;
import ij.plugin.filter.*; // L'interface PlugInFilter

import ij.process.*; 	// Les différents ImageProcessor
import ij.measure.*;	// Calibration;
import ij.gui.*;
import ij.Prefs;		// Prefs.get 
import ij.util.*;
// import ij.util.Tools;

import java.io.*;
import java.util.*;
// import java.lang.Thread;
import java.lang.*; 

import java.awt.*; 	// Rectangle

public class FFT_OnLine implements PlugIn {
// public class FFT_OnLine implements PlugInFilter {
	static boolean debug = false; // true;
	static boolean debugFR = true;
	
	String sVer="SarcOptiM Module ver.1.2 (2016/05/26)";
	String sCop="Copyright \u00A9 2015-2016 F.GANNIER - C.PASQUALIN";
	
	static boolean VFreq;
	static float TimeOut;
	static int MaxFrames;
	static float SLmin;
	static float SLmax;
	static boolean slDisplay;
	static String GType;
	
	static long fftwin = 0;
	static double pixelW = 0;
	// Advanced options
	int decal = 3000;
	int offsetDisplay = 10000;
	
	static int xCumul = 3;
	static int Xprecision = 4;  	// 1/4ms
	
	public static long HRgettime() {
		return  System.nanoTime()/1000; 
	}	
	
	public long HRsleep(long time, long micro) {
		int ms = (int) (micro / 1000);
		if (ms > 0) IJ.wait(ms);
		long newtime = HRgettime();
			while ((newtime - time) < micro)
			{	
				newtime = HRgettime();
			}
		return newtime;
	}

	public long HRsleep(long micro) {
		return HRsleep(HRgettime(), micro);
	}
	
	public long testMSprecision() {
	// JIT/hotspot warmup:
		for (int r = 0; r < 3000; ++ r) System.currentTimeMillis ();
		
		long time = System.currentTimeMillis (), time_prev = time, cumul5=0;
		for (int i = 0; i < 5; ++ i)
		{
			while (time == time_prev)
				time = System.currentTimeMillis ();
			cumul5 += time - time_prev;
			time_prev = time;
		}
		IJ.log("OS precision = " + (cumul5/5) + " ms");
		return (time - time_prev);
	}

	public long testHRprecision() {
	// JIT/hotspot warmup:
		for (int r = 0; r < 3000; ++ r) System.currentTimeMillis ();
		
		long time = HRgettime(), time_prev = time, cumul5=0;
		for (int i = 0; i < 5; ++ i)
		{
			while (time == time_prev)
				time = HRgettime();
			cumul5 += time - time_prev;
			time_prev = time;
		}
		IJ.log("HR precision = " + (cumul5/5) + " us");
		return (time - time_prev);
	}
	
	public long testHRwait(long HRTimeOut) {
	// JIT/hotspot warmup:
		for (int r = 0; r < 3000; ++ r) System.currentTimeMillis ();
		
		long time = HRgettime(), newtime = time;
		if (HRTimeOut > 0) 
			newtime = HRsleep(time, HRTimeOut); 
		IJ.log("HR wait expected ("+HRTimeOut+"us) : real("+(newtime-time)+" us)");
		return (time - newtime);
	}
	
	double[] l2d(long[] l) {
		return l2d(l, 0, l.length);
	}
	
	double[] l2d(long[] l, int min, int max) {
		double[] d = new double[max-min];
		for (int i = min; i < max; i++)
			d[i] = new Double(l[i]);
		return d;
	}
	
	float[] d2f(double[] d) {
		return d2f(d, 0, d.length);
	}
	float[] d2f(double[] d, int min, int max) {
		float[] f = new float[max-min];
		for (int i = min; i < max; i++)
			f[i] = new Float(d[i]); 
		return f;
	}

	double[] f2d(float[] f) {
		return f2d(f,0,f.length);
	}	
	double[] f2d(float[] f, int min, int max) {
		double[] d = new double[max-min];
		for (int i = min; i < max; i++)
			d[i] = new Double(f[i]); 
		return d;
	}
	
	double calcOptmizedSL(float [] ZoneiFFTprofile, int PDM, int xmin) {
		int XMin = xmin+PDM;
		if ( (PDM >= xCumul) && (PDM < (ZoneiFFTprofile.length-xCumul)) )
		{
			float cumul1 = 0; float cumul2 = 0;
			for(int ii=-xCumul;ii<=xCumul;ii++)
			{
				cumul1 += (ZoneiFFTprofile[PDM+ii]);
				cumul2 += (ZoneiFFTprofile[PDM+ii]/(XMin+ii));
			}
	// FG Amelioration de la resolution
			double rapport = cumul2 / cumul1;
			double ecart = XMin-(1/rapport);
	// FG Optimisation de l'amelioration
			rapport += rapport * ecart/200;
			return pixelW*(double)fftwin*rapport;
		} else  /* */
		{
			return pixelW*(double)fftwin/(double)XMin;
		}
	}	

	long Fenetre1D_fft(double lg) {
		double iii = 0;
		while(lg>1) { lg /= 2; iii++;}
		return (long) Math.pow(2.0,iii);
	}
    
	public void OnLine() {
		// get the current image
		ImagePlus img = WindowManager.getCurrentImage();
// 		ImagePlus img = IJ.getImage();
		if (img == null) {
			IJ.noImage(); return;
		}
		ImageWindow imw = img.getWindow();
		ImageProcessor ip = img.getProcessor();
//		if (debug) IJ.log("Width :"+ip.getWidth());
//		if (debug) IJ.log("Height :"+ip.getHeight());
	
		Roi roi = img.getRoi();
//		boolean isRoi = roi!=null && roi.isArea();
		boolean isLine = roi!=null && roi.getType()==Roi.LINE;
		double LineLengthForCell;
//		if (isRoi||isLine)
		if (isLine)
		{
		    Rectangle b = new Rectangle(roi.getBounds());
//			if (debug) IJ.log(""+b);
			ip.setInterpolationMethod(ImageProcessor.BICUBIC);
			ProfilePlot profileP = new ProfilePlot(img, Prefs.verticalProfile);//get the profile
			double[] profile = profileP.getProfile();
//			LineLengthForCell = Math.sqrt(b.width*b.width+b.height*b.height);
			LineLengthForCell = profile.length;
		} else {
			IJ.log("You must select a line!");
			return;
		}
		
		Calibration cal = img.getCalibration();
		String unit = cal.getUnit();
 		if (unit.equals("pixel")) {
			IJ.log("Doesn't seem to be calibrated!");
			return;
		}
		if (debug) {IJ.log("unit : "+unit);}
		pixelW = cal.pixelWidth ;
		if (unit.equals("nm")) { pixelW = cal.pixelWidth * 0.001; }
		if (unit.equals("cm")) { pixelW = cal.pixelWidth * 10000;}
		if (unit.equals("mm")) { pixelW = cal.pixelWidth * 1000;}
		if (debug) {IJ.log("pixelW : "+pixelW);}
		
//		loadParameters();

		fftwin = Fenetre1D_fft(LineLengthForCell);
		int xmax = (int) Math.floor ( fftwin * pixelW / SLmin );
		int xmin = (int) Math.floor ( fftwin * pixelW / SLmax );
		
		double[] SLDisplay = new double[decal]; 
		double[] TmDisplay = new double[decal]; 
		double[] FRtab = new double[10];
		
		long[] timeSL  = new long[MaxFrames];
		double[] SL = new double[MaxFrames];
		double[] framerate  = new double[MaxFrames];
		
		for(int i=0; i<decal; i++) TmDisplay[i]=i*1000;


		if (debug) {
			IJ.log("FFT passband : "+xmin+"-"+xmax);
			IJ.log("Line length : "+LineLengthForCell);
			IJ.log("FFT win : "+fftwin);
			IJ.log("pixel size : "+pixelW);
		}

		Prefs.set("Cam.newImage",false);

		//IJ.getLocationAndSize(Vidx, Vidy, Vidwidth, Vidheight);
		if (imw != null) {
			imw.setLocation( 0, 0);
			ImageWindow.setNextLocation( 0, imw.getSize().height);
		} else {
			ImageWindow.setNextLocation( 0, ip.getHeight());
		}
		Plot SLplot = new Plot("sarco_length", "time (s)", "SL (microns)");
		SLplot.add(GType, TmDisplay, SLDisplay);
		PlotWindow SLwindow = SLplot.show();

		//Gestion du frameRate
		int 	Nframes = 0;			// Nb de points
		double frameRate;
		double totalFR;
		double ecart = 0;
		int HRTimeOut = (int) (1000*TimeOut);
		int HRwait = (int) (1000/Xprecision);

		// Variable de temps en us
		long temps;
		long timetemp;
		double laps;
		if (debug) {
			testMSprecision();
			testHRprecision();
			testHRwait(HRTimeOut);
		}
		long tempsDepart = HRgettime();
		long newTime = tempsDepart;
		long lastTime = tempsDepart;
		long error = 0;
		FHT fft = new FHT();
		while (!IJ.spaceBarDown()) {
			temps = HRgettime();
			if (VFreq) {	// Frequence de la camera
				while (!(boolean) Prefs.get("Cam.newImage",false)) {
					 	temps = HRsleep(temps, HRwait);
					if ((temps - newTime) >= HRTimeOut) break;
				}
				Prefs.set("Cam.newImage",false); 
			} else if (HRTimeOut > 0) {
					temps = HRsleep(temps, HRTimeOut - (temps - newTime)); 
			}
			lastTime = newTime;				//en us
			newTime = temps;
			timetemp = (newTime - tempsDepart)/1000; 	// en ms
			laps = (newTime - lastTime)/1000.0; 	// en ms
			timeSL[Nframes] = timetemp;
			
 			ip.setInterpolationMethod(ImageProcessor.BICUBIC); // semble ne pas changer gd chose
			ProfilePlot profileP = new ProfilePlot(img, Prefs.verticalProfile);//get the profile
			float[] profile = d2f(profileP.getProfile());
			float[] fftprofile = fft.fourier1D(profile, fft.HANN);
 			float[] ZoneiFFTprofile = Arrays.copyOfRange(fftprofile, xmin, xmax);
 			ArrayUtil au = new ArrayUtil(ZoneiFFTprofile);
 			double zimax = au.getMaximum();
 			double zimean = au.getMean(); /* */
			int[] PositionDuMax = MaximumFinder.findMaxima(f2d(ZoneiFFTprofile), zimax - zimean, true);
			if (PositionDuMax.length < 1) { error++; IJ.showStatus("No peak found, error ("+error+") : press SPACE"); continue; }
			SL[Nframes] = calcOptmizedSL( ZoneiFFTprofile, PositionDuMax[0], xmin); 

			String st = " ";
			if (slDisplay) {
				if (SLwindow.isClosed()) {
					IJ.showStatus("Online FFT analysis halted");
					return;
				}
 				SLDisplay[Nframes%decal] = SL[Nframes];
 				TmDisplay[Nframes%decal] = timetemp;
				
				SLplot = new Plot("sarco_length", "time (s)", "SL (microns)"); //, TmDisplay, SLDisplay);
				SLplot.add(GType, TmDisplay, SLDisplay);
				SLplot.setLimits(timetemp-offsetDisplay, timetemp, SLmin, SLmax);
 				SLwindow.drawPlot(SLplot);
			} else  /* */
				st += "SL : "+IJ.d2s(SL[Nframes],3)+" um ";

			if (debugFR) {
				if (laps == 0)
					frameRate = 0;
				else frameRate = 100/laps; 		// 0.1fps 
				FRtab[Nframes % 10] = frameRate;
				totalFR = 0;
				for(int ii=0; ii <10; ii++)
					totalFR += FRtab[ii];		// fps
				framerate[Nframes] = (int) totalFR;
				st += "FR : " + IJ.d2s(framerate[Nframes],2) + " fps ";
			}

			ecart += laps;
			if (ecart > 500) {
				ecart = 0;
				if (debugFR | !slDisplay) {
					st += "- SPACE to stop";
					IJ.showStatus(st);
				}
			}
			Nframes++;
			if (Nframes>=MaxFrames)	break;
		}
//		if (slDisplay) if (!SLwindow.isClosed()) SLwindow.close();
		if (error >0) IJ.log("found "+error+" error(s)");
		
		if (Nframes > 0) {
			double[] a1 = l2d(timeSL, 0, Nframes-1);
			double[] a2 = Arrays.copyOfRange(SL, 0, Nframes-1);

			SLplot = new Plot("Sarcomere measurement", "time (s)", "Sarcomere length", a1, a2);

			ArrayUtil au = new ArrayUtil(d2f(a2));
			double max = au.getMaximum();
			double min = au.getMinimum();		
			if (min == max)
				SLplot.setLimits(0, a1[Nframes-2], min-0.25, max+0.25);
			SLwindow.drawPlot(SLplot);

			if (debugFR) {
				ImageWindow.setNextLocation(SLwindow.getSize().width, SLwindow.getLocation().y);
		//		Array.show("framerate", framerate);
				double[] a3 = Arrays.copyOfRange(framerate, 0, Nframes-1);
				Plot FRPlot = new Plot("framerate", "time (s)", "framerate", a1, a3);
				FRPlot.show();
			}
		}
	}

	public void run(String args) {
		if (args.equals("offline")) {
			IJ.log("OffLine analisys");
			return ;
		}
		if (args.equals("online")) {
			if (debug) IJ.log("*** Start FFT_OnLine ***");
			loadParameters();			
			if (showOffLineDialog() == 0) return;
			saveParameters();
			OnLine();
			return ;
		}
	
	}

	public void showAbout() {
		IJ.showMessage("About ...",
		"To do\n" +
		"About box."
		);
	}
	
	static void loadParameters() {
		debug =  (boolean) Prefs.get("OVA.debug",false);
		debugFR =  (boolean) Prefs.get("OVA.debugFR",true);

		VFreq =  (boolean) Prefs.get("OVA.VFreq",false);
		TimeOut =  (float) Prefs.get("OVA.TO",10);
		MaxFrames = (int) Prefs.get("OVA.MaxFrames",18000);
		SLmin = (float) Prefs.get("OVA.SLmin",1.2);
		SLmax = (float) Prefs.get("OVA.SLmax",2.1);
		slDisplay = (boolean) Prefs.get("OVA.slDisplay",true);
		GType = Prefs.get("OVA.GType","dots");
		if (debug) {
			IJ.log("VFreq : "+VFreq);
			IJ.log("TimeOut : " +TimeOut+" ms");
			IJ.log("SL passband : "+SLmin+"-"+SLmax);
			IJ.log("display : "+slDisplay);
		}
	}

	static void saveParameters() {
		Prefs.set("OVA.MaxFrames",MaxFrames);
		Prefs.set("OVA.SLmin",SLmin);
		Prefs.set("OVA.SLmax",SLmax);
		Prefs.set("OVA.GType",GType);
		Prefs.set("OVA.VFreq",VFreq);
		Prefs.set("OVA.TO",TimeOut);
		Prefs.set("OVA.slDisplay",slDisplay);
		
		Prefs.set("OVA.debug",debug);
		Prefs.set("OVA.debugFR",debugFR);
		
	}	
	
	int showOffLineDialog() { 
		GenericDialog gd = new GenericDialog(sVer); 

		gd.addMessage("On-line video analysis");
//      gd.setInsets(0, 20, 0);
		gd.addNumericField("Approximative Nb of points",MaxFrames, 0, 8,"");
		gd.addMessage("1h at 50Hz need 72000 pts");
		gd.addMessage("");
		gd.addNumericField("Min Sarcomere length", SLmin, 3, 6, "\u00B5m");
		gd.addNumericField("Max Sarcomere length", SLmax, 3, 6, "\u00B5m");
		
		String [] ch = {"dots","line","circles","boxes","connected","triangle","x","crosses"};
		gd.addChoice("Display...", ch, GType);

		gd.addCheckbox("Limit to Video Freq.", VFreq);
		gd.addNumericField("VFreq time out",TimeOut,2,6,"ms");
		gd.addCheckbox("Display SL while acquiring", slDisplay);
		gd.addCheckbox("Advanced Options", false);
		gd.addMessage("WARNING:\nTo avoid Java error, DO NOT RESIZE the\nFFT Spectrum window during acquisition.");
		gd.addMessage(sCop);
		
		gd.addHelp("http://pccv.univ-tours.fr/ImageJ/SarcOptiM/Online.html");
		
		gd.showDialog(); 		// The macro terminates if the user clicks "Cancel" 
		if (gd.wasCanceled()) 
			return 0; 

		MaxFrames = (int) gd.getNextNumber();
		SLmin = (float) gd.getNextNumber();
		SLmax = (float) gd.getNextNumber();
		GType = gd.getNextChoice();
		VFreq = gd.getNextBoolean();
		TimeOut = (float) gd.getNextNumber();
		slDisplay = gd.getNextBoolean();
		boolean AdvOptions = gd.getNextBoolean();

		if (AdvOptions) {
			gd = new GenericDialog(sVer); 
			gd.addMessage("Advanced options");
			gd.addNumericField("Precision (1/x ms)", Xprecision,0,6,"(1/x ms)");
			gd.addNumericField("Points in HiRes analysis",xCumul,0,6,"");
			gd.addNumericField("Buffer of Array", decal,0,6,"");
			gd.addNumericField("Display duration (ms)", offsetDisplay,0,6,"ms");
			gd.addCheckbox("Mode Debug", debug);
			gd.addCheckbox("Display Framerate", debugFR);
			gd.addMessage(sCop);
 
			gd.showDialog(); 		// The macro terminates if the user clicks "Cancel" 
			if (gd.wasCanceled()) 
				return 0; 

			Xprecision = (int) gd.getNextNumber();
			xCumul = (int) gd.getNextNumber();
			decal = (int) gd.getNextNumber();
			offsetDisplay = (int) gd.getNextNumber();
			debug = gd.getNextBoolean();
			debugFR = gd.getNextBoolean();
		}
		return 1; 
	}
} 
