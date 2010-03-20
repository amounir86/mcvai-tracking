## dshow.mak
##   makefile for the DirectShow plugin for videoIO.
##
## Copyright (c) 2006 Gerald Dalley
## See "MIT.txt" in the installation directory for licensing details 
## (especially when using this library on GNU/Linux). 

MEXOPTS   = -I. -g #  -O
OBJOPTS   = $(MEXOPTS) -outdir $(MEXEXT)
DSHOWLIBS = strmbase.lib strmiids.lib Vfw32.lib comsupp.lib winmm.lib 
# TODO: change install docs to add the /Zc:wchar_t- to BaseClasses too

all: DirectShow Vfw

clean:
	del *.obj *.mexw* *.bak /s /q /f mexglx mexa64 mexsol mexs64 mexmac mexmaci mexw32 mexw64 

$(MEXEXT):
	mkdir $(MEXEXT)

##### VIDEOREADER/VIDEOWRITER DIRECTSHOW PLUGIN ##############################

DirectShow: iDirectShow oDirectShow

###=== DirectShow videoReader plugin ======================================

iDirectShow: videoReader_DirectShow.$(MEXEXT)

videoReader_DirectShow.$(MEXEXT): $(MEXEXT)/mexClientDirect.obj $(MEXEXT)/videoReaderWrapper.obj $(MEXEXT)/DirectShowIVideo.obj $(MEXEXT)/WinCommon.obj $(MEXEXT)/registry.obj $(MEXEXT)/debug.obj dshow.mak 
	mex $(MEXOPTS) -output videoReader_DirectShow.$(MEXEXT) $(MEXEXT)/mexClientDirect.obj $(MEXEXT)/videoReaderWrapper.obj $(MEXEXT)/DirectShowIVideo.obj $(MEXEXT)/WinCommon.obj $(MEXEXT)/registry.obj $(MEXEXT)/debug.obj $(DSHOWLIBS) 

$(MEXEXT)/DirectShowIVideo.obj: DirectShowIVideo.cpp DirectShowIVideo.h WinCommon.h registry.h debug.h IVideo.h handle.h MatlabHelpers.h parse.h dshow.mak $(MEXEXT)
	mex $(OBJOPTS) -c DirectShowIVideo.cpp 

###=== DirectShow videoWriter plugin ======================================

oDirectShow: videoWriter_DirectShow.$(MEXEXT)

videoWriter_DirectShow.$(MEXEXT): $(MEXEXT)/mexClientDirect.obj $(MEXEXT)/videoWriterWrapper.obj $(MEXEXT)/DirectShowOVideo.obj $(MEXEXT)/WinCommon.obj $(MEXEXT)/registry.obj $(MEXEXT)/debug.obj dshow.mak
	mex $(MEXOPTS) -output videoWriter_DirectShow.$(MEXEXT) $(MEXEXT)/mexClientDirect.obj $(MEXEXT)/videoWriterWrapper.obj $(MEXEXT)/DirectShowOVideo.obj $(MEXEXT)/WinCommon.obj $(MEXEXT)/registry.obj $(MEXEXT)/debug.obj $(DSHOWLIBS)

$(MEXEXT)/DirectShowOVideo.obj: DirectShowOVideo.cpp DirectShowOVideo.h WinCommon.h registry.h debug.h OVideo.h IVideo.h handle.h MatlabHelpers.h parse.h dshow.mak $(MEXEXT)
	mex $(OBJOPTS) -c DirectShowOVideo.cpp 


##### VIDEOREADER/VIDEOWRITER Vfw PLUGIN #####################################

Vfw: oVfw

###=== Vfw videoWriter plugin =============================================

oVfw: videoWriter_Vfw.$(MEXEXT)

videoWriter_Vfw.$(MEXEXT): $(MEXEXT)/mexClientDirect.obj $(MEXEXT)/videoWriterWrapper.obj $(MEXEXT)/VfwOVideo.obj $(MEXEXT)/WinCommon.obj $(MEXEXT)/registry.obj $(MEXEXT)/debug.obj dshow.mak
	mex $(MEXOPTS) -output videoWriter_Vfw.$(MEXEXT) $(MEXEXT)/mexClientDirect.obj $(MEXEXT)/videoWriterWrapper.obj $(MEXEXT)/VfwOVideo.obj $(MEXEXT)/WinCommon.obj $(MEXEXT)/registry.obj $(MEXEXT)/debug.obj $(DSHOWLIBS)

$(MEXEXT)/VfwOVideo.obj: VfwOVideo.cpp VfwOVideo.h WinCommon.h registry.h debug.h OVideo.h IVideo.h handle.h MatlabHelpers.h parse.h dshow.mak $(MEXEXT)
	mex $(OBJOPTS) -c VfwOVideo.cpp 


###### VIDEOREADER/VIDEOWRITER-SPECIFIC SHARED COMPONENTS ####################

$(MEXEXT)/WinCommon.obj: WinCommon.cpp WinCommon.h dshow.mak $(MEXEXT)
	mex $(OBJOPTS) -c WinCommon.cpp 

$(MEXEXT)/debug.obj: debug.cpp debug.h dshow.mak $(MEXEXT)
	mex $(OBJOPTS) -c debug.cpp 

$(MEXEXT)/registry.obj: registry.cpp registry.h debug.h dshow.mak $(MEXEXT)
	mex $(OBJOPTS) -c registry.cpp

$(MEXEXT)/mexClientDirect.obj: mexClientDirect.cpp debug.h matarray.h MatlabHelpers.h handleMexRequest.h dshow.mak $(MEXEXT)
	mex $(OBJOPTS) -c mexClientDirect.cpp 

$(MEXEXT)/videoReaderWrapper.obj: videoReaderWrapper.cpp handleMexRequest.h IVideo.h matarray.h debug.h registry.h dshow.mak $(MEXEXT)
	mex $(OBJOPTS) -c videoReaderWrapper.cpp 

$(MEXEXT)/videoWriterWrapper.obj: videoWriterWrapper.cpp handleMexRequest.h OVideo.h IVideo.h matarray.h debug.h registry.h parse.h dshow.mak $(MEXEXT)
	mex $(OBJOPTS) -c videoWriterWrapper.cpp 
