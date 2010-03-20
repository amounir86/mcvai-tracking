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
#include "debug.h"
#include "matarray.h"
#include "pipecomm.h"
#include "handleMexRequest.h"

using namespace std;
using namespace VideoIO;

// Users of this file are expected to link to all of the externs in
// handleMexRequest.h.

int obtainRequest(int &nlhs, MatArrayVector &rhs)
{
  TRACE;

  const int msgId = readMessageHeader();
  nlhs = readScalar<int>();
  const int nrhs = readScalar<int>();
  for (int i=0; i<nrhs; i++) {
    rhs.push_back(readMatArray().release());
  }
  readMessageFooter();
  return msgId;
}

void sendNonFatalResponse(int msgId, std::string const &errMsg) 
{
  TRACE;

  writeMessageHeader(stdout, msgId);
  writeScalar<int>(NonFatalError);
  writeString(errMsg);
  writeMessageFooter();
  VrFatalIoCheck(fflush(stdout) == 0);
  VERBOSE("server sent non-fatal response: " << errMsg.c_str());
}

void sendFatalResponse(int msgId, std::string const &errMsg) 
{
  TRACE;

  writeMessageHeader(stdout, msgId);
  writeScalar<int>(FatalError);
  writeString(errMsg);
  writeMessageFooter();
  VrFatalIoCheck(fflush(stdout) == 0);
  VERBOSE("server sent fatal response: " << errMsg.c_str());
}

void sendSuccessResponse(int msgId, MatArrayVector const &lhs) 
{
  TRACE;

  writeMessageHeader(stdout, msgId);
  writeScalar<int>(Success);
  
  writeScalar<int>((int)lhs.size());
  for (size_t i=0; i<lhs.size(); i++) {
    writeMatArray(*lhs[i]);
  }

  writeMessageFooter();
  VrFatalIoCheck(fflush(stdout) == 0);
  VERBOSE("server is sending " << lhs.size() << " vars.");
}

int main(int argc, char **argv) 
{
  TRACE;

  try {
#ifdef ECHO_PIPE_COMMUNICATION
    string const logfname(string(argv[0]) + ".log");
    VrFatalIoCheckMsg(wecho = fopen(logfname.c_str(), "w"),
                      "Unable to open log file: \"" << logfname << "\".");
#endif

    while (true) {
      VERBOSE("Obtaining request...");
      int nlhs;
      MatArrayVector rhs;
      const int msgId = obtainRequest(nlhs, rhs);

      if (rhs.size() > 0 && 
          rhs[0]->mx() == MatDataTypeConstants::mxCHAR_CLASS) {
        VERBOSE("Request has " << rhs.size() << " arguments with \"" <<
                mat2string(rhs[0]) << "\" as the first argument.");
      }
      
      VERBOSE("Handling request...");
      MatArrayVector lhs;
      try {
        handleMexRequest(lhs, nlhs, rhs);

        VERBOSE("Sending response...");
        sendSuccessResponse(msgId, lhs);

      } catch (VrRecoverableException const &e) {
        sendNonFatalResponse(msgId, e.message);
      } catch (VrFatalError const &e) {
        sendFatalResponse(msgId, e.message);
      } catch (...) {
        sendFatalResponse(msgId, "Unexpected exception trapped!");
      }
    }

  } catch (VrRecoverableException const &e) {
    PRINTERROR("Otherwise recoverable server exception "
               "(server is exiting):\n" + e.message);
    cleanup();
    exit(1);
  } catch (VrFatalError const &e) {
    PRINTERROR("Fatal server exception (server is exiting):\n" + e.message);
    cleanup();
    exit(2);
  } catch (...) {
    PRINTERROR("Fatal server exception (server is exiting):\n" 
               "Unexpected exception (unknown type)!");
    cleanup();
    exit(3);
  }

  return 0;
}
