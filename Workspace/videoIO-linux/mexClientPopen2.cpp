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
#include <sys/types.h>
#include <sys/wait.h>
#include <signal.h>
#include <stdlib.h>
#include "debug.h"
#include "popen2.h"
#include "matarray.h"
#include "pipecomm.h"
#include "MatlabHelpers.h"

using namespace std;
using namespace VideoIO;

/** These globals are used by almost every function.  Unfortunately, they 
 *  pretty much have to be globals since killServer is not allowed to take
 *  any arguments and it must access these.  */
static bool  initialized = false;
static FILE  *toServer   = NULL;
static FILE  *fromServer = NULL;
static pid_t childPid    = -1;

/** As a MEX function, we launch a server process that implements the plugin.
 *  Find the server executable that's found in the same directory as this MEX 
 *  file.  This hopefully helps to make sure different versions don't get 
 *  mixed together. */
string findServerProc() {
  return getMexPathname() + "Server";
}

/** When the mex function is interrupted by Ctrl-C or when it's about to be
 *  cleared, we want to force ourselves into a known state and kill off the 
 *  server.
 */
void killServer() {
  VERBOSE("Killing " << findServerProc() << "...\n");
  // retry every 10ms
  const static int retryUSec        = 10*1000; 
  // give the server process 2s to shutdown gracefully
  const static int maxRetryAttempts = (2*1000*1000) / retryUSec; 
  // Try to kill off the server and reset ourselves
  if (childPid != -1) {
    if (kill(childPid, SIGTERM) == 0) {
      bool hardKill = true;
      for (int retryNum = 0; retryNum < maxRetryAttempts; retryNum++) {
        int waitVal = waitpid(childPid, NULL, WNOHANG);
        
        // error -- there's nothing more we can do
        if (waitVal < 0) break; 
        // child doesn't exist or hasn't exited.  wait a little.
        if (waitVal == 0) { usleep(retryUSec); continue; }
        // child killed
        if (waitVal == childPid) { hardKill = false; break; }
      }
      
      // Be aggressive and kill it for real if the server doesn't want to die.
      if (hardKill) kill(childPid, SIGKILL);
    }
  }
  if (toServer)   { fclose(toServer);   toServer   = NULL; }
  if (fromServer) { fclose(fromServer); fromServer = NULL; }
  initialized = false;
  VERBOSE("...killed " << findServerProc() << "\n");
}

void initialize() {
#ifdef ECHO_PIPE_COMMUNICATION
  string const logfname = (getMexName() + ".log");
  VrFatalIoCheckMsg(
    (wecho = fopen(logfname.c_str(), "w")) != NULL,
    "Could not open log file: \"" << logfname << "\".");
#endif
  
  // Here we reap any left-over zombie children.  This can happen if this
  // mex function gets cleared from memory without fully shutting down
  // the server.  Note: if someone else has a MEX function that actually 
  // wants to reap manually, there's a slim chance we'll mess them up.  This
  // seems rather unlikely since Matlab is single-threaded.  
  while (waitpid(0, NULL, WNOHANG) > 0);
    
  string const serverProc = findServerProc();
  
  // Matlab likes to override the LD_LIBRARY_PATH environment variable.  
  // While this works well for their executable, it causes problems for
  // mex functions that are built against different versions of gcc.  So
  // far, the most robust method we have found to handle this situation is 
  // to wipe out the LD_LIBRARY_PATH variable so that ther serverProc does
  // not inherit Matlab's preferred value.  With the current build files,
  // any necessary library path information is already built in.  Note that
  // modifying LD_LIBRARY_PATH does not affect the loading of shared libraries
  // (such as mex functions) of currently-running processes. It only affects 
  // newly-launched ones.
  string const oldLdLibPath = getenv("LD_LIBRARY_PATH");
  VrFatalIoCheckMsg(unsetenv("LD_LIBRARY_PATH")==0,
                    "Could not clear the LD_LIBRARY_PATH environment "
                    "variable.");

  // Start the server process
  static int infp, outfp;
  childPid = popen2(serverProc.c_str(), &infp, &outfp);

  // Restore the LD_LIBRARY_PATH.
  VrFatalIoCheck(setenv("LD_LIBRARY_PATH", oldLdLibPath.c_str(), 1)==0);

  // Finish wiring ourselves up to the server process
  mexAtExit(killServer);
  VERBOSE("Started video server process with PID " << childPid 
          << " (infp=" << infp << ",outfp=" << outfp << ")\n");
  VrFatalIoCheck(fromServer = fdopen(outfp, "r"));
  VrFatalIoCheck(toServer   = fdopen(infp,  "w"));
  initialized = true;
}

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


class MatArrayVec : public vector<MatArray*> {
public:
  MatArrayVec(size_t n) : vector<MatArray*>(n) {
    for (size_t i=0; i<size(); i++) {
      (*this)[i] = NULL;
    }
  }

  virtual ~MatArrayVec() {
    squeeze();
  }

  void squeeze() {
    for (size_t i=0; i<size(); i++) {
      MatArray *&m = (*this)[i];
      if (m != NULL) {
        delete m;
        m = NULL;
      }
    }
    this->resize(0);
  }
};

void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])
{
  TRACE;

  try {
    if (!initialized) initialize();

    MatArrayVec rhs(nrhs); // auto_ptr's okay w/ no resize
    try {
      // Errors are recoverable as long as we don't write anything to the
      // communication channel.
      for (int i=0; i<nrhs; i++) {
        rhs[i] = new MatArray(prhs[i]);
      }
    } catch(VrRecoverableException const &e) {
      VERBOSE("Recoverable exception:\n" + e.message);
      // Avoid some really nasty double-free problems by forcing rhs to
      // free its mxMalloc-ed memory *before* mexErrMsgTxt frees it.
      rhs.squeeze();
      mexErrMsgTxt(e.message.c_str());
      VERBOSE("Recoverable exception, returning "
              "(this line should *never* execute)...");
    }

    // For now, we'll just block all Ctrl-C attempts.  If we find some
    // backends that hang, we may create timers that will do a hard kill.
    CtrlCTrap trap;

    // Pass data to server
    const int reqMsgId = writeMessageHeader(toServer);
    writeScalar<int>(nlhs, toServer);
    writeScalar<int>(nrhs, toServer);
    for (int i=0; i<nrhs; i++) {
      writeMatArray(*rhs[i], toServer);
    }
    rhs.squeeze();
    writeMessageFooter(toServer);
    VrFatalIoCheck(fflush(toServer) == 0);

    // Get back response
    const int respMsgId = readMessageHeader(fromServer);
    VrFatalCheckMsg(reqMsgId == respMsgId,
                    "Received response for message #" << respMsgId << ", but "
                    "expected a response for #" << reqMsgId);

    // Analyze the response
    ResponseType const rt = (ResponseType)readScalar<int>(fromServer);
    VERBOSE("Response: " << rt);
    switch (rt) {
    case Success:
      {
        const int nlhsReturned = readScalar<int>(fromServer);
        VERBOSE(nlhsReturned << " lhs args returned (" << nlhs
                << " slots should be filled)");
        VrRecoverableCheckMsg(nlhsReturned <= nlhs ||
                              (nlhsReturned == 1 && nlhs == 0),
          "Expected " << nlhs << " left hand arguments from the server, but " 
          << nlhsReturned << " were returned instead.");
        for (int i=0; i<nlhsReturned; i++) {
          readMatArray(fromServer)->transferToMat(plhs[i]);
        }
      }
      readMessageFooter(fromServer);
      break;

    case FatalError:
      VrFatalThrow(readString(fromServer));
      // No need to read the footer--this is panic mode
      break;

    case NonFatalError:
      { 
        string errMsg = readString(fromServer);
        // *must* read footer before erroring out!
        readMessageFooter(fromServer);
        trap.release(); // makes R13sp1 work (it skips destructors)
        // communication is done, so the channel isn't corrupted--no need
        // to make this fatal.
        mexErrMsgTxt(errMsg.c_str());
      }
      break;

    default:
      trap.release(); // makes R13sp1 work (it skips destructors)
      VrFatalThrow("Unexpected response type from server: " << rt);
      // No need to read the pipe's footer--this is panic mode
    }

    if (trap.trapped()) {
      trap.release(); // makes R13sp1 work (it skips destructors)
      mexErrMsgTxt("User break");
    }

  } catch (VrRecoverableException const &e) {
    VERBOSE("Otherwise recoverable exception encountered after communication "
            "with the backend began, clearing self:\n" + e.message);
    v_mat_s("clear", getMexName().c_str());
    VERBOSE("Otherwise recoverable error, generating matlab error...");
    mexErrMsgTxt(e.message.c_str());
    VERBOSE("Otherwise recoverable exception, returning "
            "(this line should *never* execute)...");

  } catch (VrFatalError const &e) {
    VERBOSE("Fatal exception, clearing self:\n" + e.message);
    // When we have a protocol error and/or when the server reports a fatal
    // error, (1) we kill off the server so we can start a fresh one later, and
    // (2) we unload this mex file so all the static and global C++ variables 
    // here get cleared.
    v_mat_s("clear", getMexName().c_str());
    VERBOSE("Fatal error, generating matlab error...");
    mexErrMsgTxt(e.message.c_str());
    VERBOSE("Fatal error, returning (this line should *never* execute)...");
  }
}
