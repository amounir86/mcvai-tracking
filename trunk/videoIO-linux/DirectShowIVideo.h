#ifndef DirectShowIVideo_H
#define DirectShowIVideo_H

// $Date: 2008-11-28 21:00:03 -0500 (Fri, 28 Nov 2008) $
// $Revision: 709 $

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

// Because of the way Windows works, the user must first include windows.h
// before including this file.

// DirectShow
#include <Streams.h>
#pragma warning( push )
#pragma warning( disable: 4312 )
// tricks to remove the dependencies on dxtrans.h and similar files that 
// Microsoft's qedit.h still requires but have been removed from the 
// DirectX SDK (at least for November 2007 and March 2008).
#define __IDxtCompositor_INTERFACE_DEFINED__
#define __IDxtAlphaSetter_INTERFACE_DEFINED__
#define __IDxtJpeg_INTERFACE_DEFINED__
#define __IDxtKey_INTERFACE_DEFINED__
#include <qedit.h>
#include <atlbase.h>
#define NO_DSHOW_STRSAFE
#include <dshow.h>
#include <wxdebug.h>
#pragma warning( pop )
#undef min
#undef max
#include <dvdmedia.h>

#include <vector>
#include <string>
#include "debug.h"
#include "IVideo.h"

// When defined, we add our filtergraph to Windows Running Object Table 
// (ROT).  This allows other applications, most notably GraphEdit, to
// inspect our filtergraph.  This is sometimes useful for debugging 
// codec issues.
//#define ADDTOROT

namespace VideoIO 
{

  // AO = "Assert Open"
#undef AO
#define AO VrRecoverableCheck(isOpen())

  /**
   * Enables reading video files on Windows system.  
   *
   * The general design and especially the core interaction model between 
   * DirectShowIVideo::seek and DirectShowIVideo::SampleCB is based off work by
   * Josh Migdal (jmigdal@mit.edu).
   */
  class DirectShowIVideo : public IVideo, ISampleGrabberCB
  {
  public:
    DirectShowIVideo();
    virtual ~DirectShowIVideo() { TRACE; close(); }

    virtual void         open(KeyValueMap &kvm);
    virtual void         close();
    virtual bool         next()            { AO; return step(); }
    virtual bool         step(int delta=1) { AO; return seek(currentFrameNumber+delta); }
    virtual bool         seek(int toFrame);
    virtual int          currFrameNum() const { AO; return currentFrameNumber; }
    virtual Frame const &currFrame()    const { AO; return currentFrame; } 

    virtual std::string  filename()             const { AO; return fname;                        }
    virtual int          width()                const { AO; return w;                            }
    virtual int          height()               const { AO; return h;                            }
    virtual int          depth()                const { AO; return d;                            }
    virtual double       fps()                  const { AO; return framesPerSecond;              }
    virtual int          numFrames()            const { AO; return nFrames - nHiddenFinalFrames; }
    virtual FourCC       fourcc()               const { AO; return fourCC;                       }
    virtual int          numHiddenFinalFrames() const { AO; return nHiddenFinalFrames;           }
    
    virtual ExtraParamsAndStats extraParamsAndStats() const;
    inline  int                 frameTimeoutMS()      const { AO; return frameTimeoutMS_;              }

    // ISampleGrabberCB interface methods.  
    STDMETHODIMP_(ULONG) AddRef(); 
    STDMETHODIMP_(ULONG) Release();
    STDMETHODIMP QueryInterface(REFIID riid, void ** ppv);
    STDMETHODIMP BufferCB( double SampleTime, BYTE * pBuffer, long BufferLen ) { return 0; }
    STDMETHODIMP SampleCB( double SampleTime, IMediaSample * pSample );

  private:
    inline bool isOpen() const { return (fname.size() > 0); } 
           bool seekPrecise(int toFrame);
           bool seekImprecise(int toFrame);
           void parseOpenArgs(KeyValueMap &kvm); // call from open() only

    std::string fname;
    int         nFrames;
    double      framesPerSecond;
    int         w, h, d;
    int         currentFrameNumber; // NOTE: if any imprecise seek is done, this value is an *estimate*
    FourCC      fourCC;
    int         nHiddenFinalFrames;
    GUID        timeFormat;

    int         preciseFrames;
    int         frameTimeoutMS_;

    double      sampleCbTime; // frame time according to SampleCB, in seconds.  Only valid after dataTransferred has been raised.

    bool quickExit;
    HANDLE dataReceived, dataTransferTrigger, dataTransferred;

    /** Decoded, matlab byte-ordered frame */
    Frame currentFrame; 

    // pointer to IMediaDet interface (Platform SDK)
    CComPtr<IMediaDet>      pDet;                           
    // sample grabber interface
    CComPtr<ISampleGrabber> pGrabber;
    // seeking interface
    CComQIPtr<IMediaSeeking, &IID_IMediaSeeking> pSeeking;  
    // media control interface (stop, run, pause, etc)
    CComQIPtr<IMediaControl, &IID_IMediaControl> pControl;  
    // receives messages from the filtergraph
    CComQIPtr<IMediaEvent,   &IID_IMediaEvent>   pEvent;
    
    std::vector<std::string> extraDirectShowFilterNames;

#ifdef ADDTOROT
    DWORD dwRegister;
#endif
    long  m_nRefCount;

    void parseMediaType(AM_MEDIA_TYPE *pMediaType);
    /*__declspec(noalias)*/ HRESULT shuffleImageBytes(IMediaSample *pSample);
    bool synchronousFrameGrab(int maxTimeout);
  };

#undef AO

}; /* namespace VideoIO */

#endif
