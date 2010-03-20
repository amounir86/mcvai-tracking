// $Date: 2008-09-12 11:12:24 -0400 (Fri, 12 Sep 2008) $
// $Revision: 659 $

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
#include <comutil.h>

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

#include "debug.h"
#include "parse.h"
#include "WinCommon.h"

using namespace std;

namespace VideoIO {

  void coInitIfNeeded() {
    static bool initialized = false; // NOT threadsafe
    if (!initialized) {
      CoInitialize(NULL);
      initialized = true;
    }
  }

  // Adapted From: http://www.codeproject.com/tips/formatmessage.asp
  string errorString(DWORD err)
  {
    string error;
    LPTSTR s;
    HANDLE hModule = GetModuleHandle("quartz.dll" /* main VFW DLL */); 
    if (::FormatMessage(FORMAT_MESSAGE_ALLOCATE_BUFFER|FORMAT_MESSAGE_FROM_SYSTEM|
      FORMAT_MESSAGE_FROM_HMODULE,
      hModule, err, 0, (LPTSTR)&s, 1024, NULL) == 0)
    { /* failed */
      // Unknown error code %08x (%d)
      error = "Unknown error code";
    } else { 
      /* success */
      LPTSTR p = _tcschr(s, _T('\r'));
      if(p != NULL)
      { /* lose CRLF */
        *p = _T('\0');
      } /* lose CRLF */
      error = s;
      ::LocalFree(s);
    } 
    return error;
  } 

  /** Converts Matlab's preferred byte layout for images to C-style RGB images.
  *  This code should be kept in sync with bgr2Matlab in FfmpegIVideo.cpp.
  */
  void matlab2bgr(uint8 *bgr, uint8 const *mat, 
    int stride, int w, int h, int d)
  {
    for (int c=d-1; c>=0; c--) { // counting down does a RGB -> BGR conversion
      for (int x=0; x<w; x++) {
        for (int y=h-1; y>=0; y--) { // top-down -> bottom-up conversion
          // We need to transpose from row-major to column-major
          bgr[y*stride + x*d + c] = *mat++;
        }
      }
    }
  }

  void topDownBgrToMatlab(unsigned char *out, 
    unsigned char const *bgrData, 
    size_t stride, int w, int h, int d)
  {
    for (int c=0; c<d; c++) {
      for (int x=0; x<w; x++) {
        for (int y=0; y<h; y++) {
          // We need to vertically flip, transpose from row-major to 
          // column-major, and do BGR->RGB conversion.
          *out++ = bgrData[x*d+(h-y-1)*stride + (d-1-c)];
        }
      }
    }
  }

  HRESULT addToRot(IUnknown *pUnkGraph, DWORD *pdwRegister)
  {
    IMoniker            *pMoniker = NULL;
    IRunningObjectTable *pROT     = NULL;
    if (FAILED(GetRunningObjectTable(0, &pROT))) {
      return E_FAIL;
    }
    char eightBitName[256];
    wsprintf(eightBitName, 
      "FilterGraph %08x pid %08x", 
      (DWORD_PTR)pUnkGraph, GetCurrentProcessId());
    WCHAR wsz[256];
    USES_CONVERSION;
    memcpy(wsz, A2OLE(eightBitName), sizeof(WCHAR)*256);
    HRESULT hr = CreateItemMoniker(L"!", wsz, &pMoniker);
    if (SUCCEEDED(hr)) {
      hr = pROT->Register(ROTFLAGS_REGISTRATIONKEEPSALIVE, pUnkGraph, pMoniker, pdwRegister);
      pMoniker->Release();
    }
    pROT->Release();
    return hr;
  }

  void removeFromRot(DWORD pdwRegister)
  {
    IRunningObjectTable *pROT;
    if (SUCCEEDED(GetRunningObjectTable(0, &pROT))) {
      pROT->Revoke(pdwRegister);
      pROT->Release();
    }
  }



  CodecEnumerator::CodecEnumerator(REFCLSID filterCategory, bool enumVfw) : 
    i(ENUMERATING_DSHOW), enumVfw(enumVfw) 
  {
    coInitIfNeeded();

    CComPtr<ICreateDevEnum> pSysDevEnum(NULL);

    HRESULT hr = CoCreateInstance(CLSID_SystemDeviceEnum, NULL, 
      CLSCTX_INPROC_SERVER, IID_ICreateDevEnum, (void**)&pSysDevEnum);
    if (SUCCEEDED(hr)) {
      if (FAILED(pSysDevEnum->CreateClassEnumerator(
        filterCategory, &e, 0)))
      {
        e = NULL;
      }
    } 
  }

  bool CodecEnumerator::next() {
    if (i == ENUMERATING_DSHOW) {
      return nextDShow();
    } else {
      return nextVfw();
    }
  }

  bool CodecEnumerator::nextDShow() {
    while (true) {
      fname = "";
      fcc   = "";
      ULONG numRetrieved = 0;

      if ((e == NULL) || (S_OK != e->Next(1, &m, &numRetrieved))) {
        m = NULL;
        e = NULL;
        return nextVfw();
      }
      CComPtr<IPropertyBag> pPropBag(NULL);
      HRESULT hr = m->BindToStorage(NULL, NULL, IID_IPropertyBag, 
        (void **)&pPropBag);
      if (!SUCCEEDED(hr)) continue;

      // Depending on the OS (XP vs. Vista) and the compressor type 
      // (DirectShow vs. VfW), either the FriendlyName and/or the 
      // FccHandler are available.  Allow either to be used.

      VARIANT friendlyName = {0};
      friendlyName.vt = VT_BSTR;
      hr = pPropBag->Read(L"FriendlyName", &friendlyName, 0);
      if (SUCCEEDED(hr)) {
        fname = (char*)_bstr_t(friendlyName.bstrVal, false);
        VariantClear(&friendlyName);
      }

      VARIANT fourccVar = {0};
      fourccVar.vt = VT_BSTR;
      hr = pPropBag->Read(L"FccHandler", &fourccVar, 0);
      if (SUCCEEDED(hr)) {
        fcc = (char*)_bstr_t(fourccVar.bstrVal, false);
        VariantClear(&fourccVar);
      }

      return true;
    }
  }

  bool CodecEnumerator::nextVfw() {
    fname = "";
    fcc   = "";

    if (i == DONE_ENUMERATING) return false;
    if (!enumVfw) {
      i = DONE_ENUMERATING;
      return false;
    }

    i++;
    DWORD fccType = 0; // match all
    for (; ICInfo(fccType, (DWORD)i, &icinfo); ++i) { 
      if (icinfo.fccType != ICTYPE_VIDEO) continue;
      HIC hic = ICOpen(icinfo.fccType, icinfo.fccHandler, ICMODE_QUERY); 
      if (hic) {
        // Find out the compressor name. 
        ICGetInfo(hic, &icinfo, sizeof(icinfo)); 
        fcc = fourCCToString(icinfo.fccHandler);
        ICClose(hic); 
        return true;
      } 
    } 
    i = DONE_ENUMERATING;
    return false;
  }

};
