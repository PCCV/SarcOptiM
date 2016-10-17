///////////////////////////////////////////////////////////////////
//  This file is part of TTorg.
//
//  TTorg is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  TTorg is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with TTorg.  If not, see <http://www.gnu.org/licenses/>.
//
// Copyright 2014-2016 C�me PASQUALIN, Fran�ois GANNIER
//////////////////////////////////////////////////////////////////
import ij.*; 
import ij.io.*; 
import ij.process.*; 
import ij.gui.*;		// genericDialog 
import ij.plugin.*; 
import ij.Macro.*;
//import ij.Prefs;		//Prefs.get 

import java.io.*; 		// File

//public class Hanning implements PlugIn, Runnable { 
public class Hanning implements PlugIn { 
	String sVer="Hanning Win for ImageJ ver. 1.2";
	String sCop="Copyright \u00A9 2014-2016 F.GANNIER - C.PASQUALIN";
	String [] Args;

	public void run(String arg) { 
		String options = Macro.getOptions();
		if (options == null) {
			arg = showDialog();
		} else {
			arg = Macro.getValue(options, "fftsize", null);
			if (arg == null)
				return;
		}
        
		short fftsize;
        try {
		fftsize = Short.parseShort(arg);
        } catch (NumberFormatException e) {
        	return;
        }
		
        if (fftsize>7) {
			String Hanning_name = "hanning"+fftsize+".tif";
			String dir = IJ.getDirectory("temp");
			File file = new File(dir+Hanning_name);
			ImagePlus image;
//			if (file.exists()) {
//				IJ.open(dir+Hanning_name);
//			} else {
				image = IJ.createImage(Hanning_name, "32-bit Black", fftsize, fftsize, 1);
				ImageProcessor ip = image.getProcessor();
				if (ip!=null) {
					float[] pix = (float[])ip.getPixels();
					double ru, rv, ruv, wuv;
					for (short v=0; v<fftsize; v++) {
						IJ.showProgress( v, fftsize);
						for (short u=0; u<fftsize; u++) {
							ru = 2*(double)u/fftsize-1.0;
							rv = 2*(double)v/fftsize-1.0;
							ruv = 1*ru*ru+rv*rv;
							ruv = Math.sqrt(ruv);
							wuv =  0.5*(Math.cos(Math.PI*ruv)+1.0);
//							if (ruv >= 0 && ruv < 1) 
								pix[u + v*fftsize] = (float) wuv;
//							else
//								pix[u + v*fftsize] = 0;
						}
					}
					image.show();
					IJ.saveAs(image, "Tiff", dir+Hanning_name);
				}
//			}
		}
	}
	
    String showDialog() { 
		String[] it={"32","64","128","256","512","1024","2048","4096","8192"};
        GenericDialog gd = new GenericDialog(sVer);
		gd.addChoice("Size : ", it, "1024");
		gd.addMessage(sCop);
        
		gd.showDialog();
		
        if (gd.wasCanceled())
			return "0";
		return gd.getNextChoice();
    }		
}
