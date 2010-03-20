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

#include "VfwOVideo.h"
#include "debug.h"
#include "registry.h"
#include "WinCommon.h"
#include <wchar.h>
#include <comutil.h>
#include <Streams.h>
#include <atlenc.h>

#include <mex.h>
#include <vfw.h>

using namespace std;

static int const DEFAULT_FPS_NUM   = 30000;
static int const DEFAULT_FPS_DENOM =  1001;

// Useful sources of information:
//    http://www.adp-gmbh.ch/win/programming/avi/avi.html
//      Simple AVI writer class
//
//    http://www.codeproject.com/bitmap/createmovie.asp?df=100&forumid=23466&exp=0&select=1130461
//      This shows how to create WMV and QT movies.

// Adapted from http://www.adp-gmbh.ch/win/programming/avi/avi.html
inline static const char *getErrMessage(HRESULT code) { 
  const char *msg = NULL;
  switch (code) { 
  case S_OK:                  return "Success"; break;
  case AVIERR_BADFORMAT:      return "AVIERR_BADFORMAT: corrupt file or unrecognized format"; break;
  case AVIERR_MEMORY:         return "AVIERR_MEMORY: insufficient memory"; break;
  case AVIERR_FILEREAD:       return "AVIERR_FILEREAD: disk error while reading file"; break;
  case AVIERR_FILEOPEN:       return "AVIERR_FILEOPEN: disk error while opening file"; break;
  case REGDB_E_CLASSNOTREG:   return "REGDB_E_CLASSNOTREG: file type not recognised"; break;
  case AVIERR_READONLY:       return "AVIERR_READONLY: file is read-only"; break;
  case AVIERR_NOCOMPRESSOR:   return "AVIERR_NOCOMPRESSOR: a suitable compressor could not be found"; break;
  case AVIERR_UNSUPPORTED:    return "AVIERR_UNSUPPORTED: compression is not supported for this type of data"; break;
  case AVIERR_INTERNAL:       return "AVIERR_INTERNAL: internal error"; break;
  case AVIERR_BADFLAGS:       return "AVIERR_BADFLAGS"; break;
  case AVIERR_BADPARAM:       return "AVIERR_BADPARAM"; break;
  case AVIERR_BADSIZE:        return "AVIERR_BADSIZE"; break;
  case AVIERR_BADHANDLE:      return "AVIERR_BADHANDLE"; break;
  case AVIERR_FILEWRITE:      return "AVIERR_FILEWRITE: disk error while writing file"; break;
  case AVIERR_COMPRESSOR:     return "AVIERR_COMPRESSOR"; break;
  case AVIERR_NODATA:         return "AVIERR_READONLY"; break;
  case AVIERR_BUFFERTOOSMALL: return "AVIERR_BUFFERTOOSMALL"; break;
  case AVIERR_CANTCOMPRESS:   return "AVIERR_CANTCOMPRESS"; break;
  case AVIERR_USERABORT:      return "AVIERR_USERABORT"; break;
  case AVIERR_ERROR:          return "AVIERR_ERROR"; break;
  }
  return "";
}

#define Win32Call(code) \
{ HRESULT hr = code; if (FAILED(hr)) { \
  VrRecoverableThrow( \
  "AVI Error 0x" << std::hex << hr << ": " << getErrMessage(hr));\
} }

#define Win32Warn(code) \
{ HRESULT hr = code; \
  if (FAILED(hr)) { \
  PRINTWARN("error calling " << #code << ".  Error code: 0x" <<\
            std::hex << code << ": " << getErrMessage(code));\
  worked = false;\
  } \
}

namespace VideoIO  
{
  
  class VfwOVideoManager : public OVideoManager
  {
  public:
    virtual std::set<std::string> getcodecs() throw()
    {
      set<string> codecs;

      CodecEnumerator e(CLSID_VideoCompressorCategory, true);
      while (e.next()) {
        // only look at the fccHandlers
        string const fcc = e.fccHandler();
        if (fcc.size()) codecs.insert(fcc);
      }

      return codecs;
    }
    
    virtual OVideo *createVideo() throw() {
      return new(nothrow) VfwOVideo();
    }
    
  };
  
  static auto_ptr<OVideoManager> oldManager(
    registerOVideoManager(new VfwOVideoManager()));

  VfwOVideo::VfwOVideo() :
    width(-1), height(-1),
    fpsNum(DEFAULT_FPS_NUM), fpsDenom(DEFAULT_FPS_DENOM), 
    filename(""), currentFrameNumber(0), aviFile(NULL), rawAviStream(NULL),
    comprAviStream(NULL), bmp(NULL)
  { 
    TRACE;
    coInitIfNeeded();
    AVIFileInit();  

    // Set up default compression options
    ::ZeroMemory(&comprOpts,sizeof(comprOpts));
    comprOpts.fccType         = streamtypeVIDEO;
    // Uncompressed by default
    comprOpts.fccHandler      = mmioFOURCC('D','I','B',' '); 
    // retain options when opening dialog
    comprOpts.dwFlags         = AVICOMPRESSF_VALID; 
    // default to a keyframe every 100 frames
    comprOpts.dwFlags        |= AVICOMPRESSF_KEYFRAMES;
    comprOpts.dwKeyFrameEvery = 100; 
    // default to high quality for old codecs
    comprOpts.dwQuality = 10000; 
  }

  VfwOVideo::~VfwOVideo() { 
    TRACE;

    bool worked = true;

    // Close the file if it's open
    nothrowClose(); 

    // Clean up compression options if any memory was allocated for
    // holding codec-specific parameters
    AVICOMPRESSOPTIONS *opts[1];
    opts[0] = &comprOpts;
    Win32Warn(AVISaveOptionsFree(1, opts));

    AVIFileExit(); 
  }

  void VfwOVideo::setup(KeyValueMap &kvm) {
    TRACE;
    
    int fpsNum, fpsDenom;
    if (kvm.fpsParse(fpsNum, fpsDenom)) {
      setFramesPerSecond(fpsNum, fpsDenom);
    }

    if (kvm.hasKey("width")) {
      setWidth(kvm.parseInt<int>("width"));
    }
    if (kvm.hasKey("height")) {
      setHeight(kvm.parseInt<int>("height"));
    }

    if (kvm.hasKey("filename")) open(kvm.find("filename")->second);

    // Codec specified by FourCC code
    if (kvm.hasKey("fourcc")) {
      string const &fourcc = kvm.find("fourcc")->second;
      VrRecoverableCheckMsg(fourcc.size() == 4, 
                            "VfW codec fourcc codes must be exactly "
                            "4 characters long.");
      setFourCcCodec(fourcc);
    }
    if (kvm.hasKey("codec")) {
      string const &fourcc = kvm.find("codec")->second;
      VrRecoverableCheckMsg(fourcc.size() == 4, 
                            "VfW codec fourcc codes must be exactly "
                            "4 characters long.");
      setFourCcCodec(fourcc);
    }

    if (kvm.hasKey("codecParams")) {
      string const &params = kvm.find("codecParams")->second;
      setCodecParams(params);
    }

    if (kvm.hasKey("gopSize")) {
      setGopSize(kvm.parseInt<int>("gopSize"));
    }
    
    if (kvm.hasKey("bitRate")) {
      setBitRate(kvm.parseInt<int>("bitRate"));
    }

    if (kvm.hasKey("quality")) {
      setQuality(kvm.parseInt<int>("quality"));
    }
    
    if (kvm.hasKey("showCompressionDialog")) {
      if (kvm.parseInt<int>("showCompressionDialog")) {
        showCompressionDialog();
      }
    }


    kvm.alertUncheckedKeys("Unrecognized arguments: ");
  }

#define assnString(lval, x) \
  { stringstream ss; ss << x; lval = ss.str(); }

  KeyValueMap VfwOVideo::getSetupAndStats() const {
    TRACE;
    KeyValueMap kvm;
    // setup
    assnString(kvm["fps"],          ((double)fpsNum) / fpsDenom);
    assnString(kvm["width"],        width);
    assnString(kvm["height"],       height);
    assnString(kvm["gopSize"],      comprOpts.dwKeyFrameEvery);
    assnString(kvm["bitRate"],      getBitRate());
    assnString(kvm["quality"],      getQuality());
               kvm["filename"]    = filename;
               kvm["codec"]       = fourCCToString(comprOpts.fccHandler);
               kvm["codecParams"] = getCodecParams();
    
    // stats
    assnString(kvm["currFrameNumber"], currentFrameNumber);

    return kvm;
  }

  /** Opens up a new AVI file (implicitly scheduling the erasure of any 
  *  previous file with the same name).  Fails if isOpen(). */
  void VfwOVideo::open(std::string const &filename) {
    TRACE;
    VrRecoverableCheckMsg(!isOpen(),  
                          "This video object is already open.  Close it "
                          "before trying to open a new file.");

    try {
      this->filename = filename;

      Win32Call(AVIFileOpen(&aviFile, filename.c_str(), 
                            OF_WRITE | OF_CREATE, NULL));
    } catch(...) {
      nothrowClose(); 
      throw;
    }
  }

  bool VfwOVideo::nothrowClose() {
    TRACE;
    bool worked = true;

    if (bmp)            { Win32Warn(GlobalFreePtr(bmp));               bmp            = NULL; }
    if (comprAviStream) { Win32Warn(AVIStreamRelease(comprAviStream)); comprAviStream = NULL; }
    if (rawAviStream)   { Win32Warn(AVIStreamRelease(rawAviStream));   rawAviStream   = NULL; }
    if (aviFile)        { Win32Warn(AVIFileRelease(aviFile));          aviFile        = NULL; }
    
    filename = ""; 
    this->currentFrameNumber = 0; // Frames are 0-indexed

    return worked;
  }

  void VfwOVideo::close() {
    // Something really wrong happened if anything in close failed!
    VrFatalCheck(nothrowClose());
  }

#define FancyAssertEq(N,V,EXP) \
  VrRecoverableCheckMsg(V == EXP, \
  "Expected the " << N << " to be " << (EXP) << ", but it is " << (V) << ".");

  void VfwOVideo::addframe(int w, int h, int d, IVideo::Frame const &f) {
    TRACE;
    VrRecoverableCheckMsg(isOpen(), "The video is not open, so frames cannot "
                          "be added.");

    if (getWidth()  < 0) setWidth(w);
    if (getHeight() < 0) setHeight(h);

    FancyAssertEq("width",  w, getWidth());
    FancyAssertEq("height", h, getHeight());
    FancyAssertEq("depth",  d, getDepth());
    FancyAssertEq("number of elements in the frame", f.size(), w*h*d);

    try {
      initStreamsIfNeeded();

      matlab2bgr((uint8*)GlobalLock(bmp), &f[0], getStride(), w, h, d);

      // Write out a single frame.  Don't worry about checking the number of 
      // samples or bytes written out.
      Win32Call(AVIStreamWrite(comprAviStream, currentFrameNumber, 1, 
        (uint8*)bmp, getStride() * getHeight(), AVIIF_KEYFRAME, NULL, NULL)); 

      currentFrameNumber++;

      GlobalUnlock(bmp); 

    } catch(...) {
      GlobalUnlock(bmp);
      nothrowClose();
      throw;
    }
  }

  /** Allows the user to manually select compression options using a GUI.
  *  Can only be called after open(const char*) and before the first 
  *  call to next(), step(int64), or seek(int64).  The 
  *  canSetCompressionOptions() method may be used to determine if it's 
  *  too late to call this method. 
  */
  void VfwOVideo::showCompressionDialog() {
    TRACE;
    // Make sure we haven't started compress yet (you can't change
    // codecs mid-stream).
    VrRecoverableCheckMsg(canSetCompressionOptions(), 
      "The compression dialog cannot be shown now.  Compression options may "
      "only be set after the video is open but before any frames have been "
      "added.");

    // Let the user select the default keyframe interval and data rate
    // if they are applicable to the codec chosen.  We don't supply a
    // preview (since we'd need to require that the application supply
    // some sample frames to do that).  
    const UINT uiflags = ICMF_CHOOSE_KEYFRAME | ICMF_CHOOSE_DATARATE; 
    int const nStreams = 1; // Just one video stream
    AVICOMPRESSOPTIONS *optsArr[1];
    optsArr[0] = &comprOpts;
    VrRecoverableCheckMsg(AVISaveOptions(GetForegroundWindow(), 
                                         uiflags, nStreams,
                                         &rawAviStream, optsArr),
                          "Could not launch the compression dialog");
  }

  /** Sets the codec to use by specifying the fourcc code for it.
  *  See http://www.fourcc.org/indexcod.htm?main=codecs.php for
  *  a base lists of fourcc video codecs.  Note that the codec DLLs
  *  must be installed in order for the compression to work. 
  *  Note that the fourcc codes are case-sensitive, so 
  *  "DIB " != "dib ". */
  void VfwOVideo::setFourCcCodec(string const &fourcc) {
    TRACE;
    // Make sure we haven't started compress yet (you can't change
    // codecs mid-stream).
    VrRecoverableCheckMsg(canSetCompressionOptions(), 
      "The codec's fourcc code cannot be set now.  Compression options may "
      "only be set after the video is open but before any frames have been "
      "added.");
    FancyAssertEq("fourcc code's string length", fourcc.size(), 4);
    comprOpts.fccHandler = 
      mmioFOURCC(fourcc[0], fourcc[1], fourcc[2], fourcc[3]);
  }

  string VfwOVideo::getCodecParams() const {
    TRACE;
    if (comprOpts.cbParms == 0) return "";

    string base64;
    base64.resize(getAviCompressOptions()->cbParms*2);  
    int outLen = (int)base64.size();
    VrRecoverableCheckMsg(
      Base64Encode((BYTE const *)comprOpts.lpParms, comprOpts.cbParms,
                   &base64[0], &outLen,
                   ATL_BASE64_FLAG_NOPAD | ATL_BASE64_FLAG_NOCRLF),
      "MIME Base64 encoding of the codec parameter string failed.  This "
      "should never happen.");
    base64.resize(outLen);
    return base64;
  }

  void VfwOVideo::setCodecParams(std::string const &params) {
    TRACE;
    std::vector<uint8> v(params.size());
    int outSize = (int)v.size();
    VrRecoverableCheckMsg(Base64Decode(params.c_str(), (int)params.size(),
                                       (BYTE*)&v[0], &outSize),
                          "MIME Base64 decoding of parameter string failed.");
    v.resize(outSize);
    return setCodecParams(v);
  }

  void VfwOVideo::setCodecParams(const std::vector<uint8> &params) {
    TRACE;
    // Make sure we haven't started compress yet (you can't change
    // codecs mid-stream).
    VrRecoverableCheckMsg(canSetCompressionOptions(), 
      "The codec's parameters cannot be set now.  Compression options may "
      "only be set after the video is open but before any frames have been "
      "added.");

    if (comprOpts.lpParms != NULL) {
      comprOpts.cbParms = 0;
      free(comprOpts.lpParms);
      comprOpts.lpParms = NULL;
    }

    uint8 *p = (uint8 *)malloc(params.size());
    for (size_t x=0; x<params.size(); x++) p[x] = params[x];

    comprOpts.cbParms = (DWORD)params.size();
    comprOpts.lpParms = p;
  }

  void VfwOVideo::setBitRate(int br) {
    TRACE;
    // NOTE: most useful codecs ignore this option
    // Make sure we haven't started compress yet (you can't change
    // codecs mid-stream).
    VrRecoverableCheckMsg(canSetCompressionOptions(), 
      "The bitrate cannot be set now.  Compression options may "
      "only be set after the video is open but before any frames have been "
      "added.");

    if (br<=0) {
      comprOpts.dwBytesPerSecond = 0;
      comprOpts.dwFlags &= !AVICOMPRESSF_DATARATE;
    } else {
      // if bitrate given in kilobits per sec instead of bits per sec
      if (br < 1024) br *= 1024;

      int const byteRate = br/8;

      comprOpts.dwBytesPerSecond = byteRate;
      comprOpts.dwFlags |= AVICOMPRESSF_DATARATE;
    }
  }
  
  void VfwOVideo::setQuality(int q) {
    TRACE;
    // NOTE: most useful codecs ignore this option
    // Make sure we haven't started compress yet (you can't change
    // codecs mid-stream).
    VrRecoverableCheckMsg(canSetCompressionOptions(), 
      "The quality cannot be set now.  Compression options may "
      "only be set after the video is open but before any frames have been "
      "added.");

    VrRecoverableCheckMsg(q >= 0, 
      "The video quality must be non-negative: " << q << " was supplied.");
    comprOpts.dwQuality = q;
  }

  void VfwOVideo::setGopSize(int sz) {
    TRACE;
    // NOTE: most useful codecs ignore this option
    VrRecoverableCheckMsg(canSetCompressionOptions(), 
      "The GOP size cannot be set now.  Compression options may "
      "only be set after the video is open but before any frames have been "
      "added.");

    if (sz<=0) {
      comprOpts.dwKeyFrameEvery = 0;
      comprOpts.dwFlags &= !AVICOMPRESSF_KEYFRAMES;
    } else {
      comprOpts.dwKeyFrameEvery = sz;
      comprOpts.dwFlags |= AVICOMPRESSF_KEYFRAMES;
    }
  }

  void VfwOVideo::setWidth(int w) {
    TRACE;
    VrRecoverableCheckMsg(canSetFrameSpecs(), 
      "The video width cannot be set now.  The video's frame specification "
      "can only be modified before opening the video.");
    VrRecoverableCheckMsg(w > 0, 
      "The video width must be positive: " << w << " was supplied.");
    width = w;
  }

  void VfwOVideo::setHeight(int h) {
    TRACE;
    VrRecoverableCheckMsg(canSetFrameSpecs(), 
      "The video height cannot be set now.  The video's frame specification "
      "can only be modified before opening the video.");
    VrRecoverableCheckMsg(h > 0, 
      "The video height must be positive: " << h << " was supplied.");
    height = h;
  }

  void VfwOVideo::setFramesPerSecond(double fps) {
    TRACE;
    VrRecoverableCheckMsg(canSetFrameSpecs(), 
      "The frame rate cannot be set now.  The video's frame specification "
      "can only be modified before opening the video.");
    VrRecoverableCheckMsg(fps > 0, 
      "The frame rate must be positive: " << fps << " was supplied.");
    fpsNum   = (uint32)(fps * 1000);
    fpsDenom = 1000;
  }

  void VfwOVideo::setFramesPerSecond(uint32 num, uint32 denom) {
    TRACE;
    VrRecoverableCheckMsg(canSetFrameSpecs(), 
      "The frame rate cannot be set now.  The video's frame specification "
      "can only be modified before opening the video.");
    fpsNum   = num;
    fpsDenom = denom;
  }

  bool VfwOVideo::canSetCompressionOptions() const {
    return isOpen() && (comprAviStream == NULL); 
  }

  bool VfwOVideo::canSetFrameSpecs() const {
    return (rawAviStream == NULL); 
  }

  void VfwOVideo::initStreamsIfNeeded() {
    TRACE; 
    if (!isOpen()) return;

    // No work needed if we already have already configured the compressed
    // video stream.
    if (comprAviStream) return;

    try {
      // Create the raw stream
      if (rawAviStream == NULL) {
        AVISTREAMINFO strhdr;
        ::ZeroMemory(&strhdr,sizeof(strhdr)); // most fields ignored for wrapper stream
        strhdr.fccType               = streamtypeVIDEO; 
        strhdr.dwRate                = fpsNum; 
        strhdr.dwScale               = fpsDenom;                  
        strhdr.dwSuggestedBufferSize = getStride() * getHeight();
        SetRect(&strhdr.rcFrame, 0, 0, width, height);
        ::ZeroMemory(strhdr.szName, sizeof(strhdr.szName));
        strncpy(strhdr.szName, "VfwOVideo Output", sizeof(strhdr.szName)-1); 
        
        Win32Call(AVIFileCreateStream(aviFile, &rawAviStream, &strhdr));
      }

      // Set up compressed stream
      Win32Call(AVIMakeCompressedStream(&comprAviStream, rawAviStream, &comprOpts, 0));

      // Set up input format as bottom-up BGR images because VfW
      // can't handle anything else :( 
      BITMAPINFOHEADER bi;
      ::ZeroMemory(&bi, sizeof(bi)); // default values are 0 for most fields
      bi.biSize = sizeof(BITMAPINFOHEADER);
      bi.biWidth = width;
      bi.biHeight = height; // bottom-up
      bi.biPlanes = 1;
      bi.biBitCount = 24;
      bi.biCompression = BI_RGB; // Really BGR
      bi.biSizeImage = getStride() * getHeight(); 
      Win32Call(AVIStreamSetFormat(comprAviStream, 0, &bi, sizeof(bi)));

      // Allocate space for the BGR image
      bmp = GlobalAllocPtr(GMEM_MOVEABLE|GMEM_ZEROINIT, bi.biSizeImage);
    } catch(...) {
      nothrowClose();
      throw;
    }
  }
};
