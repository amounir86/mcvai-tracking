#ifndef MATLABHELPERS_H
#define MATLABHELPERS_H

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

#include <mex.h>
#include <matrix.h>
#include <string>
#include "debug.h"

namespace VideoIO 
{

  /** Matlab string to STL string */
  static inline std::string extractString(mxArray const *a)
  {
    TRACE;
    char buf[4096]; buf[sizeof(buf)-1] = '\0';
    if (mxGetString(a, buf, sizeof(buf)-1) != 0)
    {
      VrRecoverableThrow(
        "Could not parse matlab array argument as a string.");
    }
    return buf;
  }

  /** Call a matlab function that takes a string and returns a void */
  static inline void v_mat_s(const char *func, const char *arg)
  {
    mxArray *mxArgs[] = {mxCreateString(arg)};
    mxArray *mxRet[]  = { NULL };
    VrRecoverableCheck(mexCallMATLAB(0, mxRet, 1, mxArgs, func) == 0);
    if (mxRet[0] != NULL) mxDestroyArray(mxRet[0]);
  }

  /** Call a matlab function that takes a string and returns a string */
  static inline std::string s_mat_s(const char *func, const char *arg)
  {
    mxArray *mxArgs[] = {mxCreateString(arg)};
    mxArray *mxRet[]  = { NULL };
    VrRecoverableCheck(mexCallMATLAB(1, mxRet, 1, mxArgs, func) == 0);
    if (mxRet[0] == NULL) return "";
    std::string ret = extractString(mxRet[0]);
    mxDestroyArray(mxRet[0]);
    return ret;
  }

  /** Call a matlab function that takes no args and returns a string */
  static inline std::string s_mat_v(const char *func)
  {
    mxArray *mxArgs[] = { NULL /* VS won't allocate a 0-sized array, so we put in a dummy element here */};
    mxArray *mxRet[]  = { NULL };
    VrRecoverableCheck(mexCallMATLAB(1, mxRet, 0, mxArgs, func) == 0);
    if (mxRet[0] == NULL) return "";
    std::string ret = extractString(mxRet[0]);
    mxDestroyArray(mxRet[0]);
    return ret;
  }

  /** Get the name of the currently-executing mex function */
  static inline std::string getMexName() { 
    return s_mat_v("mfilename"); 
  }

  /** get the full pathname (minus extension) of the currently-executing
   *  mex function */
  static inline std::string getMexPathname() { 
    return s_mat_s("mfilename", "fullpath"); 
  }

}; /* namespace VideoIO */

#endif
