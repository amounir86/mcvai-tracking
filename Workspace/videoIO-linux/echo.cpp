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
#include "matarray.h"
#include "handleMexRequest.h"

namespace VideoIO {

  /**
   * This handleMexRequest simply takes the rhs args and transfers all the
   * data to the lhs args, "echoing" the data.  The purpose of this function
   * is to test the calling of handleMexRequest functions from a mexFunction
   * via the popen2 + pipecomm interprocess protocol and through direct 
   * in-process function calls.
   *
   * See tests/testEcho.m for usage examples.
   */
  void handleMexRequest(std::vector<MatArray*> &lhs, 
                        int nlhs, 
                        std::vector<MatArray*> const &rhs)
    throw(VrFatalError, VrRecoverableException)
  {
    TRACE;
    VERBOSE("incoming nlhs=" << nlhs << ", nrhs=" << rhs.size());
    if ((size_t)nlhs != rhs.size()) {
      if (!(nlhs == 0 && rhs.size() == 1)) {
        VrRecoverableThrow("This mex function requires that the number of "
                           "left hand arguments (" << nlhs << ") be the same "
                           "as the number of right hand arguments (" << 
                           rhs.size() << ").");
      }
    }

    lhs.resize(rhs.size());
    for (size_t i=0; i<rhs.size(); i++) {
      lhs[i] = new MatArray(rhs[i]);
    }
    VERBOSE("outgoing nlhs=" << lhs.size());
  }

  void cleanup() {
    TRACE;
    // nothing interesting to do
  }


}; /* namespace VideoIO */
