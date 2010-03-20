#ifndef DIRECTSHOWOVIDEO_H
#define DIRECTSHOWOVIDEO_H

// $Date: 2008-11-29 21:47:27 -0500 (Sat, 29 Nov 2008) $
// $Revision: 715 $

/*
videoIO: granting easy, flexible, and efficient read/write access to video 
                 files in Matlab on Windows and GNU/Linux platforms.
    
Copyright (c) 2008 Gerald Dalley
  
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

#include "debug.h"
#include "OVideo.h"
#include "matarray.h"
#include "parse.h"

// Normal includes
#include <string>
#include <vector>
#include <math.h>
#include <memory>

// DirectShow Includes
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
#ifndef __STREAMS__
#  define NO_DSHOW_STRSAFE
#  include <dshow.h>
#  include <wxdebug.h>
#endif
#include <dshow.h>
#pragma warning( pop )

namespace VideoIO 
{
  class CBlockingSource;

  /** The DirectShowOVideo class is used to write AVI videos using Microsoft's
   *  DirectShow library.  This class was designed to be used by the 
   *  videoIO library for Matlab, but was written in a way that it can be 
   *  easily used in other contexts as a consise abstraction to DirectShow.
   *
   *  Copyright (C) 2008 Gerald Dalley
   *
   *  This code is released under the MIT license (see the accompanying MIT.txt
   *  file for details).  
   */
  class DirectShowOVideo : public OVideo
  {
  public:
    //-------------------------------------------------------------------------
    // Constructors/Destructors
    DirectShowOVideo();
    virtual ~DirectShowOVideo();

    virtual void setup(KeyValueMap &kvm);

    //-------------------------------------------------------------------------
    // I/O Operations
    virtual void open(std::string const &fname);
    virtual void close();
    virtual void addframe(int w, int h, int d, IVideo::Frame const &f);

    //-------------------------------------------------------------------------
    // Only callable when canSetCodec(): 
    //   no data has been written
    void setCodec(std::string const &name);

    //-------------------------------------------------------------------------
    // Only callable when canSetCompressionOptions(): 
    //   file is open, codec is set, no data has been written
    void setCodecParams(std::string const &params64); // MIME Base64 encoded
    void setCodecParams(const std::vector<uint8> &paramsRaw);
    void showCompressionDialog(); // the codec must be set first too

    //-------------------------------------------------------------------------
    // Only callable when canSetFrameSpecs(): 
    //   no data has been written
    void setSize(int w, int h);
    void setWidth(int w)  { setSize(w, getHeight()); };
    void setHeight(int h) { setSize(getWidth(), h);  };
    void setFramesPerSecond(double fps);
    void setFramesPerSecond(uint32 num, uint32 denom);

    //-------------------------------------------------------------------------
    // Callable any time.  
    bool isOpen()                   const;
    bool canSetCodec()              const;
    bool canSetCompressionOptions();
    void checkCanSetCompressionOptions();
    bool canSetFrameSpecs()         const;

    virtual int getWidth()   const;
    virtual int getHeight()  const;
    virtual int getDepth()   const { return 3; }

    virtual KeyValueMap getSetupAndStats() const;

    std::string getFilename()    const;

    std::string getCodec()       const { return codecName; }
    std::string getCodecParams() const; // MIME Base64 encoded

  private:
    bool nothrowClose();
    void breakApartFiltergraph();
    void connectFiltergraphIfNeeded();
    bool filtergraphIsConnected;
    void addSourceIfNeeded();

    CComPtr<ICaptureGraphBuilder2> builder;
    CComPtr<IGraphBuilder>         graph;
    CComPtr<IMediaControl>         mediaCtrl;

    CBlockingSource               *source;
    CComPtr<IBaseFilter>           compressor;
    std::string                    codecName;
    CComPtr<IBaseFilter>           renderer;
    CComPtr<IFileSinkFilter>       sink;

    static const int MILLIS_PER_SECOND = 1000;

    /** number of bytes in a bmp row */
    inline DWORD      getStride() const { return ((getWidth()*3 + 3)/4)*4; }
  };

}; /* namespace VideoIO */

#endif 
