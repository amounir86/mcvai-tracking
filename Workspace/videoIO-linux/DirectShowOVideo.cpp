// $Date: 2008-11-29 22:27:18 -0500 (Sat, 29 Nov 2008) $
// $Revision: 716 $

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

#define _WIN32_WINNT 0x0501
#define WINVER       0x0501 // Require WinXP for now
#pragma warning (disable: 4995) // ignore stdio deprecation warnings
#define WIN32_LEAN_AND_MEAN
#define _AFXDLL
#include <afxmt.h>
//#include <windows.h>
#include <atlstr.h>
#include <time.h>
#include <sys/timeb.h>
#include <iostream>
#include <sstream>
#include <wchar.h>
#undef TRACE

#include "debug.h"
#include "DirectShowOVideo.h"
#include "registry.h"
#include "parse.h"
#include "WinCommon.h"

#include <atlbase.h>
#include <atlenc.h>
#include <Streams.h>
#include <comutil.h>
#include <vfw.h>
#undef max
#undef min

using namespace std;
using namespace VideoIO;

static int const DEFAULT_FPS_NUM   = 30000;
static int const DEFAULT_FPS_DENOM =  1001;

static char NO_CODEC_TOKEN[]      = "NONE";
static char DEFAULT_CODEC_TOKEN[] = "DEFAULT";

#define FILTER_NAME L"Blocking Frame Source"

#include <initguid.h>
// {AEC5C753-5B75-4da2-987A-EDF99AEE4DEF}
DEFINE_GUID(CLSID_BlockingFrameSource, 
0xaec5c753, 0x5b75, 0x4da2, 0x98, 0x7a, 0xed, 0xf9, 0x9a, 0xee, 0x4d, 0xef);

static HWND getRootWindow()
{
  DWORD const phandle = GetCurrentProcessId();
  // Adapted from http://www.programmersheaven.com/mb/mfc_coding/190927/190927/how-to-get-hwnd/?S=B20000
  HWND h = GetTopWindow(0);
  while (h) {
    DWORD pid;
    DWORD dwTheardId = ::GetWindowThreadProcessId( h,&pid);

    if (pid == phandle) {
      return h;
    }
    h = ::GetNextWindow( h , GW_HWNDNEXT);
  }
  return 0;
}

static bool showVfwCompressionDialog(IBaseFilter *pfCompressor, 
                                     vector<uint8> &state)
{
  // By calling ShowDialog with VfwCompressDialog_Config, we are able to 
  // make the second call to GetState actually work.
  CComQIPtr<IAMVfwCompressDialogs> pCompressDlg(pfCompressor);
  if (pCompressDlg == NULL) return false;
  if (!SUCCEEDED(pCompressDlg->ShowDialog(
    VfwCompressDialog_Config, getRootWindow()))) return false;
  int stateLen = 0;
  RecoverableHresultCheck(pCompressDlg->GetState(NULL, &stateLen));
  state.resize(0);
  state.resize(stateLen);
  RecoverableHresultCheck(pCompressDlg->GetState(&state[0], &stateLen));
  return true;
}

static bool getVfwCompressionState(IBaseFilter *pfCompressor, 
                                   vector<uint8> &state)
{
  // Calling ShowDialog with VfwCompressDialog_QueryConfig is partially broken.
  // We cannot do the real GetState call.  Instead, we can call 
  // SendDriverMessage, but only if we're lucky enough and the state vector
  // lies in the first 2GB of address space: the method does not appear to be
  // 64-bit safe.
  //
  // How it *should* work:
  //   http://msdn.microsoft.com/en-us/library/ms787544(VS.85).aspx
  // How to work around MSFT bugs:
  //   http://groups.google.co.jp/group/microsoft.public.win32.programmer.directx.video/browse_thread/thread/7a40ec6496617335?tvc=2
  CComQIPtr<IAMVfwCompressDialogs> pCompressDlg(pfCompressor);
  if (pCompressDlg == NULL) return false;
  if (!SUCCEEDED(pCompressDlg->ShowDialog(
    VfwCompressDialog_QueryConfig, getRootWindow()))) return false;
  int stateLen = 0;
  RecoverableHresultCheck(pCompressDlg->GetState(NULL, &stateLen));
  VrRecoverableCheckMsg((size_t)&state[0] <= 0x7fffFFFF,
    "The SendDriverMessage method is not 64-bit safe and the state vector "
    "has been allocated to an address that sits beyond the allowable 2GB "
    "boundary.  Find a way to allocate it at a lower address.");
  state.resize(0);
  state.resize(stateLen);
  RecoverableHresultCheck(pCompressDlg->SendDriverMessage(
    ICM_GETSTATE, (long)(size_t)&state[0], stateLen)); 
  return true;
}

static bool setVfwCompressionState(IBaseFilter *pfCompressor,
                                   vector<uint8> const &state)
{
  CComQIPtr<IAMVfwCompressDialogs> pCompressDlg(pfCompressor);
  if (pCompressDlg == NULL) return false;
  // need to all ShowDialog to get the object initialized
  if (!SUCCEEDED(pCompressDlg->ShowDialog(
    VfwCompressDialog_QueryConfig, getRootWindow()))) return false;
  VrRecoverableCheck(state.size() <= (size_t)numeric_limits<int>::max());
  // now we can use SetState... if this fails, we may need to do a call to
  // SendDriverMessage instead (which is not 64-bit safe).
  RecoverableHresultCheck(pCompressDlg->SetState(
    (LPVOID)&state[0], (int)state.size()));
  return true;
}

static bool showDShowCompressionDialog(IBaseFilter *pfCompressor) 
{
  CComQIPtr<ISpecifyPropertyPages> specify(pfCompressor);
  if (specify == NULL) return false;
  CAUUID	pagelist;
  if (SUCCEEDED(specify->GetPages(&pagelist))) {
    RecoverableHresultCheck(OleCreatePropertyFrame(
      getRootWindow(), 30, 30, L"Compression Options", 1, 
      (IUnknown **)&pfCompressor, 
      pagelist.cElems, pagelist.pElems, 0, 0, NULL)); 

    // free used memory
    if (pagelist.pElems) CoTaskMemFree(pagelist.pElems);
  }
  return true;
}

namespace VideoIO  
{  
  class DirectShowOVideoManager : public OVideoManager
  {
  public:
    virtual std::set<std::string> getcodecs() throw() {
      set<string> codecs;

      CodecEnumerator e(CLSID_VideoCompressorCategory, false);
      while (e.next()) {
        string const friendlyName = e.friendlyName();
        if (friendlyName.size()) codecs.insert(friendlyName);
        string const fcc = e.fccHandler();
        if (fcc.size()) codecs.insert(fcc);
      }
    
      return codecs;
    }
    
    virtual OVideo *createVideo() throw() {
      return new(nothrow) DirectShowOVideo();
    }
   
  };
  
  static auto_ptr<OVideoManager> oldManager(
    registerOVideoManager(new DirectShowOVideoManager()));


  static double const codecSel = rand() / (double)RAND_MAX;

  static std::string randSelCodec() {
    set<string> c = oVideoManager()->getcodecs();
    size_t which = (size_t)(codecSel * c.size());
    set<string>::const_iterator it = c.begin();
    for (size_t i=0; i<which; i++, it++);
    return *it;
  }

  static void setMostRecentCodecName(std::string codecName) {
    HKEY key;
    DWORD disposition;

    if (ERROR_SUCCESS != RegCreateKeyEx(HKEY_CURRENT_USER, 
      TEXT("Software\\dalleyg\\videoIO"), 0, NULL, 
      REG_OPTION_NON_VOLATILE, KEY_ALL_ACCESS, NULL, &key, &disposition))
    {
      // just ignore any registry errors...we probably just don't have enough
      // permissions with the current user
      return;
    }

    // ignore failures
    RegSetValueExA(key, TEXT("MRUCodecName"), 0, REG_SZ, 
        (PBYTE)codecName.c_str(), codecName.size()+1);

    RegCloseKey(key);
  }
  
  static std::string getDefaultCodecName() {
    HKEY key;
    DWORD disposition;

    if (ERROR_SUCCESS != RegCreateKeyEx(HKEY_CURRENT_USER, 
      TEXT("Software\\dalleyg\\videoIO"), 0, NULL, 
      REG_OPTION_NON_VOLATILE, KEY_ALL_ACCESS, NULL, &key, &disposition))
    {
      // Registry access problem: just pick a codec
      return randSelCodec();
    }

    string name;
    if (disposition == REG_CREATED_NEW_KEY) {
      name = randSelCodec();
    } else {
      DWORD type;
      vector<char> data(1024);
      DWORD size = (DWORD)data.size() - 1;
      data[size] = '\0'; // make sure the string is null-terminated
      if (ERROR_SUCCESS != RegQueryValueExA(key, TEXT("DefaultCodecName"), 
        NULL, &type, (LPBYTE)&data[0], &size))
      {
        if (ERROR_SUCCESS != RegQueryValueExA(key, TEXT("MRUCodecName"), 
          NULL, &type, (LPBYTE)&data[0], &size))
        {
          // Error reading the key: just pick a codec
          name = randSelCodec();
        } else {
          name.assign(&data[0]);
        }
      } else if (type != REG_SZ) {
        // Unexpected data type for the key
        name = randSelCodec();
      } else {
        name.assign(&data[0]);
      }
    }

    // ignore failures
    RegSetValueExA(key, TEXT("MRUCodecName"), 0, REG_SZ, 
        (PBYTE)name.c_str(), name.size()+1);

    RegCloseKey(key);

    return name;
  }

  ///////////////////////////////////////////////////////////////////////////////
  ///////////////////////////////////////////////////////////////////////////////
  ///////////////////////////////////////////////////////////////////////////////

  // See DirectShowOVideo::DirectShowOVideo for a class overview.
  class CBlockingPin : public CSourceStream
  {
  public:
    CBlockingPin(HRESULT *phr, CSource *pFilter);
    ~CBlockingPin();

  public:
    // Methods called from DirectShow
    HRESULT Stop();

    // Override the version that offers exactly one media type
    HRESULT GetMediaType(CMediaType *pMediaType);
    HRESULT DecideBufferSize(IMemAllocator *pAlloc, ALLOCATOR_PROPERTIES *pRequest);
    HRESULT FillBuffer(IMediaSample *pSample);

    // Quality control: this implementation prevents dropped frames
    STDMETHODIMP Notify(IBaseFilter *pSelf, Quality q) {
      return E_FAIL;
    }

  public:
    // Usable from the client thread
    void writeNextFrame(uint8 const *matFrame);
    
    void setSize(int width, int height);
    void setFramesPerSecond(uint32 num, uint32 denom);

    int    getWidth()           const { return width;  }
    int    getHeight()          const { return height; }
    double getFramesPerSecond() const { return (double)fpsNum / fpsDenom; }

    size_t getCurrentFrameNumber() const { return m_iFrameNumber; }

    void unblock();

  private:
    int          width, height;
    uint32       fpsNum, fpsDenom;
    size_t       m_iFrameNumber; // frame # for the *next* frame to be written
    uint8 const *currMatFrame;

    CEvent startFillEvent, fillDoneEvent;
    bool quickExit;
  };

  ///////////////////////////////////////////////////////////////////////////////

  CBlockingPin::CBlockingPin(HRESULT *phr, CSource *pFilter)
    : CSourceStream(NAME("Blocking Frame Source"), phr, pFilter, L"Out"),
    width(-1), height(-1),
    fpsNum(DEFAULT_FPS_NUM), fpsDenom(DEFAULT_FPS_DENOM),
    m_iFrameNumber(0), 
    currMatFrame(NULL), quickExit(false)
  {
    VrFatalCheck(startFillEvent.ResetEvent());
    VrFatalCheck(fillDoneEvent.ResetEvent());
  }

  CBlockingPin::~CBlockingPin() {
    unblock();
  }

  void CBlockingPin::unblock() {
    quickExit = true;
    startFillEvent.SetEvent();
  }

  HRESULT CBlockingPin::Stop() {
    //unblock();
    return CSourceStream::Stop();
  }

  // GetMediaType: This method tells the downstream pin what types we support.
  HRESULT CBlockingPin::GetMediaType(CMediaType *pMediaType) {
    CAutoLock cAutoLock(m_pFilter->pStateLock());
    CheckPointer(pMediaType, E_POINTER);

    // Allocate enough room for the VIDEOINFOHEADER and the color tables
    VIDEOINFOHEADER *pvi = (VIDEOINFOHEADER*)pMediaType->AllocFormatBuffer(
      SIZE_PREHEADER + sizeof(BITMAPINFOHEADER));
    if (pvi == 0) return(E_OUTOFMEMORY);

    ZeroMemory(pvi, pMediaType->cbFormat);   
    pvi->AvgTimePerFrame = (REFERENCE_TIME)(
      UNITS * (double)fpsDenom / fpsNum);

    pvi->bmiHeader.biSize        = sizeof(BITMAPINFOHEADER);
    pvi->bmiHeader.biWidth       = width;
    pvi->bmiHeader.biHeight      = height; // positive = bottom-up
    pvi->bmiHeader.biPlanes      = 1;
    pvi->bmiHeader.biBitCount    = 24;
    pvi->bmiHeader.biCompression = BI_RGB; // Really BGR
    int const stride = ((width*3 + 3)/4)*4; 
    pvi->bmiHeader.biSizeImage   = stride * height; 

    // Clear source and target rectangles
    SetRectEmpty(&(pvi->rcSource)); // we want the whole image area rendered
    SetRectEmpty(&(pvi->rcTarget)); // no particular destination rectangle

    pMediaType->SetType(&MEDIATYPE_Video);
    pMediaType->SetFormatType(&FORMAT_VideoInfo);
    pMediaType->SetTemporalCompression(FALSE);

    // Work out the GUID for the subtype from the header info.
    const GUID SubTypeGUID = GetBitmapSubtype(&pvi->bmiHeader);
    pMediaType->SetSubtype(&SubTypeGUID);
    pMediaType->SetSampleSize(pvi->bmiHeader.biSizeImage);

    return S_OK;
  }

  HRESULT CBlockingPin::DecideBufferSize(IMemAllocator *pAlloc, 
    ALLOCATOR_PROPERTIES *pRequest)
  {
    CAutoLock cAutoLock(m_pFilter->pStateLock());

    CheckPointer(pAlloc, E_POINTER);
    CheckPointer(pRequest, E_POINTER);

    VIDEOINFOHEADER *pvi = (VIDEOINFOHEADER*)m_mt.Format();

    // Ensure a minimum number of buffers
    if (pRequest->cBuffers == 0) pRequest->cBuffers = 2;
    pRequest->cbBuffer = pvi->bmiHeader.biSizeImage;

    ALLOCATOR_PROPERTIES Actual;
    HRESULT hr = pAlloc->SetProperties(pRequest, &Actual);
    if (FAILED(hr)) return hr;

    // Is this allocator unsuitable?
    if (Actual.cbBuffer < pRequest->cbBuffer) return E_FAIL;

    return S_OK;
  }

  // FillBuffer is called once for every sample in the stream.
  HRESULT CBlockingPin::FillBuffer(IMediaSample *pSample) {
    CheckPointer(pSample, E_POINTER);

    // Block until writeNextFrame signals us to proceed (handling quickExit
    // as well).
    if (quickExit) {
      fillDoneEvent.SetEvent();
      return E_FAIL;  
    }
    ::WaitForSingleObject(startFillEvent.m_hObject, INFINITE);
    if (quickExit) {
      fillDoneEvent.SetEvent();
      return E_FAIL;  
    }
    if (!startFillEvent.ResetEvent()) {
      fillDoneEvent.SetEvent();
      return E_FAIL;
    }

    // Access the sample's data buffer
    BYTE *pData;
    pSample->GetPointer(&pData);
    long const cbData = pSample->GetSize();

    // Check that we're still using video
    ASSERT(m_mt.formattype == FORMAT_VideoInfo);

    VIDEOINFOHEADER *pVih = (VIDEOINFOHEADER*)m_mt.pbFormat;
    if ((size_t)cbData < (size_t)pVih->bmiHeader.biSizeImage) {
      fillDoneEvent.SetEvent();
      return E_FAIL;
    }

    uint8 const *matFrame = currMatFrame;
    if (matFrame == NULL) {
      fillDoneEvent.SetEvent();
      return E_POINTER;
    }

    // tranfer data while converting from Matlab to Microsoft image layout
    int const stride = ((width*3 + 3)/4)*4;
    matlab2bgr(pData, matFrame, stride, width, height, 3);

    // Set the timestamps that will govern playback frame rate.
    REFERENCE_TIME rtStart = (REFERENCE_TIME)(
      UNITS * (double)fpsDenom / fpsNum * m_iFrameNumber);
    REFERENCE_TIME rtStop = (REFERENCE_TIME)(
      UNITS * (double)fpsDenom / fpsNum * (m_iFrameNumber + 1));

    pSample->SetTime(&rtStart, &rtStop);
    m_iFrameNumber++;

    // Set TRUE on every sample for uncompressed frames
    pSample->SetSyncPoint(TRUE);

    if (!fillDoneEvent.SetEvent()) {
      return E_FAIL;
    }

    return S_OK;
  }

  void CBlockingPin::writeNextFrame(uint8 const *matFrame) {
    VrRecoverableCheck(width > 0 && height > 0);
    VrRecoverableCheck(fpsNum > 0 && fpsDenom > 0);

    // Record data for the directshow thread
    currMatFrame = matFrame;

    // Transfer execution to the directshow thread
    quickExit = false;
    VrFatalCheck(fillDoneEvent.ResetEvent());
    // TODO: allow the timeout to be user-settable.  If we do this, hitting a 
    // timeout would still be fatal because we don't know what the DirectShow
    // thread is doing.  
    DWORD res = ::SignalObjectAndWait(
      startFillEvent.m_hObject, fillDoneEvent.m_hObject, INFINITE, FALSE);

    // Make sure the wait call worked.
    switch (res) 
    {
    case WAIT_OBJECT_0:
      // Expected result: wait succeeded
      // Note: fillDoneEvent is still signalled: that's okay
      break;
    case WAIT_ABANDONED:
      VrFatalThrow("BUG: DirectShow thread improperly terminated");
    case WAIT_IO_COMPLETION:
      VrFatalThrow("BUG: SignalObjectAndWait returned due to an APC event even "
        "though we told it not to.");
    case WAIT_TIMEOUT:
      VrFatalThrow("Timeout expired, but FillBuffer may still be running, so "
        "this is treated as a fatal condition.");
    }
  }

  void CBlockingPin::setSize(int width, int height) {
    VrRecoverableCheckMsg(m_iFrameNumber == 0,
      "The frame size cannot be modified after the first frame has been "
      "written.");
    VrRecoverableCheck(width  > 0);
    VrRecoverableCheck(height > 0);
    this->width  = width;
    this->height = height;
  }

  void CBlockingPin::setFramesPerSecond(uint32 num, uint32 denom) {
    VrRecoverableCheckMsg(m_iFrameNumber == 0,
      "The frame rate cannot be modified after the first frame has been "
      "written.");
    VrRecoverableCheck(num  > 0);
    VrRecoverableCheck(denom > 0);
    this->fpsNum   = num;
    this->fpsDenom = denom;
  }

  ///////////////////////////////////////////////////////////////////////////////
  ///////////////////////////////////////////////////////////////////////////////
  ///////////////////////////////////////////////////////////////////////////////

  // See DirectShowOVideo::DirectShowOVideo for a class overview.
  class CBlockingSource : public CSource
  {
  public:
    CBlockingSource(IUnknown *pUnk, HRESULT *phr);
    CBlockingPin *getPin() { return m_pPin.get(); }

  private:
    auto_ptr<CBlockingPin> m_pPin;
  };

  CBlockingSource::CBlockingSource(IUnknown *pUnk, HRESULT *phr)
    : CSource(NAME("BlockingFrameSource"), pUnk, CLSID_BlockingFrameSource),
      // The pin magically adds itself to our pin array.
      m_pPin(new CBlockingPin(phr, this))
  {
    if (phr) {
      *phr = (m_pPin.get() == NULL) ? E_OUTOFMEMORY : S_OK;
    }
  }

  ///////////////////////////////////////////////////////////////////////////////
  ///////////////////////////////////////////////////////////////////////////////
  ///////////////////////////////////////////////////////////////////////////////

  /**
   * CBlockingPin is our workhorse: it takes Matlab-formatted frames and 
   * puts them into the DirectShow filtergraph.  It blocks the DirectShow 
   * filtergraph while waiting for new frames.  
   *
   * CBlockingSource is a simple DirectShow source filter whose only purpose
   * is to manage a CBlockingPin.
   *
   * DirectShowOVideo is in charge of construction and high-level management of
   * the filtergraph.  It also provides the public interface to the 
   * functionality provided here.
   */
  DirectShowOVideo::DirectShowOVideo() 
    : filtergraphIsConnected(false), source(NULL)
  { 
    TRACE;

    try {
      coInitIfNeeded();

      RecoverableHresultCheck(CoCreateInstance(
        (REFCLSID)CLSID_CaptureGraphBuilder2, NULL, CLSCTX_INPROC_SERVER, 
        (REFIID)IID_ICaptureGraphBuilder2, (void **)&builder));

      RecoverableHresultCheck(CoCreateInstance(
        (REFCLSID)CLSID_FilterGraph, NULL, CLSCTX_INPROC_SERVER, 
        (REFIID)IID_IGraphBuilder, (void **)&graph));
      RecoverableHresultCheck(builder->SetFiltergraph(graph));

      RecoverableHresultCheck(
        graph->QueryInterface(IID_IMediaControl, (void **)&mediaCtrl));

    } catch(...) {
      nothrowClose();
      throw;
    }
  }

  DirectShowOVideo::~DirectShowOVideo() { 
    TRACE;
    nothrowClose(); 
  }

  void DirectShowOVideo::setup(KeyValueMap &kvm) {
    TRACE;
    
    int fpsNum, fpsDenom;
    if (kvm.fpsParse(fpsNum, fpsDenom)) {
      setFramesPerSecond(fpsNum, fpsDenom);
    }

    if (kvm.hasKey("width") && kvm.hasKey("height")) {
      setSize(kvm.parseInt<int>("width"), kvm.parseInt<int>("height"));
    } else if (kvm.hasKey("width")) {
      setWidth(kvm.parseInt<int>("width"));
    } else if (kvm.hasKey("height")) {
      setHeight(kvm.parseInt<int>("height"));
    }

    if (kvm.hasKey("filename")) open(kvm.find("filename")->second);

    // Codec specified by FourCC code
    if (kvm.hasKey("fourcc")) {
      string const &codec = kvm.find("fourcc")->second;
      setCodec(codec);
    }
    if (kvm.hasKey("codec")) {
      string const &codec = kvm.find("codec")->second;
      setCodec(codec);
    }

    if (kvm.hasKey("codecParams")) {
      string const &params = kvm.find("codecParams")->second;
      setCodecParams(params);
    }

    if (kvm.hasKey("showCompressionDialog")) {
      if (kvm.parseInt<int>("showCompressionDialog")) {
        showCompressionDialog();
      }
    }
    
    // TODO:
    //  In the future, we may add support for preallocating an unfragmented 
    //  output file using ICaptureGraphBuilder2::AllocCapFile.  If we do this,
    //  we'll want to also automatically make a call to 
    //  ICaptureGraphBuilder2::CopyCaptureFile when we close the file to 
    //  reclaim unused space.  We will have to decide what name to use for
    //  the temporary capture file (e.g. use tempnam vs. use the final filename,
    //  copy to a tempfile, then rename the tempfile).

    kvm.alertUncheckedKeys("Unrecognized arguments: ");
  }


  /** Opens up a new AVI file (implicitly scheduling the erasure of any 
  *  previous file with the same name).  Fails if isOpen(). */
  void DirectShowOVideo::open(std::string const &filename) {
    TRACE;
    VrRecoverableCheckMsg(!isOpen(),  
                          "This video object is already open.  Close it "
                          "before trying to open a new file.");

    try {
      // TODO: look at the AMCap sample to see ways of creating other container
      // types like quicktime or mpeg files.
      USES_CONVERSION;
      WCHAR *filenameW = A2W(filename.c_str()); // allocated on the stack
      RecoverableHresultCheck(builder->SetOutputFileName(
        &MEDIASUBTYPE_Avi, filenameW, &renderer, &sink));
    } catch(...) {
      nothrowClose(); 
      throw;
    }
  }

  void DirectShowOVideo::close() {
    // Something really wrong happened if anything in close failed!
    VrFatalCheck(nothrowClose());
  }

#define FancyAssertEq(N,V,EXP) \
  VrRecoverableCheckMsg(V == EXP, \
  "Expected the " << N << " to be " << (EXP) << ", but it is " << (V) << ".");

  void DirectShowOVideo::addframe(int w, int h, int d, IVideo::Frame const &f) {
    TRACE;

    if ((getWidth() < 0) || (getHeight() < 0)) setSize(w, h);

    connectFiltergraphIfNeeded();

    FancyAssertEq("width",  w, getWidth());
    FancyAssertEq("height", h, getHeight());
    FancyAssertEq("depth",  d, getDepth());
    FancyAssertEq("number of elements in the frame", f.size(), w*h*d);
    
    RecoverableHresultCheck(mediaCtrl->Run());

    try {
      source->getPin()->writeNextFrame(&f[0]);
    } catch(VrFatalError) {
      nothrowClose();
      throw;
    }
    // recoverable exceptions don't force a close.
  }

  void DirectShowOVideo::setCodec(std::string const &name) {
    TRACE;
    VrRecoverableCheck(canSetCodec());

    string tmpCodecName = name;

    if (tmpCodecName.size() == 0) {
      tmpCodecName = "";
    } else if (strcasecmp(tmpCodecName.c_str(), NO_CODEC_TOKEN) == 0) {
      tmpCodecName = "";
    } else if (strcasecmp(tmpCodecName.c_str(), DEFAULT_CODEC_TOKEN) == 0) {
      tmpCodecName = getDefaultCodecName();
    }

    CComPtr<IMoniker> pComprMoniker;
    if (tmpCodecName.size()) {
      CodecEnumerator e(CLSID_VideoCompressorCategory, false);
      while (e.next()) {
        if (((strcasecmp(tmpCodecName.c_str(), e.friendlyName().c_str()) == 0) ||
             (strcasecmp(tmpCodecName.c_str(), e.fccHandler().c_str()) == 0)) &&
            (e.moniker() != NULL)) 
        {
          pComprMoniker = e.moniker();
          break;
        }
      }

      VrRecoverableCheckMsg(pComprMoniker != NULL,
        "Could not find requested encoder");  
    }

    if (compressor != NULL) {
      breakApartFiltergraph();
      RecoverableHresultCheck(graph->RemoveFilter(compressor));
      compressor = NULL;
    }

    if (tmpCodecName.size()) {
      RecoverableHresultCheck(pComprMoniker->BindToObject(
        NULL, NULL, IID_IBaseFilter, (void**)&compressor));
      RecoverableHresultCheck(graph->AddFilter(compressor, L"Encoder"));
    }

    codecName = tmpCodecName;

    if (tmpCodecName.size()) setMostRecentCodecName(codecName);
  }

  void DirectShowOVideo::setCodecParams(std::string const &params64) {
    TRACE;
    std::vector<uint8> v(params64.size());
    int outSize = (int)v.size();
    VrRecoverableCheckMsg(Base64Decode(params64.c_str(), (int)params64.size(),
                                       (BYTE*)&v[0], &outSize),
                          "MIME Base64 decoding of parameter string failed.");
    v.resize(outSize);
    return setCodecParams(v);
  }

  void DirectShowOVideo::setCodecParams(const std::vector<uint8> &params) {
    TRACE;
    // Make sure we haven't started compress yet (you can't change
    // codecs mid-stream).
    checkCanSetCompressionOptions();

    VrRecoverableCheckMsg(compressor != NULL,
      "No codec has been selected, so its parameters cannot be set.");
  
    if (!setVfwCompressionState(compressor, params)) {
      VrRecoverableThrow(
        "Only Video for Windows (VfW) codecs support programmatic "
        "configuration.");
    }
  }

  void DirectShowOVideo::showCompressionDialog() {
    TRACE;
    if (compressor == NULL) setCodec(DEFAULT_CODEC_TOKEN); 

    int    const oldWidth  = getWidth();
    int    const oldHeight = getHeight();
    bool   const unsized   = ((oldWidth < 0) || (oldHeight < 0));

    if (unsized) setSize(640,480); // temporarily use a safe & very common frame size
    checkCanSetCompressionOptions();

    connectFiltergraphIfNeeded(); // if unsized, it will connect

    vector<uint8> state;
    VrRecoverableCheckMsg(
      showDShowCompressionDialog(compressor) ||
      showVfwCompressionDialog(compressor, state),
      "Neither a DirectShow nor a Video for Windows (VfW) configuration dialog "
      "could be displayed.  The codec is probably either a VCM or DMO-based "
      "object, and this class does not currently prodce configuration GUIs for "
      "those types of objects.  Try choosing a different codec if the default "
      "configuration for this one is not what you want.");
    // TODO: IPropertyBag can be used to configure DMOs
    // TODO: When using VfW, it's easy to pop up the VCM dialog using 
    //   AVISaveOptions.  We could see if there's a similar existing function
    //   for managing a VCM dialog under DirectShow.  If not, we'll have to use
    //   IAMVideoCompression to access the data and create our own dialog 
    //   classes.  Monogram's GraphStudio is a good place to look for an 
    //   existing implementation.    

    // If the user hasn't given a frame size yet, we now rip apart the 
    // filtergraph.  Most compressors impose restrictions on frame sizes, 
    // and this way we can get the frame size checked lazily upon an
    // explicit call to setSize or addframe.  
    if (unsized) {
      string const filename = getFilename();

      breakApartFiltergraph();

      setSize(oldWidth, oldHeight);

      // Unfortunately, just connecting the filtergraph causes file headers
      // to be written (at least for .avi files).  Solution: re-create the 
      // renderer and/or sink.
      bool worked = true;
      if (renderer != NULL) {
        if (!SUCCEEDED(graph->RemoveFilter(renderer.p))) worked = false;
      }
      sink = NULL;
      open(filename);

      VrRecoverableCheckMsg(worked, 
        "Could not clean up temporary output objects.");
    }
  }

  void DirectShowOVideo::setSize(int w, int h) {
    TRACE;
    VrRecoverableCheck(canSetFrameSpecs());
    // Note: we allow negative w & h values as an undocumented hack to 
    // make showCompressionDialog easier.
    VrRecoverableCheckMsg(w != 0, 
      "The video width must be positive: " << w << " was supplied.");
    VrRecoverableCheckMsg(h != 0, 
      "The video height must be positive: " << h << " was supplied.");
    addSourceIfNeeded();
    if (w > 0 && h > 0) {
      // Some codecs only work for certain frame sizes.  For example, some 
      // mpeg encoders only take certain specific frame sizes.  Others like 
      // some H.264 encoders require that the width and height be a multiple 
      // of 16.  To make sure everything works out, we must disconnect the 
      // filtergraph, update the frame size, then see if the downstream 
      // filters are okay with the new frame size.
      bool const wasConnected = filtergraphIsConnected;
      if (wasConnected) breakApartFiltergraph();
      source->getPin()->setSize(w, h);
      if (wasConnected) connectFiltergraphIfNeeded();
    }
  }

  void DirectShowOVideo::setFramesPerSecond(double fps) {
    VrRecoverableCheck(fps > 0);
    if ((uint32)fps == fps) {
      setFramesPerSecond((uint32)fps, 1);
    } else if ((uint32)(fps*1001) == fps*1001) {
      setFramesPerSecond((uint32)(fps*1001), 1001);
    } else {
      setFramesPerSecond((uint32)(fps*1000), 1000);
    }
  }

  void DirectShowOVideo::setFramesPerSecond(uint32 num, uint32 denom) {
    TRACE;
    VrRecoverableCheck(canSetFrameSpecs());
    VrRecoverableCheck(num > 0);
    VrRecoverableCheck(denom > 0);
    addSourceIfNeeded();
    bool const wasConnected = filtergraphIsConnected;
    if (wasConnected) breakApartFiltergraph();
    source->getPin()->setFramesPerSecond(num, denom);
    if (wasConnected) connectFiltergraphIfNeeded();
  }

  bool DirectShowOVideo::isOpen() const {
    return (sink != NULL);
  }

  bool DirectShowOVideo::canSetCodec() const {
    return ((source == NULL) || 
       (source->getPin()->getCurrentFrameNumber() == 0));
  }

  bool DirectShowOVideo::canSetCompressionOptions() {
    try {
      checkCanSetCompressionOptions();
    } catch(VrRecoverableException const &) {
      return false;
    }
    return true;
  }

  void DirectShowOVideo::checkCanSetCompressionOptions() {
    addSourceIfNeeded();
    VrRecoverableCheckMsg(compressor != NULL,
      "No compressor has been instantiated, so it cannot be configured.");
    VrRecoverableCheckMsg((source != NULL) && (source->getPin() != NULL),
      "No input pin has been created yet.");
    VrRecoverableCheckMsg((source->getPin()->getWidth() > 0) &&
      (source->getPin()->getHeight() > 0),
      "The frame size must be explicitly specified before configuring "
      "the compressor.");
    VrRecoverableCheckMsg(source->getPin()->getFramesPerSecond() > 0,
      "The frame rate must be explicitly specified before configuring "
      "the compressor.");
    // We currently use ICaptureGraphBuilder2 to connect the pins and it
    // requires a renderer (otherwise, it'll create a rendering window,
    // and we don't want that). ...
    VrRecoverableCheckMsg(isOpen(),
      "Due to some DirectShow ideosyncracies, an output file must be "
      "specified before compression options can be set.");
  }

  bool DirectShowOVideo::canSetFrameSpecs() const {
    return !filtergraphIsConnected && ((source == NULL) || 
      (source->getPin()->getCurrentFrameNumber() == 0));
  }

  int DirectShowOVideo::getWidth() const {
    return (source == NULL) ? -1 : source->getPin()->getWidth();
  }

  int DirectShowOVideo::getHeight() const {
    return (source == NULL) ? -1 : source->getPin()->getHeight();
  }

  // TODO: if old mpeg-style config is needed, look at the docs on 
  // IAMVideoCompression.

#define assnString(lval, x) \
  { stringstream ss; ss << x; lval = ss.str(); }

  std::string DirectShowOVideo::getFilename() const {
    if (sink != NULL) {
      LPOLESTR fname = NULL;
      RecoverableHresultCheck(sink->GetCurFile(&fname, NULL));
      if (fname != NULL) {
        USES_CONVERSION;
        char *fnameA = OLE2A(fname); // allocated on the stack
        string filename = fnameA;
        CoTaskMemFree(fname);
        return filename;
      }
    }
    return "";
  }

  KeyValueMap DirectShowOVideo::getSetupAndStats() const {
    TRACE;

    USES_CONVERSION;

    KeyValueMap kvm;
    // setup
    if (source != NULL && source->getPin() != NULL) {
      assnString(kvm["fps"], source->getPin()->getFramesPerSecond());
    }
    assnString(kvm["width"],  getWidth());
    assnString(kvm["height"], getHeight());
    kvm["codec"]       = getCodec();
    kvm["codecParams"] = getCodecParams();

    string fname = getFilename();
    if (fname.size()) kvm["filename"] = fname;

    // stats
    if (source != NULL && source->getPin() != NULL) {
      assnString(kvm["currFrameNumber"], 
                 source->getPin()->getCurrentFrameNumber() - 1);
    }

    return kvm;
  }

  string DirectShowOVideo::getCodecParams() const {
    TRACE;
    if (compressor == NULL) return "";

    vector<uint8> state;
    if (!getVfwCompressionState(compressor, state)) return "";

    string base64;
    base64.resize(state.size() * 2);
    int outLen = (int)base64.size();
    VrRecoverableCheckMsg(
      Base64Encode((BYTE const *)&state[0], state.size(),
                   &base64[0], &outLen,
                   ATL_BASE64_FLAG_NOPAD | ATL_BASE64_FLAG_NOCRLF),
      "MIME Base64 encoding of the codec parameter string failed.  This "
      "should never happen.");
    base64.resize(outLen);
    return base64;
  }

  bool DirectShowOVideo::nothrowClose() {
    TRACE;
    bool worked = true;

    if (source != NULL) {
      source->getPin()->unblock();
    }

    if (mediaCtrl != NULL) {
      if (!SUCCEEDED(mediaCtrl->Stop())) worked = false;
    }

    if (graph != NULL) {
      if (renderer != NULL) {
        if (!SUCCEEDED(graph->RemoveFilter(renderer.p))) worked = false;
      }
      if (compressor != NULL) {
        if (!SUCCEEDED(graph->RemoveFilter(compressor.p))) worked = false;
      }
      if (source != NULL) {
        if (!SUCCEEDED(graph->RemoveFilter(source))) worked = false;
      }
    }

    sink       = NULL;
    renderer   = NULL;
    compressor = NULL;
    codecName  = "";
    if (source != NULL) {
      delete source;
      source = NULL;
    }
    
    filtergraphIsConnected = false;

    return worked;
  }

  void DirectShowOVideo::breakApartFiltergraph() {
    TRACE;
    if (mediaCtrl != NULL) {
      RecoverableHresultCheck(mediaCtrl->Stop());
    }
    if (source != NULL) {
      RecoverableHresultCheck(graph->Disconnect(source->getPin()));
    }
    if (compressor != NULL) {
      CComPtr<IEnumPins> pins;
      RecoverableHresultCheck(compressor->EnumPins(&pins));
      CComPtr<IPin> pin;
      ULONG nFetched = 0;
      while (SUCCEEDED(pins->Next(1, &pin.p, &nFetched)) && nFetched) {
        RecoverableHresultCheck(graph->Disconnect(pin));
      }
    }
    filtergraphIsConnected = false;
  }

  void DirectShowOVideo::connectFiltergraphIfNeeded() {
    TRACE;
    VrRecoverableCheckMsg(isOpen(),
      "The final filtergraph cannot be connected because the output file is "
      "not open.");
    VrRecoverableCheck(getWidth() > 0 && getHeight());
    addSourceIfNeeded();
    if (compressor == NULL) setCodec(DEFAULT_CODEC_TOKEN);
    if (!filtergraphIsConnected) {
      VrRecoverableCheck(renderer != NULL);
      RecoverableHresultCheckMsg(builder->RenderStream(
        NULL, &MEDIATYPE_Video, (IPin*)source->getPin(), compressor, renderer),
        "Could not connect the source, compressor, and file writer objects.");

      filtergraphIsConnected = true;
    }
  }

  void DirectShowOVideo::addSourceIfNeeded() {
    VrRecoverableCheck(graph != NULL);
    if (source == NULL) {
      HRESULT hr = S_OK;
      source = new CBlockingSource(NULL, &hr);
      if (!SUCCEEDED(hr)) {
        source = NULL;
        RecoverableHresultCheck(hr);
      }
      source->AddRef();
      RecoverableHresultCheck(graph->AddFilter(source, L"Source Filter"));
    }
  }

};
