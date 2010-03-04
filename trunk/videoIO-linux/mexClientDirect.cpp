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
#include <mex.h>
#include <matrix.h>
#ifdef __linux__
#  include <sys/types.h>
#  include <sys/wait.h>
#else
typedef void (*sighandler_t)(int sig);
#endif
#include <signal.h>
#include "debug.h"
#include "matarray.h"
#include "MatlabHelpers.h"
#include "handleMexRequest.h"
#include "registry.h"

using namespace std;
using namespace VideoIO;
  
/** 
 * This is a little helper class for trapping the Ctrl-C signal.
 * We've wrapped it up in a class so that we can be sure that 
 * the destructor is called if an exception is thrown.
 */
class CtrlCTrap 
{
public: 
  CtrlCTrap()  { 
    VrRecoverableCheckMsg(oldHandler == NULL,
      "CtrlCTrap is not designed for nested traps.");
    ctrlHasBeenTrapped = false; 
    oldHandler = signal(SIGINT, &signalHandler); 
  }

  ~CtrlCTrap() { release(); }

  void release() { 
    if (oldHandler) { signal(SIGINT, oldHandler); oldHandler = NULL; } 
  }

  bool trapped() { return ctrlHasBeenTrapped; }

private:
  static void signalHandler(int signum) { ctrlHasBeenTrapped = true; }
  static bool ctrlHasBeenTrapped;
  static sighandler_t oldHandler;
};
bool CtrlCTrap::ctrlHasBeenTrapped = false;
sighandler_t CtrlCTrap::oldHandler = NULL;

inline void initializeIfNeeded() {
  static bool initialized = false;
  if (!initialized) {
    mexAtExit(cleanup);
    initialized = true;
  }
}

void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])
{
  TRACE;

  try {
    initializeIfNeeded();

    // Transfer input data to MatArrays
    MatArrayVector rhs;
    for (int i=0; i<nrhs; i++) {
      rhs.push_back(new MatArray(prhs[i]));
    }

    // Call linked pseudo-mexFunction
    MatArrayVector lhs;
    {
      CtrlCTrap trap;
      handleMexRequest(lhs, nlhs, rhs);
      if (trap.trapped()) {
        trap.release(); // makes R13sp1 work (it skips destructors)
        mexErrMsgTxt("User break");
      }
    }

    // Check # of return args
    if (lhs.size() > (size_t)nlhs) {
      if (!((lhs.size() == 1) && (nlhs == 0))) {
        VrRecoverableThrow("Expected " << nlhs << " left hand arguments from "
                           "the server, but " << lhs.size() << " were " 
                           "returned instead.");
      }
    }

    // Transfer output data
    for (size_t i=0; i<lhs.size(); i++) {
      lhs[i]->transferToMat(plhs[i]);
    }

  } catch (VrRecoverableException const &e) {
    mexErrMsgTxt(e.message.c_str());
  } catch (VrFatalError const &e) {
    v_mat_s("clear", getMexName().c_str());
    mexErrMsgTxt(e.message.c_str());
  }
}
