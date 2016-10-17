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

import java.io.*;
import java.util.*;
// import java.awt.*;
//import java.lang.Thread;


public class HRtime {
	
	public static void main(String[] arg) {
	}

	public static long sleep(long time, long micro) {
		int ms = (int) (micro / 1000);
		if (ms > 0) IJ.wait(ms);
		long newtime = gettime();
			while ((newtime - time) < micro)
			{	
				newtime = gettime();
			}
		return newtime;
	}

 	public static long sleep(long micro) {
 		return sleep(gettime(), micro); 	
 	}
 	
 	public static long sleep(String time, String micro) {
 		return sleep((long) Double.parseDouble(time), (long) Double.parseDouble(micro)); 	
 	}
 	
	public static long gettime() {
		return  System.nanoTime()/1000; 
	}
}

