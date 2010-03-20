// $Date: 2008-11-17 17:39:15 -0500 (Mon, 17 Nov 2008) $
// $Revision: 706 $

/*
videoIO: granting easy, flexible, and efficient read/write access to video 
                 files in Matlab on Windows and GNU/Linux platforms.
    
Copyright (c) 2006 Gerald Dalley
  
Permission is hereby granted, free of charge, to any person obtaining a copy of 
this software and associated documentation files (the "Software"), to deal in 
the Software without restriction, including without limitation the rights to 
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of 
the Software, and to permit persons to whom the Software is furnished to do so, 
subject to the following conditions:

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
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS 
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR 
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER 
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN 
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

#include <sys/types.h>
#include <sys/wait.h>
#include <signal.h>
#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include "popen2.h"

namespace VideoIO 
{

#define READ 0
#define WRITE 1

  /* Error handling helpers */

#define ASSRT_CHILD(testCond) \
  if (!(testCond)) { if (perrorInChild) { perror(#testCond); } exit(errno); }

  static inline int safeClose(int &fd)
  {
    if (fd == -1) return 0;
    const int ret = close(fd);
    fd = -1;
    return ret;
  }

  static inline void closeErrSuppr(int &fd) 
  {
    int olderr = errno; 
    safeClose(fd);
    errno = olderr; 
  }

  static inline void closeErrSupprPipe(int *p) 
  {
    closeErrSuppr(p[0]);
    closeErrSuppr(p[1]);
  }

  #define ASSRT_PARENT(testCond)     \
    if (!(testCond)) {               \
      closeErrSupprPipe(pipeStdin);  \
      closeErrSupprPipe(pipeStdout); \
      *infp = *outfp = -1;           \
      if (pid != -1) {               \
        kill(pid, SIGTERM);          \
        int olderr = errno;          \
        int status;                  \
        waitpid(pid, NULL, 0);       \
        errno = olderr;              \
      }                              \
      return -1;                     \
    }

  /* The real function */
  pid_t popen2(const char *command, int *infp, int *outfp, bool perrorInChild)
  {
    int pipeStdin [2] = { -1, -1 };
    int pipeStdout[2] = { -1, -1 };
    pid_t pid = -1;

    if (pipe(pipeStdin) != 0 || pipe(pipeStdout) != 0) {
      closeErrSupprPipe(pipeStdin);
      closeErrSupprPipe(pipeStdout);
      return -1;
    }

    pid = fork();

    if (pid < 0) {
      /* error, fork didn't work */
      closeErrSupprPipe(pipeStdin);
      closeErrSupprPipe(pipeStdout);
      return pid;

    } else if (pid == 0) {
      /* child process -- connect the read end of pipeStdin to our stdin */
      ASSRT_CHILD(close(pipeStdin[WRITE]) == 0);
      ASSRT_CHILD(dup2(pipeStdin[READ], READ) != -1);
      ASSRT_CHILD(close(pipeStdin[READ]) == 0);

      /* connect the write end of pipeStdout to our stdout */
      ASSRT_CHILD(close(pipeStdout[READ]) == 0);
      ASSRT_CHILD(dup2(pipeStdout[WRITE], WRITE) != -1);
      ASSRT_CHILD(close(pipeStdout[WRITE]) == 0);

      /* run the desired command */
      ASSRT_CHILD(execl("/bin/sh", "sh", "-c", command, NULL) != -1);

      /* execl should never return. */
      exit(errno);
    }

    /* parent process -- return the write end of pipeStdin if requested */
    if (infp == NULL) {
      ASSRT_PARENT(safeClose(pipeStdin[WRITE]) == 0);
    } else {
      *infp = pipeStdin[WRITE];
    }
    ASSRT_PARENT(safeClose(pipeStdin[READ]) == 0);

    /* return the read end of pipeStdout if requested */
    if (outfp == NULL) {
      ASSRT_PARENT(safeClose(pipeStdout[READ]) == 0);
    } else {
      *outfp = pipeStdout[READ];
    }
    ASSRT_PARENT(safeClose(pipeStdout[WRITE]) == 0);

    /* return process id of the child so the parent can use waitfor(), etc. */
    return pid;
  }

}; /* namespace VideoIO */
