#ifndef VFWOVIDEO_H
#define VFWOVIDEO_H

// $Date: 2008-11-17 17:39:15 -0500 (Mon, 17 Nov 2008) $
// $Revision: 706 $

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

#include "debug.h"
#include "OVideo.h"
#include "matarray.h"
#include "parse.h"

// Normal includes
#include <string>
#include <sstream>
#include <map>
#include <vector>
#include <math.h>
#include <limits>
#include <memory>

// VfW / DirectShow Includes
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
#include <vfw.h>
#pragma warning( pop )

namespace VideoIO 
{
  /** The VfwOVideo class is used to write AVI videos using Microsoft's
   *  Video for Windows (VfW) library.  This class was designed to be used by 
   *  the videoIO library for Matlab, but was written in a way that it can be 
   *  easily used in other contexts as a consise abstraction to VfW.
   *
   *  Note: the current implementation only supports AVI 1.0 files.  The 
   *  resulting AVI file will be cut off at 4GB.
   *
   *  Copyright (C) 2007 Gerald Dalley
   *
   *  This code is released under the MIT license (see the accompanying MIT.txt
   *  file for details).  
   */
  class VfwOVideo : public OVideo
  {
  public:
    //-------------------------------------------------------------------------
    // Constructors/Destructors
    VfwOVideo();
    virtual ~VfwOVideo();

    virtual void setup(KeyValueMap &kvm);

    //-------------------------------------------------------------------------
    // I/O Operations
    virtual void open(std::string const &fname);
    virtual void close();
    virtual void addframe(int w, int h, int d, IVideo::Frame const &f);

    //-------------------------------------------------------------------------
    // Only callable when canSetCompressionOptions(): 
    //   file is open, but no data has been written
    void showCompressionDialog();
    void setFourCcCodec(std::string const &fourcc);
    void setCodecParams(std::string const &params);
    void setCodecParams(const std::vector<uint8> &params);
    void setGopSize(int gs);
    void setBitRate(int br);
    void setQuality(int q);

    //-------------------------------------------------------------------------
    // Only callable when canSetFrameSpecs(): file is not open
    void setWidth(int w);
    void setHeight(int h);
    void setFramesPerSecond(double fps);
    void setFramesPerSecond(uint32 num, uint32 denom);

    //-------------------------------------------------------------------------
    // Callable any time.  
    bool isOpen()                   const { return aviFile != NULL; }
    bool canSetCompressionOptions() const;
    bool canSetFrameSpecs()         const;

    virtual int getWidth()   const { return width;  }
    virtual int getHeight()  const { return height; }
    virtual int getDepth()   const { return 3; }
            int getGopSize() const { return comprOpts.dwKeyFrameEvery; }
            int getBitRate() const { return comprOpts.dwBytesPerSecond * 8; }
            int getQuality() const { return comprOpts.dwQuality; }

    virtual KeyValueMap getSetupAndStats() const;

    const AVICOMPRESSOPTIONS *getAviCompressOptions() const { return &comprOpts; }
    std::string getCodecParams() const; // MIME Base64 encoded

  private:
    bool nothrowClose();

    int                 currentFrameNumber;  /// current working frame number

    std::string         filename;
    int                 width;
    int                 height;
    uint32              fpsNum, fpsDenom;

    PAVIFILE            aviFile;        /// AVI file interface
    PAVISTREAM          rawAviStream;   /// Raw video stream wrapper
    AVICOMPRESSOPTIONS  comprOpts;      /// Compression options
    PAVISTREAM          comprAviStream; /// Compressed video stream wrapper
    LPVOID              bmp;            /// Windows-friendly raw image buffer

    static const int MILLIS_PER_SECOND = 1000;

    /** Should be called internally before any AVIStreamWrite.  Sets up
     *  the actual AVI streams and preps them for writing if that work
     *  has not already been done. */
    void initStreamsIfNeeded();
    /** number of bytes in a bmp row */
    inline DWORD      getStride() const { return ((width*3 + 3)/4)*4; }
    /** Converts frame numbers to millisecond time */
    inline int64 F2T(int64 f) const
      { return ((int64)f * MILLIS_PER_SECOND) * fpsDenom / fpsNum; }
    /** Converts millisecond time to frame numbers */
    inline int64 T2F(int64 t) const
      { return ((int64)t * fpsNum) / ((int64)fpsDenom * MILLIS_PER_SECOND); } 
};

}; /* namespace VideoIO */

#endif 
