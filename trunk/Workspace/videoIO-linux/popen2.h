#ifndef POPEN2_H
#define POPEN2_H

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

#include <unistd.h>

namespace VideoIO 
{

  /** 
  * Executes an external shell command with the new command's stdin and 
  * stdout streams redirected via pipes to the current process.  This function 
  * works like popen (man popen), but returns two file descriptors, one for 
  * reading from the new command's stdout and one for writing to its stdin.  
  *
  * Parameters
  *    command: the shell command to execute in a new process.  It is evaluated
  *             as "/bin/sh -c ${command}" where ${command} is the contents of 
  *             the command string argument.  The new process' stdin and stdout
  *             are redirected to infp and outfp before it is executed.  The 
  *             redirection is managed by anonymous pipes.
  *
  *    infp:    returns a file descriptor that is connected to the new process'
  *             stdin.  Standard I/O operations such as read, close, and 
  *             fdopen may be used on it.  If fdopen is used to associate a 
  *             stream with infp, remember to use fflush as appropriate to 
  *             force the data to actually travel through the pipe.  infp 
  *             should be closed with close().  If fdopen is used, fclose on 
  *             the associated stream may be used instead of close(infp).  If 
  *             infp is NULL, the connection to the new process' stdin will 
  *             automatically be closed inside this function.
  *
  *    outfp:   returns a file descriptor that is connected to the new process'
  *             stdout.  Standard I/O operations such as write, close, and 
  *             fdopen may be used on it.  outfp should be closed with close().
  *             If fdopen is used, fclose on the associated stream may be used 
  *             instead of close(outfp).  If outfp is NULL, the connection to 
  *             the new process' stdout will automatically be closed inside 
  *             this function.
  *
  *    perrorInChild: 
  *             If true and an error occurs in the new process, the perror
  *             function will be used to print a short error message (to 
  *             stderr).  If false, the error message will be suppressed.
  *
  * Return value
  *   If the caller process' side of the function is successful, the process id
  *   of the command's new process is returned.  The caller must reap the child
  *   with a call to wait or waitpid when it terminates in order for all its
  *   resources to be freed.  
  *
  *   If an error does occur in the caller's side, -1 is returned.  In this 
  *   case the child process is reaped internally if necessary (since the 
  *   caller will have no reliable way of reaping it without knowing its 
  *   process id).
  *
  * Error handling:
  *   If an error occurs in the caller process' side of the function, the 
  *   following occur:
  *     1) The new process is killed with a SIGTERM signal and reaped 
  *        internally.
  *     2) errno is set as described by pipe, fork, and close's documentation 
  *        according to the first offending error.
  *     3) infp and outfp are set to -1
  *     4) -1 is returned
  *
  *   If an error occurs in the child process while attempting to redirect 
  *   stdin and stdout or begin execution of the requested command, the 
  *   following occur:
  *     1) The child process' exit code is set to errno (see the documentation 
  *        for close, dup2, and execl for possible errno values).
  *     2) If perrorInChild is true, a brief message is first printed to stderr
  *     3) The child process is terminated.  The caller must reap the child 
  *        with a call to wait or waitpid to free all its resources.
  *
  *   If the command begins execution successfully, it will proceed normally 
  *   with its own error handling.  Note that if it the caller wishes to 
  *   examine its exit code after calling wait or waitpid, there is no general 
  *   way of telling the difference from an exit code set to be errno (as 
  *   described in the previous paragraph) and an exit code of the same value 
  *   set by the command.
  *
  * If all is successful, the child process will execute normally.  To supply
  * data to be read by its stdin stream, the caller should write to infp.  To 
  * receive data that the child writes to its stdout stream, read from outfp.  
  * When the child process terminates, the caller must reap it by calling wait 
  * or waitpid.
  *
  * A few quick notes about wait and waitpid: Once a child process terminates,
  * it becomes a so-called "zombie" process and remains that way until reaped.
  * Calls to wait or waitpid are used to explicitly reap processes.  Also, 
  * when the caller application terminates, the children that are zombies are 
  * usually reaped automatically (but not always!).  If the caller does not 
  * care about the value of child process exit codes or precisely controlling 
  * when the reaping occurs, it is often convenient to create a function of the
  * form:
  *   static void childreap(int s) { while (waitpid(0, NULL, WNOHANG) > 0); }
  * and have it automatically reap all children by executing:
  *   signal(SIGCHLD, childreap);
  * To work properly, this call to signal must occur before the child exits.  
  * The busy-wait nature of childreap is not as bad as it appears since 
  * childreap will only get called when SIGCHLD is raised.
  *
  * The original implementation for this function was posted at
  *     http://www.bigbold.com/snippets/tag/popen
  * Changes were made by Gerald Dalley primarily to add this documentation, 
  * implement safety checks, and free up allocated file descriptor resources.
  */
  pid_t popen2(const char *command, int *infp, int *outfp, 
    bool perrorInChild = true);

}; /* namespace VideoIO */

#endif
