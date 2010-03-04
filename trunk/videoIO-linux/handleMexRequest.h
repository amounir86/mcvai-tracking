#ifndef HANDLEMEXREQUEST_H
#define HANDLEMEXREQUEST_H

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

#include <string>
#include <vector>
#include "matarray.h"
#include "handle.h"
#include "debug.h"

namespace VideoIO {

  // Tell VS to not tell us that it ignores throw declarations.
  #pragma warning (disable: 4290)
  
  /** This is the declaration for a proxy function that works like a Matlab
   *  mexFunction(int,mxArray**,int,mxArray const **), but does not require
   *  linking to any Matlab libraries.  
   *
   *  The Matlab-like function parameters are given by rhs.  nlhs specifies
   *  the number of left hand side assignments that have been requested by
   *  Matlab.  If nlhs == 0, lhs may contain 0 or 1 elements upon return.
   *  Otherwise, lhs should typically have exactly nlhs elements upon 
   *  returning.  
   *
   *  If a VrRecoverableException is thrown, the handleMexRequest 
   *  implementation is declaring that a recoverable error has occurred and 
   *  all state encapsulated by the implementation is valid.  If any other 
   *  type of exception is thrown, the internal state of the implementation 
   *  is invalid and future calls may cause arbitrary program behavior.  It 
   *  is the caller's responsibility to unload the implementation.
   */
  extern void handleMexRequest(std::vector<MatArray*> &lhs, 
                               int nlhs, 
                               std::vector<MatArray*> const &rhs)
    throw(VrFatalError, VrRecoverableException);

  /** The user must also supply an implementation of cleanup() that
   *  releases all resources.
   */
  extern void cleanup();





  /** Helper function for mex request implementations that always expect
   *  an operation string and a numeric object handle for all function 
   *  calls.  
   *
   *  Checked Preconditions:
   *    1) myRhs.size() >= 2
   *    2) myRhs[0] contains a string
   *    3) myRhs[1] contains Handle
   *  If any preconditions are not met, a VrRecoverableException is thrown.
   *
   *  Otherwise, the first two elements of myRhs are removed and their
   *  values are placed in op and handle.  myRhs is modified!
   */
  inline void extractOpAndHandle(std::string &op, Handle &handle, 
                                 std::vector<MatArray*> &myRhs) {
    VrRecoverableCheckMsg(myRhs.size() >= 2, 
                          "An operation string and a handle are required.");
    
    op = mat2string(myRhs[0]); 
    myRhs.erase(myRhs.begin());
    
    handle = mat2scalar<Handle>(myRhs[0]); 
    myRhs.erase(myRhs.begin());
  }

  /** Helper function for checking the number of left hand side arguments
   *  to handleMexRequest.  
   */
  inline void nlhsCheck(int nlhs, int expectedNlhs) {
    TRACE;
    if (expectedNlhs == 1) {
      if (!(nlhs == 0 || nlhs == 1)) {
        VrRecoverableThrow("Expected 0 or 1 output args, but " << nlhs << 
                           " was/were found.");
      }
    } else {
      if (nlhs != expectedNlhs) {
        VrRecoverableThrow("Expected " << expectedNlhs << " output args, but "
                           << nlhs << " was/were found.");
      }
    }
  }
  
  /** Helper function for checking the number of right hand side arguments
   *  to handleMexRequest.  
   */
  inline void nrhsCheck(std::vector<MatArray*> const &rhs, 
                        size_t expectedNrhs) {
    TRACE;
    if (rhs.size() != expectedNrhs) {
      VrRecoverableThrow("Expected " << expectedNrhs << " input args, but " 
                         << rhs.size() << " were found.");
    }
  }


}; /* namespace VideoIO */

#endif
