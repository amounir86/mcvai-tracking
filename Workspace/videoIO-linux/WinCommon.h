#ifndef WINCOMMON_H
#define WINCOMMON_H

// $Date: 2008-09-12 11:12:24 -0400 (Fri, 12 Sep 2008) $
// $Revision: 659 $

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
#include "matarray.h"
#include "IVideo.h"

#include <Vfw.h>
#include <unknwn.h>
#include <objidl.h>

namespace VideoIO {

  void coInitIfNeeded();

  ///////////////////////////////////////////////////////////////////////////////
  // Error handling and reporting utilities

  std::string errorString(DWORD err);

  /** Use this for calling HRESULT functions where you want to throw an exception
  *  on failure and embed the HRESULT value in the message. */
#define            HresultCheckMsg(testCond, ThrowType, msg)  { HRESULT retHresultAssert = S_OK; VrGenericCheckMsg(SUCCEEDED(retHresultAssert = testCond), ThrowType,              msg << "\n", "Failed test: " #testCond "\nHRESULT = 0x" << (void*)retHresultAssert << ".  " << errorString(retHresultAssert)); }
#define               HresultCheck(testCond, ThrowType)       { HRESULT retHresultAssert = S_OK; VrGenericCheckMsg(SUCCEEDED(retHresultAssert = testCond), ThrowType,              "",          "Failed test: " #testCond "\nHRESULT = 0x" << (void*)retHresultAssert << ".  " << errorString(retHresultAssert)); }
#define RecoverableHresultCheckMsg(testCond, msg)             { HRESULT retHresultAssert = S_OK; VrGenericCheckMsg(SUCCEEDED(retHresultAssert = testCond), VrRecoverableException, msg << "\n", "Failed test: " #testCond "\nHRESULT = 0x" << (void*)retHresultAssert << ".  " << errorString(retHresultAssert)); }
#define    RecoverableHresultCheck(testCond)                  { HRESULT retHresultAssert = S_OK; VrGenericCheckMsg(SUCCEEDED(retHresultAssert = testCond), VrRecoverableException, "",          "Failed test: " #testCond "\nHRESULT = 0x" << (void*)retHresultAssert << ".  " << errorString(retHresultAssert)); }
#define       FatalHresultCheckMsg(testCond, msg)             { HRESULT retHresultAssert = S_OK; VrGenericCheckMsg(SUCCEEDED(retHresultAssert = testCond), VrFatalError,           msg << "\n", "Failed test: " #testCond "\nHRESULT = 0x" << (void*)retHresultAssert << ".  " << errorString(retHresultAssert)); }
#define          FatalHresultCheck(testCond)                  { HRESULT retHresultAssert = S_OK; VrGenericCheckMsg(SUCCEEDED(retHresultAssert = testCond), VrFatalError,           "",          "Failed test: " #testCond "\nHRESULT = 0x" << (void*)retHresultAssert << ".  " << errorString(retHresultAssert)); }

  /** Use this for calling HRESULT functions from functions/methods that return
  *  HRESULTs */
#define StdimplHresultCheck(testCond) \
  { HRESULT const resStdimplHresultAssert = testCond;  \
  if (!SUCCEEDED(resStdimplHresultAssert)) return resStdimplHresultAssert; }

  ///////////////////////////////////////////////////////////////////////////////
  // Data management utilities

  void matlab2bgr(uint8 *bgr, uint8 const *mat, 
    int stride, int w, int h, int d);

  void topDownBgrToMatlab(unsigned char *out, unsigned char const *bgrData, 
    size_t stride, int w, int h, int d);

  ///////////////////////////////////////////////////////////////////////////////
  // DirectShow filtergraph management

  HRESULT addToRot(IUnknown *pUnkGraph, DWORD *pdwRegister);
  void removeFromRot(DWORD pdwRegister);

  class CodecEnumerator 
  {
  public:
    CodecEnumerator(REFCLSID filterCategory, bool enumVfw);
  
    bool next();

    IMoniker    *moniker()      const { return m.p;   }
    std::string  friendlyName() const { return fname; }
    std::string  fccHandler()   const { return fcc;   }

  private:
    static int64 const ENUMERATING_DSHOW = -1;
    static int64 const DONE_ENUMERATING  = -2;

    bool nextDShow();
    bool nextVfw();

    bool                  enumVfw;
    CComPtr<IMoniker>     m;
    CComPtr<IEnumMoniker> e;
    BITMAPINFOHEADER      bih;
    int64                 i;
    ICINFO                icinfo;

    std::string fname, fcc;
  };

};

#endif
