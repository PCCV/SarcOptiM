# SarcOptiM - High Frequency Online Sarcomere Length Measurement
Plugins and toolbars for ImageJ 
===============================
Côme PASQUALIN - François GANNIER (gannier at univ-tours dot fr) 
University of Tours (France)

Date : 2015/09/01 first version
2016/05/26: add MultiCell mode

Please visit http://pccv.univ-tours.fr/ImageJ/SarcOptiM/ to download and for more information

Tested on ImageJ 1.49t (linux, Mac OS and Windows)

Installation
------------
 - Download and unpack SarcOptiM.zip. 
 - Copy the SarcOptiM folder into the "ImageJ\plugins" folder and the SarcOptiM.ijm file into the "ImageJ\macros\toolsets" folder. 
 - Start ImageJ or restart it if already opened. 
 - In the "More tools" menu (>>) of the toolbar, select "SarcOptiM". A new set of buttons should now be present on the right side of the toolbar. SarcOptim is now ready to use. 
 
 N.B.: To have access to the full functionalities of SarcOptim, USE ONLY the toolbar. SarcOptim from the "Plugins" menu only shows some coding elements used in the script.
 
 
Short user guide
-----------------
 - See complete instructions at http://fg.tcplugins.free.fr/ImageJ/SarcOptiM/
 - Despite the fact that SarcOptiM can be used on entire image, using a simple line provides the best results.

1 - Setup
 - Spatial and temporal calibrations of the video must be done. 
 -> For spatial calibration, this could easily be done by pressing CTRL+SHIFT+P or the "1µm" button on the toolbar and following the instructions of the dialog box, for example. This has to be done to allow the programme to search the sarcomere length within the window lengths given in the analysis parameters. 
 -> For temporal calibration, one needs to know the camera frequency. On video capture, if the camera module is compatible (HF_IDS_Cam or webcam_Capture plugin v1.2) check "limit to Video Freq" in the different dialog boxes and enter a Time out value COMPATIBLE with the video frequency, i.e., greater than 1/frequency. Otherwise, use a time out equivalent to the video frequency (i.e., 1/frequency).

 For FFT on cell axis :
 - Trace a line on the cell. Use always the longer line: ideal will be 256+ pixels while 32/64/128 is possible but show worst results.
 - The live display of the "Online FFT Spectrum" module should help you to find the best profile (i.e., a single peak as narrow and high as possible), for that, just move and/or rotate the line.
  - While the FFT is displayed you can move the line or even change the angle (very useful if the cell is moving during the experiment).
 
N.B.: if the size of the line is changed by a factor 2 from a 2n value (ie : 32/64/128/256/512...) you must stop and restart the "Online FFT Spectrum" analysis.

2 - Online/Offline measurments
 - When the best FFT is obtained, press "SPACE" to stop the "Online FFT Spectrum" analysis,  be sure the image window is selected then choose the online or offline video analysis tool. 
 The analysis is stopped by pressing the SPACE bar. 
 
