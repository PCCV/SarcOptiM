///////////////////////////////////////////////////////////////////
//  This file is part of SarcOptiM.
//
//  SarcOptiM is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  SOM is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with SOM.  If not, see <http://www.gnu.org/licenses/>.
//
// Copyright 2015-2016 Côme PASQUALIN, François GANNIER
//////////////////////////////////////////////////////////////////

import ij.*; 
import ij.process.*; 
import ij.gui.*;		// genericDialog 
import ij.plugin.*; 
import ij.Prefs;		//Prefs.get 

import ij.plugin.filter.RankFilters;
import ij.measure.Calibration;

import java.awt.*; 
import java.io.*; 
import java.util.*; 
import java.util.Random;

/* 
File.delete("d:\\Program Files\\ImageJ\\plugins\\CTI_org.class" ); 
run("Compile and Run...", "compile=[D:\\Program Files\\ImageJ\\plugins\\CTI_org.java]"); 
*/ 
 
public class Sarc_Org implements PlugIn { 
	String sVer="Sarc_Org Module ver. 1.0";
	String sCop="Copyright \u00A9 2015-2016 F.GANNIER - C.PASQUALIN";
	
	int ssize, amp, level, noise, gnoise, TCP, LCP, Nturn, org_lvl; 
	float period, angle, resol, HCS, WCS; 
	String path, name; 
	boolean b_save, isvideo;
	
	public void run(String arg) { 
		MessageDialog md; 
//		org_lvl = 100;
		loadDefaultValues(); 
//		if (arg.equals("auto")) {
		if (isvideo) {
			createImage(true, false);
			Prefs.set("SOM.video",false);
			return;
		}
		if (showDialog()==0)  
			return; 
		if (b_save) saveFile();
		if(period >0) { 
			if (Nturn>0) { 
				String name_save = name; 
				for (int i=1; i<=Nturn; i++) { 
					name = name_save+"_"+i; 
					createImage(true, true); 
				} 
				name = name_save; 
			} else createImage(false, true); 
		} else md = new MessageDialog(null, "Info", "No image created");  
		saveValues(); 
	} 
	 
	void createImage(boolean save, boolean progress) { 
		ImagePlus imp = IJ.createImage("Test", "16-bit Black", ssize, ssize, 1);
		if (imp!=null) {
			Calibration cal = new Calibration(imp); 
			cal.setUnit("microns"); 
			cal.pixelHeight = resol; 
			cal.pixelWidth  = resol; 
			imp.setCalibration(cal); 
 
			ImageProcessor ip = imp.getProcessor();  
			if (ip!=null) {
				int c_noise = noise*5;
// Position de la Cell			
				int V1 = (int) (ssize/2 - HCS/resol/2);		// V1 = LCP*size/100;
				int H1 = (int) (ssize/2 - WCS/resol/2);		//H1 = TCP*size/100;
				int V2 = (int) (HCS/resol+V1);
				int H2 = (int) (WCS/resol+H1); 
				int dec_noise = 0; 
				
				if (imp.getType() == ImagePlus.GRAY16) {  
// Acces memoire direct a l'image				
					short[] pix = (short[])ip.getPixels();
					double ru, rnd, test = (1f * (95f - org_lvl))/100;
					Random random = new Random();
					for (int v=V1-LCP; v<(V2-LCP); v++) { // vertical 
						if (progress) IJ.showProgress(v, ssize); 
// Calcul des alternances BW
						ru = (1 + Math.sin(2*Math.PI*v*resol*1000/period))*amp*325 + level*650; 
						ru = ru<0?0:ru;
						ru = ru>65534?65534:ru;
						for (int u=H1-TCP; u<(H2-TCP); u++) { // horizontal 
//							rnd = (random.nextGaussian() + org_lvl/50)/3;
							rnd = random.nextFloat();
							if (rnd > test)
								pix[u + v*ssize] = (short) ru; 
//							else pix[u + v*ssize] = (short) (noise*(-rnd));
							else { 
								if (rnd > (test/20)) 
									pix[u + v*ssize] = (short) ( 50 * rnd ); 
								else 
									pix[u + v*ssize] = (short) (65534-ru); 
							}
						} 
					}  
				}
				IJ.setForegroundColor(50, 50, 50);	// background not black 
				ip.setColor(new Color(50,50,50)); 	// couleur de l'ip
// Contour de la cellule, create ROI then draw on ip after setcolor
				{
					int[] xpoints = {H1-TCP+5,H1-TCP-5,H1-TCP+5}; 
					int[] ypoints = {V1-LCP,V1-LCP +(V2-V1)/2,V2-LCP}; 
					PolygonRoi polyline = new PolygonRoi( xpoints, ypoints, 3, Roi.POLYLINE); 
					polyline.fitSpline(); 
					polyline.setStrokeWidth(2.5);
					polyline.drawPixels(ip);

					int[] xpoints1 = {H2-TCP-4,H2-TCP+6,H2-TCP-5}; 
					int[] ypoints1 = {V1-LCP,V1-LCP +(V2-V1)/2,V2-LCP}; 
					polyline = new PolygonRoi( xpoints1, ypoints1, 3, Roi.POLYLINE); 
					polyline.fitSpline(); 
					polyline.setStrokeWidth(2.5);
					polyline.drawPixels(ip);
// Horiz				
					int[] xpoints2 = {H1-TCP+5,H1-TCP+(H2-H1)/2,H2-TCP-4};
					int[] ypoints2 = {V1-LCP,V1-LCP-4,V1-LCP};
					polyline = new PolygonRoi( xpoints2, ypoints2, 3, Roi.POLYLINE); 
					polyline.fitSpline(); 
					polyline.setStrokeWidth(2.5);
					polyline.drawPixels(ip);
					
					int[] xpoints3 = {H1-TCP+5,H1-TCP+(H2-H1)/2,H2-TCP-5};
					int[] ypoints3 = {V2-LCP,V2-LCP+4,V2-LCP}; 
					polyline = new PolygonRoi( xpoints3, ypoints3, 3, Roi.POLYLINE); 
					polyline.fitSpline(); 
					polyline.setStrokeWidth(2.5);
					polyline.drawPixels(ip); 
				}
// Fin contour Cell				
				ip.resetRoi();	// annule ROI precedent => entire Image
				if (angle!=0) { 
					ip.setInterpolationMethod(ImageProcessor.BILINEAR); 
					ip.rotate(angle); 
				} 
//filtre
				RankFilters RF = new RankFilters(); 
//arithmetique
				ip.subtract(((c_noise+dec_noise)*.2));
				ip.multiply(5); /* */

				RF.rank(ip, 1, RankFilters.MEAN); 
//				RF.rank(ip, 2, RankFilters.MEDIAN); 

				if (noise>=0)
					ip.noise(c_noise);
//add gaussian noise
				if (gnoise>=0) ip.noise(gnoise);

				imp.show(); 
				if (save) {
					if (!path.endsWith("/")) 
						path = path + "/"; 
					IJ.saveAs(imp, "Tiff", path+name);  
				}
			}
		}
	} 
	
	void loadDefaultValues() { 
		isvideo = (boolean) Prefs.get("SOM.video", false);
		ssize = (int) Prefs.get("SOM.size", 512);
		period = (float) Prefs.get("SOM.period", 1800);
		amp = (int) Prefs.get("SOM.amp",100);
		level = (int) Prefs.get("SOM.level",-50);
		angle = (float) Prefs.get("SOM.angle",0);
		noise = (int)Prefs.get("SOM.noise",10);
		gnoise = (int)Prefs.get("SOM.gnoise",5000);
		resol = (float) Prefs.get("SOM.resol",0.30);
		path = Prefs.get("SOM.path", IJ.getDirectory("home"));
		name = Prefs.get("SOM.name","image_test");
		TCP = (int) Prefs.get("SOM.TCP",0);
		org_lvl = (int) Prefs.get("SOM.org_lvl",85);
		LCP = (int) Prefs.get("SOM.LCP",0);
		HCS = (float) Prefs.get("SOM.HCS",100);
		WCS = (float) Prefs.get("SOM.WCS",20);
		Nturn = (int) Prefs.get("SOM.Nturn",0);
		b_save = (boolean) Prefs.get("SOM.svParam",false);
	} 
	 
	void saveValues() { 
		Prefs.set("SOM.video",false);
		Prefs.set("SOM.size",ssize);  
		Prefs.set("SOM.period",period);  
		Prefs.set("SOM.amp",amp);  
		Prefs.set("SOM.level",level);  
		Prefs.set("SOM.org_lvl",org_lvl); 
		Prefs.set("SOM.angle",angle);  
		Prefs.set("SOM.noise",noise);  
		Prefs.set("SOM.gnoise",gnoise);
		Prefs.set("SOM.resol",resol);  
		Prefs.set("SOM.path",path);  
		Prefs.set("SOM.name",name);  
		Prefs.set("SOM.LCP",LCP); 
		Prefs.set("SOM.TCP",TCP); 
		Prefs.set("SOM.HCS",HCS); 
		Prefs.set("SOM.WCS",WCS); 
 
		Prefs.set("SOM.Nturn",0); 
	} 

	void saveFile() {
		try {
			String filename = path + name + ".txt";
			File file = new File(filename);
			if (!file.exists()) {
				file.createNewFile();
			}
			FileWriter fw = new FileWriter(file.getAbsoluteFile());
			BufferedWriter bw = new BufferedWriter(fw);
			
			bw.write("SOM.size = " + ssize);  
			bw.write("\r\n");
			bw.write("SOM.period = "+period);  
			bw.write("\r\n");
			bw.write("SOM.amp = "+amp);  
			bw.write("\r\n");
			bw.write("SOM.level = "+level);  
			bw.write("\r\n");
			bw.write("SOM.angle = "+angle);
			bw.write("\r\n");
			bw.write("SOM.noise = "+noise);
			bw.write("\r\n");
			bw.write("SOM.gnoise = "+gnoise);
			bw.write("\r\n");
			bw.write("SOM.resol = "+resol);  
			bw.write("\r\n");
			// bw.write("SOM.path = "+path);  bw.write("\r\n");
			// bw.write("SOM.name = "+name);  bw.write("\r\n");
			bw.write("SOM.LCP = "+LCP); 
			bw.write("\r\n");
			bw.write("SOM.TCP = "+TCP); 
			bw.write("\r\n");
			bw.write("SOM.HCS = "+HCS); 
			bw.write("\r\n");
			bw.write("SOM.WCS = "+WCS); 
			bw.write("\r\n");

			bw.close();		
		} catch (IOException e) {
			e.printStackTrace();
		}
	} 
	
	int showDialog() { 
		GenericDialog gd = new GenericDialog(sVer); 
		 
//      gd.setInsets(0, 20, 0); 
		gd.addNumericField("Square Image Size :", ssize, 0, 6, "pixels"); 
		gd.addNumericField("Pixel size :", resol, 11, 15, "\u00B5m/pixel"); 
		 
		gd.addNumericField("Left Cell position :", LCP, 0, 6, "pixels");	 
		gd.addNumericField("Top Cell position :", TCP, 0, 6, "pixels"); 
		 
		gd.addNumericField("Hight Cell size :", HCS, 1, 6, "\u00B5m"); 
		gd.addNumericField("Width Cell size :", WCS, 1, 6, "\u00B5m"); 
		 
		gd.addNumericField("Period :", period, 0, 6, "nm"); 
		gd.addNumericField("Amplitude :", amp, 0, 6, "%"); 
		gd.addNumericField("Basal level :", level, 0, 6, "%"); 
		gd.addNumericField("Organisation level :", org_lvl, 0, 6, "%"); 
//		gd.addNumericField("Noise level :", noise, 0);
		gd.addNumericField("Angle (\u00B0):", angle, 1); 
		gd.addNumericField("Add Gaussian noise :", gnoise, 0);  
		 
		gd.addStringField("Path :", path, 25); 
		gd.addStringField("Name :", name, 15);
		gd.addCheckbox("Save parameters file", b_save);
		gd.addMessage(sCop);
       // gd.addHelp(IJ.URL+"/docs/menus/process.html#fft-options"); 
 
		gd.showDialog(); 		// The macro terminates if the user clicks "Cancel" 
        if (gd.wasCanceled()) 
			return 0; 
			 
		ssize = (int) gd.getNextNumber(); 
		resol = (float) gd.getNextNumber(); 
		LCP = (int) gd.getNextNumber(); 
		TCP = (int) gd.getNextNumber(); 
		HCS = (float) gd.getNextNumber(); 
		WCS = (float) gd.getNextNumber(); 
		period = (float) gd.getNextNumber(); 
		amp = (int) gd.getNextNumber(); 
		level = (int) gd.getNextNumber(); 
		org_lvl = (int) gd.getNextNumber(); 
//		noise = (int) gd.getNextNumber(); 
		angle = (float) gd.getNextNumber(); 
		gnoise = (int) gd.getNextNumber(); 
		path = gd.getNextString(); 
		name = gd.getNextString();	/**/ 
		
		b_save = gd.getNextBoolean();
		 
		return 1; 
    }  
} 