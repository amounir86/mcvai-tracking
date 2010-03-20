// $Date: 2008-11-28 21:24:28 -0500 (Fri, 28 Nov 2008) $
// $Revision: 711 $

/*
videoIO: granting easy, flexible, and efficient read/write access to video 
files in Matlab on Windows and GNU/Linux platforms.

Copyright (c) 2006 Gerald Dalley

Permission is hereby granted, free of charge, to any person obtaining a copy 
of this software and associated documentation files (the "Software"), to deal 
in the Software without restriction, including without limitation the rights 
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell 
copies of the Software, and to permit persons to whom the Software is 
furnished to do so, subject to the following conditions:

Portions of this software link to code licensed under the Gnu General 
Public License (GPL).  As such, they must be licensed by the more 
restrictive GPL license rather than this MIT license.  If you compile 
those files, this library and any code of yours that uses it automatically
becomes subject to the GPL conditions.  Any source files supplied by 
this library that bear this restriction are clearly marked with internal
comments.

The above copyright notice and this permission notice shall be included in all 
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR 
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, 
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE 
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER 
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, 
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE 
SOFTWARE.
*/

// Windows stuff
#define _WIN32_WINNT 0x0501
#define WINVER       0x0501 // Require WinXP for now
#pragma warning (disable: 4995) // ignore stdio deprecation warnings
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <atlstr.h>
#include <time.h>
#include <sys/timeb.h>
#include <iostream>
#include <sstream>

//#define PRINT_VERBOSES
#include "debug.h"

#include "DirectShowIVideo.h"
#include "registry.h"
#include "parse.h"
#include "WinCommon.h"

using namespace std;

namespace VideoIO 
{

  class DirectShowIVideoManager : public IVideoManager
  {
  public:
    virtual IVideo *createVideo() throw() {
      return new(nothrow) DirectShowIVideo();
    }
  };
  static auto_ptr<IVideoManager> oldManager(
    registerIVideoManager(new DirectShowIVideoManager()));

  typedef __int64 int64;

  /*************************************************************************
  *************************************************************************
  **   H E L P E R S
  *************************************************************************
  *************************************************************************/

  // TODO: If this works, transfer its usage back to the tracker lib
#define ClosingAssert(testCond) \
  try { \
  VrRecoverableCheckMsg(testCond, "closing the file..."); \
  } catch (...) { close(); throw; }

#define FatalAssert(testCond) \
  try { VrFatalCheck(testCond); } catch (...) { close(); throw; }


  // Adapted from:
  // https://matroska.org/svn/matroska/trunk/MatroskaUtils/ShellExtension/DShowTools/DShowTools.cpp
  static IPin *findVideoPin(IBaseFilter *pGrabberFilter, PIN_DIRECTION requiredPinDir) 
  {
    VrRecoverableCheck(pGrabberFilter!=NULL);

    //Find the output pin of the Source Filter
    CComPtr<IEnumPins> pPinEnum;
    RecoverableHresultCheck(pGrabberFilter->EnumPins(&pPinEnum));

    IPin *pSearchPin;
    while (pPinEnum->Next(1, &pSearchPin, NULL) == S_OK) {
      PIN_DIRECTION pPinDir;
      RecoverableHresultCheck(pSearchPin->QueryDirection(&pPinDir));
      if (pPinDir == requiredPinDir) {
        // Found out pin.  If the filter is connected, let's see if it's 
        // a video pin.
        CMediaType type;
        if (!SUCCEEDED(pSearchPin->ConnectionMediaType(&type))) {
          // If it's not connected, just assume it'll work.
          return pSearchPin;
        } else {
          if (type.formattype == FORMAT_VideoInfo) {
            return pSearchPin;
          } else if (type.formattype == FORMAT_VideoInfo2) {
            return pSearchPin;
          } else if (type.formattype == FORMAT_MPEG2Video) {
            return pSearchPin;
          } else if (type.formattype == FORMAT_MPEGVideo) {
            return pSearchPin;
          } else {
            // not a video pin...keep searching
          }
        }
      }
    }
    return NULL;
  }

  static void connectFilters(IGraphBuilder *pGraph, IBaseFilter &src, IBaseFilter &dest) 
  {
    CComPtr<IPin> pSourceOutPin = findVideoPin(&src, PINDIR_OUTPUT);
    VrRecoverableCheck(pSourceOutPin!=NULL);
    CComPtr<IPin> pDestInPin = findVideoPin(&dest, PINDIR_INPUT);
    VrRecoverableCheck(pDestInPin!=NULL);

    RecoverableHresultCheck(pGraph->Connect(pSourceOutPin, pDestInPin));
  }

  static void connectFiltersDirect(IFilterGraph *pGraph, IBaseFilter &src, 
    IBaseFilter &dest, AM_MEDIA_TYPE const *pmt = NULL) 
  {
    CComPtr<IPin> pSourceOutPin = findVideoPin(&src, PINDIR_OUTPUT);
    VrRecoverableCheck(pSourceOutPin!=NULL);
    CComPtr<IPin> pDestInPin = findVideoPin(&dest, PINDIR_INPUT);
    VrRecoverableCheck(pDestInPin!=NULL);

    RecoverableHresultCheck(pGraph->ConnectDirect(pSourceOutPin, pDestInPin, pmt));
  }

  static void disconnectFilters(IFilterGraph *pGraph, IBaseFilter &src, IBaseFilter &dest) 
  {
    CComPtr<IPin> pSourceOutPin = findVideoPin(&src, PINDIR_OUTPUT);
    VrRecoverableCheck(pSourceOutPin!=NULL);
    CComPtr<IPin> pDestInPin = findVideoPin(&dest, PINDIR_INPUT);
    VrRecoverableCheck(pDestInPin!=NULL);

    RecoverableHresultCheck(pGraph->Disconnect(pSourceOutPin));
    RecoverableHresultCheck(pGraph->Disconnect(pDestInPin));
  }

  static IBaseFilter *getSourceFilter(IBaseFilter &dest) 
  {
    IPin *pDestInPin = findVideoPin(&dest, PINDIR_INPUT);
    IPin *pSrcOutPin = NULL;
    RecoverableHresultCheck(pDestInPin->ConnectedTo(&pSrcOutPin));
    PIN_INFO srcInfo;
    RecoverableHresultCheck(pSrcOutPin->QueryPinInfo(&srcInfo));
    return srcInfo.pFilter;
  }

  // adapted from: http://sid6581.wordpress.com/2006/10/12/finding-directshow-filters-by-name/
  static IBaseFilter *createFilterByName(char const *name, REFCLSID filterCategory)
  {
    // Find the filter that matches the name given.
    CodecEnumerator e(filterCategory, false); 
    while (e.next()) {
      if ((e.moniker() != NULL) && 
          ((_strcmpi(name, e.friendlyName().c_str()) == 0) || 
           (_strcmpi(name, e.fccHandler().c_str()) == 0)))
      {
        IBaseFilter *filter = NULL;
        RecoverableHresultCheck(
          e.moniker()->BindToObject(0, 0, IID_IBaseFilter, (void**)&filter));
        return filter;
      }
    }
    // Couldn't find a matching filter.
    VrRecoverableThrow("Could not find a filter named \"" << name << "\".");
  }

  // Note: this function should only be called before 
  // pDet->EnterBitmatGrabMode.
  static IVideo::FourCC getFourCC(IMediaDet *pDet) 
  {
    IVideo::FourCC ret = 0;
    CMediaType type;
    RecoverableHresultCheck(pDet->get_StreamMediaType(&type));

    if (type.formattype == FORMAT_VideoInfo) {
      VIDEOINFOHEADER *pVih = reinterpret_cast<VIDEOINFOHEADER*>(type.pbFormat);
      ret = pVih->bmiHeader.biCompression;
    } else if (type.formattype == FORMAT_MPEGVideo) {
      MPEG1VIDEOINFO *pVih = reinterpret_cast<MPEG1VIDEOINFO*>(type.pbFormat);
      ret = pVih->hdr.bmiHeader.biCompression;
    } else if (type.formattype == FORMAT_VideoInfo2) {
      VIDEOINFOHEADER2 *pVih = reinterpret_cast<VIDEOINFOHEADER2*>(type.pbFormat);
      ret = pVih->bmiHeader.biCompression;
    } else if (type.formattype == FORMAT_MPEG2Video) {
      MPEG2VIDEOINFO *pVih = reinterpret_cast<MPEG2VIDEOINFO*>(type.pbFormat);
      ret = pVih->hdr.bmiHeader.biCompression;
    } 

    return ret;
  }

  /*************************************************************************
  *************************************************************************
  **   V I D E O   C L A S S
  *************************************************************************
  *************************************************************************/

  DirectShowIVideo::DirectShowIVideo() : 
  nFrames(-1), framesPerSecond(-1), w(-1), h(-1), d(3),
    currentFrameNumber(-1), nHiddenFinalFrames(0),
    timeFormat(TIME_FORMAT_FRAME /* wishful thinking */), 
    preciseFrames(5*60), frameTimeoutMS_(1000*3), quickExit(false), 
    dataReceived(CreateEvent(NULL, FALSE, FALSE, NULL)),
    dataTransferTrigger(CreateEvent(NULL, FALSE, FALSE, NULL)),
    dataTransferred(CreateEvent(NULL, FALSE, FALSE, NULL)),
    m_nRefCount(0) 
  {
    coInitIfNeeded();
    // most users are not COM-aware, so we auto-create a reference
    AddRef();
  }

  // call from open() only
  void DirectShowIVideo::parseOpenArgs(KeyValueMap &kvm)
  {
    // Extract arguments
    VrRecoverableCheckMsg(kvm.hasKey("filename"), 
      "The filename must be specified");
    for (KeyValueMap::const_iterator i=kvm.begin(); i!=kvm.end(); i++) {
      if (strcasecmp("filename", i->first.c_str()) == 0) {
        this->fname = i->second; // no type conversion necessary

      } else if (strcasecmp("preciseFrames", i->first.c_str()) == 0) {
        this->preciseFrames = kvm.parseInt<int>("preciseFrames");

      } else if (strcasecmp("frameTimeoutMS", i->first.c_str()) == 0) {
        int const newTimeout = kvm.parseInt<int>("frameTimeoutMS");
        if (newTimeout == 0) {
          VrRecoverableThrow("User attempted to use a frameTimeoutMS of "
            "0.  The timeout must be at least 1ms.  Use "
            "-1 for no timeout.");
        } else if (newTimeout == -1) {
          // -1 == no timeout ... do nothing special here
        } else if (newTimeout < -1) {
          VrRecoverableThrow("User attempted to use a frameTimeoutMS of "
            << newTimeout << ", but only positive "
            "numbers or the special case of -1 are "
            "allowed.  -1 means an infinite timeout.");
        }
        this->frameTimeoutMS_ = newTimeout;

      } else if (strcasecmp("dfilters", i->first.c_str()) == 0) { 
        char nameList[8192]; nameList[sizeof(nameList)-1] = 0;
        strncpy(nameList, i->second.c_str(), sizeof(nameList)-1);

        char *name = strtok(nameList, ":");
        while (name != NULL) {
          if (strlen(name) > 0) {
            extraDirectShowFilterNames.push_back(name);
          }
          name = strtok(NULL, ":");
        }

      } else {
        VrRecoverableThrow("Unrecognnized argument name: " << i->first);
      }
    }
  }

  void DirectShowIVideo::open(KeyValueMap &kvm)
  {
    TRACE;
    if (isOpen()) close();

    parseOpenArgs(kvm);

    // Do all the work to open the file.  Much of this work is included
    // in a long function here because order is very important for most
    // of the commands here and most of the DirectShow functions can 
    // only be called here.
    try {
      USES_CONVERSION;

      // Create a media detector
      // TODO: Use ATL, make pDet a stack variable
      RecoverableHresultCheck(CoCreateInstance(CLSID_MediaDet, NULL,
        CLSCTX_INPROC_SERVER, IID_IMediaDet, (void**) &this->pDet));

      // Set filename
      RecoverableHresultCheckMsg(
        this->pDet->put_Filename(T2W(fname.c_str())),
        "Could not open \"" << fname << "\".  Perhaps the file does not "
        "exist or the required codec is not installed.");

      // Look for a video stream
      long nStreams = 0;
      RecoverableHresultCheck(this->pDet->get_OutputStreams(&nStreams));

      bool bFoundVideo = false;
      for(int i=0; i<nStreams; i++)
      {
        bool bIsVideo = false;
        CMediaType type;

        // Select a media stream
        if (!SUCCEEDED(this->pDet->put_CurrentStream(i))) continue;

        // Read the media type of the selected stream
        if (!SUCCEEDED(this->pDet->get_StreamMediaType(&type))) continue;

        // Does this stream contain video?
        if (type.majortype == MEDIATYPE_Video) bIsVideo = true;

        if (!bIsVideo) continue;

        bFoundVideo = true;
        break;
      }

      VrRecoverableCheck(bFoundVideo);

      // Record the fourcc code for the compressed data.
      fourCC = getFourCC(this->pDet);
      this->nHiddenFinalFrames = guessNumHiddenFinalFrames(fourCC);

      // set video properties.  Note that the 3ivx 4.5.1 codec doesn't read
      // the final frame, so we'll reduce our nFrames count as appropriate.
      // Must be called before pDet->EnterBitmapGrabMode.
      RecoverableHresultCheck(this->pDet->get_FrameRate(&this->framesPerSecond));
      {
        double streamLength=0;
        RecoverableHresultCheck(this->pDet->get_StreamLength(&streamLength));
        this->nFrames = (int)((streamLength*this->framesPerSecond)+0.5);
      }

      // This method will change the MediaDet to go into
      // "sample grabbing mode" at time 0.
      RecoverableHresultCheckMsg(this->pDet->EnterBitmapGrabMode(0.0),
        "Could not enter bitmap grab mode.  Usually this means that you do "
        "not have the right codec installed (recall that if you are using "
        "the 64-bit version of this software, you need to install a 64-bit "
        "codec).");

      // Ask for the sample grabber filter that we know lives inside the
      // graph made by the MediaDet
      RecoverableHresultCheck(this->pDet->GetSampleGrabber(&this->pGrabber));

      // Set the callback (our COM object callback)
      CComQIPtr<ISampleGrabberCB, &IID_ISampleGrabberCB> pCB(this);
      CComQIPtr<IBaseFilter, &IID_IBaseFilter>           pGrabberFilter(this->pGrabber);
      RecoverableHresultCheck(this->pGrabber->SetCallback(pCB, 0));

      // Make the SampleGrabber call SampleCB.  We'll simulated buffered 
      // one-shot mode in a way that still allows for streaming.  The DirectX 9 
      // docs say that OneShot mode and buffered mode from DirectX 8 were 
      // actually bad ideas and shouldn't be used.
      RecoverableHresultCheck(pGrabber->SetOneShot(FALSE));
      RecoverableHresultCheck(pGrabber->SetBufferSamples(FALSE));

      // Find the filter graph interface from the sample grabber filter
      FILTER_INFO fi;
      memset(&fi, 0, sizeof(fi));

      RecoverableHresultCheck(pGrabberFilter->QueryFilterInfo(&fi));

      // Release the filter's graph reference
      if (fi.pGraph) fi.pGraph->Release();
      IFilterGraph *pGraph = fi.pGraph;
#ifdef ADDTOROT      
      RecoverableHresultCheck(addToRot(pGraph, &dwRegister));
#endif

      // The graph will have been paused by entering bitmap grab mode.
      // We'll need to seek back to 0 to get it to deliver correctly.
      CComQIPtr<IMediaSeeking, &IID_IMediaSeeking> pSeeking2(pGraph);
      CComQIPtr<IMediaControl, &IID_IMediaControl> pControl2(pGraph);
      CComQIPtr<IMediaEvent,   &IID_IMediaEvent>   pEvent2(pGraph);

      this->pSeeking = pSeeking2;
      this->pControl = pControl2;
      this->pEvent   = pEvent2;

      // Stop the filter graph:  We first tell SampleCB to exit quickly and
      // we make sure it isn't blocked on the dataTransferTrigger.  We next
      // stop the filtergraph.  The Stop call is a blocking call: when it 
      // returns, we are guaranteed that SampleCB will not be called again
      // until we Run the graph again.  We then turn off the quick exit
      // flag.
      quickExit = true; // avoid extra work
      VrFatalCheck(SetEvent(dataTransferTrigger)); 
      FatalHresultCheck(this->pControl->Stop()); 
      VrFatalCheck(ResetEvent(dataTransferTrigger)); // just to be clean
      quickExit = false;

      // Instantiate any requested DirectShow filters
      if (extraDirectShowFilterNames.size() > 0) {
        // Note: the filtergraph must be stopped to change connections
        CComPtr<IBaseFilter> pSource = getSourceFilter(*pGrabberFilter);
        disconnectFilters(pGraph, *pSource, *pGrabberFilter);
        for (size_t i=0; i<extraDirectShowFilterNames.size(); i++) {
          // create the filter
          CComPtr<IBaseFilter> pNewFilter =
            createFilterByName(extraDirectShowFilterNames[i].c_str(), 
                               CLSID_LegacyAmFilterCategory);

          // add it to the filtergraph
          RecoverableHresultCheck(pGraph->AddFilter(&*pNewFilter, NULL));

          // connect it to the previous filter
          connectFiltersDirect(pGraph, *pSource, *pNewFilter); 

          // the new filter becomes the source for the next filter
          pSource = pNewFilter;
        }

        // reconnect to the SampleGrabber that will be used to extract
        // the frames.
        connectFiltersDirect(pGraph, *pSource, *pGrabberFilter); 
      }

      // Get the initial image size from the sample grabber's input pin
      {
        CMediaType type;
        this->pGrabber->GetConnectedMediaType(&type);
        parseMediaType(&type);
      }

      // Set the time format. We prefer frame-based times, but I think
      // timestamp-based times are more common. Try for frame-based first, 
      // and fall back to timestamp-based for codecs that don't support
      // frame-based timing.
      if (pSeeking->IsFormatSupported(&TIME_FORMAT_FRAME)==S_OK) {
        timeFormat = TIME_FORMAT_FRAME;
      } else if (pSeeking->IsFormatSupported(&TIME_FORMAT_MEDIA_TIME)==S_OK) {
        timeFormat = TIME_FORMAT_MEDIA_TIME;
      } else {
        VrRecoverableThrow("Neither frame based nor media-time based seeking "
          "is allowed on this file.  Please use a different "
          "codec to encode your video and/or contact the "
          "library authors.");
      }

      VrRecoverableCheckMsg(SUCCEEDED(pSeeking->SetTimeFormat(&timeFormat)),
        "Could not set the time format (this is very odd since the codec "
        "explicitly said it could use this format).");

      GUID tformat = TIME_FORMAT_SAMPLE;
      VrRecoverableCheckMsg(SUCCEEDED(pSeeking->GetTimeFormat(&tformat)),
        "Could not retrieve the time format to verify it was set properly.");
      VrRecoverableCheckMsg(tformat==timeFormat, 
        "Setting the time format claimed to succeed, but the time format "
        "is not what we requested.");

      // Tell the pipeline we want to be able to access the whole video file
      REFERENCE_TIME start    = 0;
      REFERENCE_TIME duration = 0;
      RecoverableHresultCheck(this->pSeeking->GetDuration(&duration));
      if (FAILED(this->pSeeking->SetPositions(
        &start, AM_SEEKING_AbsolutePositioning, 
        &duration, AM_SEEKING_AbsolutePositioning))) 
      {
        // Some XP configurations use a set of filters that do not use 
        // the duration parameter consistently.  This workaround helps solve 
        // cases where GetDuration returned a value that is too large for 
        // SetPositions.  Note: this is generally the fault of SetPositions,
        // not GetPositions, so the final frame of the video may be 
        // inaccessible.
        duration -= 1;
        RecoverableHresultCheck(this->pSeeking->SetPositions(
          &start, AM_SEEKING_AbsolutePositioning, 
          &duration, AM_SEEKING_AbsolutePositioning));
      }

#ifdef PRINT_VERBOSES
      LONGLONG pCurrent, pStop;
      pSeeking->GetPositions(&pCurrent, &pStop);
      VERBOSE("DirectShow thinks the current position is " << pCurrent << 
        " and the ending position is " << pStop);
#endif

      currentFrameNumber = -1;
    } catch(VrRecoverableException const &) {
      close();
      throw;
    } catch(VrFatalError const &) {
      close();
      throw;
    }
  }

  void DirectShowIVideo::close() 
  {
    TRACE;
    if (!isOpen()) return;

#ifdef ADDTOROT
    removeFromRot(dwRegister);
#endif

    quickExit = true;
    SetEvent(dataTransferTrigger);
    if (pControl) pControl->Stop();

    if (pControl) pControl.Release();
    if (pSeeking) pSeeking.Release();
    if (pDet)     pDet.Release();

    CloseHandle(dataTransferred);
    CloseHandle(dataTransferTrigger);
    CloseHandle(dataReceived);

    if (pGrabber) pGrabber.Release();

    Frame(currentFrame).swap(currentFrame);

    fname = "";
  }

  /**
  * This handles all seeking, stepping, and next operations by trying to use
  * the best method given the current and desired frame numbers.  In cases
  * where we are advancing only a small number of frames, we simply stream
  * through the frames.  Otherwise, we do a more complex (and possibly imprecise
  * seek).  Note that for the long seeks, many formats will only approximately
  * seek to the desire location and are not required to go exactly there.
  *
  * If you are trying to understand the implementation here, there are some
  * important points to keep in mind.  First, pControl->Stop() is a blocking
  * operation.  This means that we must take care to never call it if 
  * SampleCB has any chance of waiting on a synchronization object.  For the
  * long seeks, we handle this by setting a flag that causes SampleCB to not
  * do any blocking.  We then reset the synchronization flag to unblock it
  * if it's blocked.  It is then safe to call Stop.  Since Stop blocks, once
  * it returns, we know that SampleCB will not be called again until we call
  * Run.  This allows us to safely reset the other synchronization objects 
  * and do the DirectShow seek call (SetPositions).  Note that while quickExit
  * is true, SampleCB might be called many times and extra file I/O might
  * wastefully occur.  We don't worry about it since there is no (easy) way
  * to prevent it from happening.  It does not affect the results because
  * we will be doing a seek anyway.
  *
  * When reading data out, we make sure the filtergraph is running, then we
  * wait for a signal from SampleCB to tell us that it has received some data.
  * SampleCB blocks before copying out its data until we're ready to read it.
  * This prevents it from modifying the data buffer when the user might be
  * calling getframe.  We then tell SampleCB to continue and wait for it to
  * signal that it has finished transferring data.
  */
  bool DirectShowIVideo::seek(int frameNumber)
  {
    TRACE;
    VrRecoverableCheck(isOpen());
    if (frameNumber == currentFrameNumber) return true;

    if (frameNumber < 0) return false;
    if (frameNumber >= numFrames()) return false;

    VERBOSE("seeking to frame " << frameNumber);

    if (this->preciseFrames < 0 || 
      (frameNumber > currentFrameNumber && 
      frameNumber <= (currentFrameNumber + this->preciseFrames)))
    {
      // Short forward seek
      return seekPrecise(frameNumber);
    } else {
      // Backward or long forward seek
      return seekImprecise(frameNumber);
    }
  }

  IVideo::ExtraParamsAndStats DirectShowIVideo::extraParamsAndStats() const {
    IVideo::ExtraParamsAndStats params;
    params["frameTimeoutMS"] = toString(frameTimeoutMS());
    params["preciseFrames"]  = toString(preciseFrames);
    return params;
  }

  STDMETHODIMP DirectShowIVideo::QueryInterface(REFIID riid, void ** ppv) 
  {
    TRACE;
    CheckPointer(ppv, E_POINTER);
    if (riid == IID_ISampleGrabberCB || riid == IID_IUnknown) {
      *ppv = (void *) static_cast<ISampleGrabberCB *>(this);
      AddRef();
      return NOERROR;
    }
    return E_NOINTERFACE;
  }

  /**
  * Callback called by DirectShow which allows us to obtain the data from a
  * sample.  The DirectShow documentation warns that we should never have
  * SampleCB block.  We violate that warning because we need to pull data
  * from the stream (DirectShow really likes to work in push mode).  We have
  * been careful with our synchronization objects and we don't do direct 
  * on-screen display, so we can get away with blocking here.  See 
  * DirectShowIVideo::seek for a description of our synchronization setup.
  */
  STDMETHODIMP DirectShowIVideo::SampleCB(double SampleTime, IMediaSample *pSample)
  {
    // Do *not* TRACE this function as long as trace outputs with mexPrintf.  
    // Matlab will croak if we call any of its functions from a secondary 
    // thread.
    if (quickExit) return 0;
    // TODO: I think this was introduced for timing tests.  If so, remove it.
    // If it should still remain, document why.
    static bool firstTime=true;
    if (firstTime) {
      SetThreadAffinityMask(NULL,1);
      firstTime=false;
    }

    if (!SetEvent(dataReceived)) return VFW_E_RUNTIME_ERROR;
    if (WaitForSingleObject(dataTransferTrigger, INFINITE) != WAIT_OBJECT_0) {
      return VFW_E_RUNTIME_ERROR; 
    }
    if (quickExit) return 0; // avoid hangs in the destructor
    if (!ResetEvent(dataReceived)) return VFW_E_RUNTIME_ERROR;

    sampleCbTime = SampleTime;

    // TODO: for completeness, we should recheck the media type in case the
    // frame geometry has changed.

    // TODO: when doing precise seeks, set a flag so we can skip 
    // shuffleImageBytes for all frames that will be discarded.  This isn't as
    // fast as avoiding the decoding entirely, but it'll save some time.
    if (pSample) {
      StdimplHresultCheck(shuffleImageBytes(pSample));
    } else {
      // This can happen for dropped frames.
      currentFrame.resize(0);
    }
    if (!SetEvent(dataTransferred)) return VFW_E_RUNTIME_ERROR; 

    return 0;
  }

  /** 
  * Here we look at the media type and extract out the width,
  * height, and byte depth of the media sample (image).  If there
  * are any problems detected, the movie's width, height, and depth
  * are all zeroed to prevent misinterpretation of the image data.
  * This method should only be called using the media type of
  * actual samples given to the sample grabber or from the sample
  * grabber.  Other upstream filters may have different media types.
  * For example, when decoding MPEG1 video (sometimes?), the initial
  * stream is a 12-bit YUV variant, but the sample grabber ends up
  * getting 24-bit frames.
  */
  void DirectShowIVideo::parseMediaType(AM_MEDIA_TYPE *pMediaType)
  {
    TRACE;
    int bitDepth = 0;
    if (pMediaType->formattype == FORMAT_VideoInfo) {
      VIDEOINFOHEADER *pVih =
        reinterpret_cast<VIDEOINFOHEADER*>(pMediaType->pbFormat);
      this->w  = pVih->bmiHeader.biWidth;
      this->h  = pVih->bmiHeader.biHeight;
      bitDepth = pVih->bmiHeader.biBitCount;
    } else if (pMediaType->formattype == FORMAT_VideoInfo2) {
      VIDEOINFOHEADER2 *pVih =
        reinterpret_cast<VIDEOINFOHEADER2*>(pMediaType->pbFormat);
      this->w  = pVih->bmiHeader.biWidth;
      this->h  = pVih->bmiHeader.biHeight;
      bitDepth = pVih->bmiHeader.biBitCount;
    } else {
      VrRecoverableThrow("The sample grabber somehow received something "
        "other than a decoded video frame");
    }

    // Make sure we got good values
    VrRecoverableCheck(h >= 0);
    // We only support 8-, 24-, and 32-bit images right now.
    VrRecoverableCheck(bitDepth%8 == 0); 
    d = bitDepth / 8;
    VrRecoverableCheck((d==1) || (d==3) || (d==4)); 
  }

  /** 
  * Here we decode the current frame buffer into an array that's laid out the 
  * way Matlab likes it.  This method should only be called by SampleCB.  We've 
  * extracted it here to separate out all the thread handling that happens there
  * from the bit twiddling we do here.
  *
  * When we add the noalias attribute to this method, we're actually lying 
  * because it requires that functions be semi-pure:
  *   "The noalias declspec is also applied only to functions, and indicates 
  *    that the function is a semi-pure function. A semi-pure function is one 
  *    that references or modifies only locals, arguments, and first-level 
  *    indirections of arguments. This declspec is a promise to the compiler, 
  *    and if the function references globals or second-level indirections of 
  *    pointer arguments then the compiler may generate code that breaks the 
  *    application."
  * We do it anyway because even though we do higher-level indirections, we 
  * know that no memory we access will be aliased. 
  */
  //__declspec(noalias) 
  HRESULT DirectShowIVideo::shuffleImageBytes(IMediaSample *pSample)
  {
    // Do *not* TRACE this function as long as trace outputs with mexPrintf.  
    // Matlab will croak if we call any of its functions from a secondary 
    // thread.
    const int sampleSize = pSample->GetActualDataLength();

    BYTE *pData=NULL;
    StdimplHresultCheck(pSample->GetPointer(&pData)); 
    const size_t   stride        = ((w*d + 3)/4)*4;
    // Some codecs such as DivX allocate extra memory, e.g. enough for RGBA,
    // so here we'll avoid second-guessing and just make sure we're not going
    // to overrun our read buffer.
    if (sampleSize < (int)(stride*h)) return VFW_E_BUFFER_OVERFLOW;
    currentFrame.resize(w*h*d);

    if (d == 1) {
      for (int y=0; y<h; y++) {
        for (int x=0; x<w; x++) {
          currentFrame[y+x*h] = pData[x+(h-y-1)*stride];
        }
      }
    } else if ((d == 3) || (d == 4)) {
      topDownBgrToMatlab(&currentFrame[0], pData, stride, w, h, d);
    } else {
      return VFW_E_UNSUPPORTED_VIDEO;
    }
    return S_OK;
  }

  ULONG __stdcall DirectShowIVideo::AddRef() {
    return InterlockedIncrement(&m_nRefCount) ;
  }

  ULONG __stdcall DirectShowIVideo::Release() {
    long nRefCount=0;
    nRefCount = InterlockedDecrement(&m_nRefCount) ;
    if (nRefCount == 0) delete this;
    return nRefCount;
  }

  bool DirectShowIVideo::seekPrecise(int frameNumber) {
    TRACE;
    VrRecoverableCheck(isOpen());
    VERBOSE("seeking precisely to frame " << frameNumber);
    if (frameNumber == currentFrameNumber) return true;

    if (frameNumber < 0) return false;
    if (frameNumber >= numFrames()) return false;
    if (frameNumber < currentFrameNumber) {
      // "imprecise" seeks to the first frame tend to be precise.  We rewind 
      // first in the case of backward seeks.
      if (!seekImprecise(0)) return false;
      if (frameNumber == 0) return true;
    }

    do {
      if (!synchronousFrameGrab(frameTimeoutMS_)) return false;
      currentFrameNumber++;
    } while (currentFrameNumber < frameNumber);

    return true;
  }

  bool DirectShowIVideo::seekImprecise(int frameNumber) {
    TRACE;
    VrRecoverableCheck(isOpen());
    VERBOSE("imprecise seek to frame " << frameNumber);
    if (frameNumber == currentFrameNumber) return true;

    if (frameNumber < 0) return false;
    if (frameNumber >= numFrames()) return false;

    VERBOSE("seeking (approximately) to frame " << frameNumber);

    // Unblock SampleCB and stop the graph
    quickExit = true;
    FatalAssert(SetEvent(dataTransferTrigger));
    // Recall that Stop is a blocking operation, so when it returns, we are 
    // guaranteed that no new calls to SampleCB will be made.
    FatalAssert(SUCCEEDED(pControl->Stop())); 
    quickExit = false;
    FatalAssert(ResetEvent(dataTransferred));
    FatalAssert(ResetEvent(dataTransferTrigger));

    // Have DirectShow seek
    REFERENCE_TIME seekTime = (timeFormat==TIME_FORMAT_FRAME)
      ? (REFERENCE_TIME)frameNumber
      : (REFERENCE_TIME)((10000000/framesPerSecond*(frameNumber+0.5)));
    FatalAssert(SUCCEEDED(pSeeking->SetPositions(&seekTime, 
      AM_SEEKING_AbsolutePositioning, NULL, AM_SEEKING_NoPositioning)));
#ifdef PRINT_VERBOSES
    VERBOSE("seekTime = " << seekTime);
    LONGLONG curr, stop;
    pSeeking->GetPositions(&curr, &stop);
    VERBOSE("After the SetPositions call but before allowing the frame to be "
      "read, DirectShow thinks the current timestamp is " << curr << 
      " and the stop position is " << stop);
#endif
    const int seekDist = (frameNumber < currentFrameNumber) ? 
      frameNumber+1 : (frameNumber - currentFrameNumber);
    const DWORD seekTimeout = 
      (DWORD)min<double>(numeric_limits<DWORD>::max()-1, 
                         ((double)seekDist)*frameTimeoutMS_);

    // Read the frame
    bool const worked = synchronousFrameGrab(seekTimeout);
    currentFrameNumber = (int)(sampleCbTime*framesPerSecond);
    if (!worked) return false;

    // Some decoders (namely libavcodec from ffdshow, as of Nov. 2007) 
    // consistently have an off-by-one error when seeking, but they are kind
    // enough to send the correct timestamp to SampleCB (but 
    // pSeeking->GetPositions is wrong).  Trust sampleCbTime and seek forward
    // precisely when needed.  Since we know this is a forward seek, we do
    // not need to worry about creating an infinite loop between this method
    // and seekPrecise.
    if (currentFrameNumber < frameNumber) {
      if (!seekPrecise(frameNumber)) return false;
    }

#ifdef PRINT_VERBOSES
    {
      LONGLONG curr, stop;
      pSeeking->GetPositions(&curr, &stop);
      VERBOSE("After allowing the frame to be read, DirectShow thinks the "
        "current timestamp is " << curr << " and the stop position is " << 
        stop);
    }
#endif

    return true;
  }
  
  // Called by the seek methods to safely coordinate with SampleCB to 
  // grab the desired frame.  
  bool DirectShowIVideo::synchronousFrameGrab(int maxTimeout) {
    // Make sure the filtergraph is running
    FatalAssert(SUCCEEDED(pControl->Run()));
    
    // Wait for SampleCB to get called (with a bunch of error checking)
    try {
      static const int waitIntervalMS = 1;
      for (int numWaits=0; true; numWaits++) {
        bool const waitWorked = 
          (WaitForSingleObject(dataReceived, waitIntervalMS) == WAIT_OBJECT_0);
        
        // Drain the filtergraph event queue under the assumption that it
        // can overflow.  Check for end-of-stream messages along the way.
        long evCode;
        LONG_PTR param1, param2;
        while (SUCCEEDED(pEvent->GetEvent(&evCode, &param1, &param2, 0))) {
          FatalAssert(SUCCEEDED(pEvent->FreeEventParams(evCode, param1, param2)));
          if (evCode == EC_COMPLETE) {
            // End-of-stream event received.  This often happens when 
            // DirectShow reported an incorrect video duration.  We 
            // correct nFrames now.  Making this correction lets the 
            // seek methods avoid having to keep track of missing final
            // frames separately.
            currentFrameNumber = int(sampleCbTime*framesPerSecond);
            nFrames            = currentFrameNumber + 1;
            return false;
          }
        }
        
        // Now that we've kept the event queue from filling up...
        if (waitWorked) break;
        
        // Check for timeouts
        if ((maxTimeout != INFINITE) && (maxTimeout > 0)) {
          if (numWaits >= maxTimeout / waitIntervalMS) {
            VrRecoverableThrow(
              "Timeout expired while waiting for a frame.  The most "
              "common causes are (a) reading files from slow or dead "
              "network connections or (b) having a CPU-intensive "
              "decoder.  Consider increasing the frameTimeoutMS "
              "parameter.");
          }
        }
      }
      
    } catch (...) {
      close(); throw;
    }
    
    // Tell SampleCB to proceed decoding the frame
    FatalAssert(ResetEvent(dataTransferred));
    FatalAssert(SetEvent(dataTransferTrigger));
    
    // Wait for SampleCB to get done 
    FatalAssert(WaitForSingleObject(dataTransferred, frameTimeoutMS_) == WAIT_OBJECT_0);
    VERBOSE("SampleCB thinks it decoded the sample at time " << 
      sampleCbTime << "s (frame " << currentFrameNumber << ").");
    
    return true;
  }

}; /* namespace VideoIO */
