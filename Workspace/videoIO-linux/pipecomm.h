#ifndef PIPECOMM_H
#define PIPECOMM_H

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
#include <sstream>
#include <stdio.h>
#include <memory>
#include <errno.h>
#include "debug.h"
#include "handle.h"
#include "matarray.h"

namespace VideoIO 
{

  /** The functions defined here define the low-level communication protocol 
  *  we use over a set of pipes for the videoIO library.  Code in 
  *  mexClientPopen2.cpp and mexServerStdio.cpp should exclusively 
  *  use these functions for read/write communication with each other.  When 
  *  debugging, ECHO_PIPE_COMMUNICATION in debug.h may be enabled to cause all 
  *  written communication to be logged to disk.  When logging, it can also be 
  *  useful to enable TEXT_COMMUNICATIONS here so that the log is more easily 
  *  read.  The functions defined here are rather straightforward (modulo the 
  *  copious #ifdefs), so most further documentation is omitted.
  *
  *  The high-level protocol is implicitly defined in mexClientPopen2.cpp
  *  and mexServerStdio.cpp.  It's small and simple enough that it wasn't 
  *  worth the effort to make a set of message classes with complicated 
  *  serializers and deserializers.
  */

#ifdef ECHO_PIPE_COMMUNICATION
  FILE *wecho = NULL;
#endif

#define VIDEOIO_COMM_TAG "VideoIOMessage"
#define VIDEOIO_COMM_HEADER_PATTERN "<" VIDEOIO_COMM_TAG " id=\"%d\">\n" 
#define VIDEOIO_COMM_FOOTER "\n</" VIDEOIO_COMM_TAG ">\n"

  typedef enum {
    Success, FatalError, NonFatalError
  } ResponseType;

  /*----- writing functions ----------------------------------------------------*/

  /** call writeScalar, not this one */
  template <class T>
  inline void writeScalarLowLevel(T val, FILE *out = stdout) 
  {
#ifdef TEXT_COMMUNICATIONS
    std::stringstream s;
    s << val << " ";
    VrFatalIoCheck(fputs(s.str().c_str(), out));
#else
    VrFatalIoCheck(fwrite(&val, sizeof(T), 1, out) == 1);
#endif
  }

  template <class T>
  inline void writeScalar(T val, FILE *out = stdout) 
  {
    TRACE;
    writeScalarLowLevel<T>(val, out);
#ifdef ECHO_PIPE_COMMUNICATION
    writeScalarLowLevel<T>(val, wecho);
    VrFatalIoCheck(fflush(wecho) == 0);
#endif
  }

  inline void writeStringLowLevel(std::string s, FILE *out = stdout)
  {
    std::stringstream escaped;
    for (int i=0; i<s.size(); i++) {
      switch (s[i]) {
        case '\\': escaped << "\\\\"; break;
        case '\n': escaped << "\\n"; break;
        default: escaped << s[i];
      }
    }
#ifdef TEXT_COMMUNICATIONS
    VrFatalIoCheck(fputs(escaped.str().c_str(), out));
    VrFatalIoCheck(fputc('\n', out) == '\n');
#else
    VrFatalIoCheck(fputs(escaped.str().c_str(), out));
    VrFatalIoCheck(fputc('\n', out) == '\n');
#endif
  }

  // Note: s must not contain any newline characters (we check!)
  inline void writeString(std::string s, FILE *out = stdout)
  {
    TRACE;
    writeStringLowLevel(s, out);
#ifdef ECHO_PIPE_COMMUNICATION
    writeStringLowLevel(s, wecho);
    VrFatalIoCheck(fflush(wecho) == 0);
#endif
  }

  inline void writeBinaryDataLowLevel(void const *data, size_t sz, FILE *out = stdout)
  {
#ifdef TEXT_COMMUNICATIONS
    unsigned char const *d = (unsigned char const *)data;
    while (sz--) {
      VrFatalIoCheck(fprintf(out, "%02x ", (int)(*d++)) > 0);
    }
#else
    size_t written = fwrite(data, 1, sz, out);
    VrFatalIoCheckMsg(written == sz, 
      "Expected " << sz << " bytes to be written, but only " << written << 
      " were actually written.");
#endif
  }

  inline void writeBinaryData(void const *data, size_t sz, FILE *out = stdout)
  {
    TRACE;
    writeBinaryDataLowLevel(data, sz, out);
#ifdef ECHO_PIPE_COMMUNICATION
    writeBinaryDataLowLevel(data, sz, wecho);
    VrFatalIoCheck(fflush(wecho) == 0);
#endif
  }

  static int lastAutoMsgIdForIncludingModule = 0;

  inline int writeMessageHeader(FILE *out = stdout,
                                 int msgId = lastAutoMsgIdForIncludingModule++)
  {
    TRACE;

    // Directly write, not using writeString since we don't want it messing 
    // with newlines or anything.    
    VrFatalIoCheck(fprintf(out, VIDEOIO_COMM_HEADER_PATTERN, msgId) > 0);
#ifdef ECHO_PIPE_COMMUNICATION
    VrFatalIoCheck(fprintf(wecho, VIDEOIO_COMM_HEADER_PATTERN, msgId) > 0);
    VrFatalIoCheck(fflush(wecho) == 0);
#endif
    VERBOSE("Wrote header for message " << msgId);
    return msgId;
  }

  inline void writeMessageFooter(FILE *out = stdout)
  {
    TRACE;
    // Directly write, not using writeString since we don't want it messing 
    // with newlines or anything.
    VrFatalIoCheck(fputs(VIDEOIO_COMM_FOOTER, out));
#ifdef ECHO_PIPE_COMMUNICATION
    VrFatalIoCheck(fputs(VIDEOIO_COMM_FOOTER, wecho));
    VrFatalIoCheck(fflush(wecho) == 0);
#endif
  }

  inline void writeMatArray(MatArray const &arr, FILE *out = stdout)
  {
    TRACE;

    writeScalar<int>(arr.mx(), out);

    writeScalar<uint64>(arr.dims().size(), out);
    writeBinaryData(&arr.dims()[0], arr.dims().size()*sizeof(arr.dims()[0]), out);

    if (arr.mx() == MatDataTypeConstants::mxCELL_CLASS) {
      MatArray const **a = (MatArray const **)arr.data();
      for (size_t i=0; i<arr.numElm(); i++) {
        writeMatArray(*a++, out);
      }
    } else {
      uint64 nBytes = arr.numElm() * MatDataTypeConstants::elmSize(arr.mx()); 
      writeBinaryData(arr.data(), nBytes, out);
    }
  }

  /*----- reading functions ----------------------------------------------------*/

#ifdef TEXT_COMMUNICATIONS
  inline void eatLeadingWhitespace(FILE *in)
  {
    int c;
    while (isspace((c = fgetc(in))));
    VrFatalIoCheck(c != EOF);
    VrFatalIoCheck(ungetc(c, in) == c);
  }
#endif

  template <class T>
  inline T readScalar(FILE *in = stdin)
  {
    TRACE;
#ifdef TEXT_COMMUNICATIONS
    eatLeadingWhitespace(in);
    std::stringstream s;
    char c;
    while (!isspace(c = fgetc(in))) s << c;
    T val;
    s >> val;
    return val;
#else
    T val;
    VrFatalIoCheck(fread(&val, sizeof(T), 1, in) == 1);
    return val;
#endif
  }

  inline std::string readString(FILE *in = stdin)
  {
    TRACE;
#ifdef TEXT_COMMUNICATIONS
    eatLeadingWhitespace(in);
#endif
    std::stringstream s;
    bool done = false;
    bool escapeJustRead = false;
    while (!done) {
      int c;
      if ((c = fgetc(in)) == EOF) break;
      switch (c) {
        case '\n': 
          done = true; break;
        case '\\': 
          if (escapeJustRead) {
            s << '\\';
            escapeJustRead = false;
          } else {
            escapeJustRead = true; 
          }
          break;
        case 'n': 
          s << (escapeJustRead ? '\n' : 'n'); 
          escapeJustRead = false; 
          break;
        default:
          s << (char)c;
      }
    }
    VERBOSE("Read string: '" << s.str() << "'\n");
    return s.str();
  }

  inline void readBinaryData(void *data, size_t sz, FILE *in = stdin)
  {
    TRACE;
#ifdef TEXT_COMMUNICATIONS
    unsigned char *d = (unsigned char *)data;
    while (sz--) {
      unsigned int v;
      VrFatalIoCheck(fscanf(in, " %02x", &v) == 1);
      *d++ = v;
    }
#else
    VrFatalIoCheck(fread(data, 1, sz, in) == sz);
#endif
  }

  inline int readMessageHeader(FILE *in = stdin)
  {
    TRACE;

    int msgId = -1;

    std::string s;
    int ch;
    bool done = false;
    while (!done) {
      switch (ch = fgetc(in)) {
      case EOF:
        VrFatalThrow("EOF found while trying to read the communication tag.  "
                     "The server process probably died.  "
                     << "String so far: \"" << s << "\"");
      case '\n': 
        done = true; 
        // fall through
      default:
        s += (char)ch;
        break;
      }
    }

    const int numAssigned = sscanf(s.c_str(), VIDEOIO_COMM_HEADER_PATTERN, &msgId);
    char buff[16384]; 
    VrFatalIoCheckMsg(numAssigned == 1, 
      "Tried to extract 1 value (the message id) from the header tag.  " << 
      numAssigned << " values were extracted instead (msgId=" << msgId << 
      ")" << (feof(in) ? " (end of file!)" : "" ) << " scanned text: \"" << 
      s << "\".  Next string: \"" << fgets(buff, sizeof(buff), in) << 
      "\".  ThreadID = 0x" << std::hex << pthread_self());

    VERBOSE("Read header for message " << msgId);
    return msgId;
  }

  inline void readMessageFooter(FILE *in = stdin)
  {
    TRACE;
    while (true) {
      const char *footer = VIDEOIO_COMM_FOOTER;
      int currChar;
      do {
        if (*footer == '\0') return; // Success!
        currChar = fgetc(in);
        VrFatalIoCheck(currChar != EOF);
      } while ((char)currChar == *footer++);
    }
  }

  inline std::auto_ptr<MatArray> readMatArray(FILE *in = stdin)
  {
    TRACE;
    uint8  mx    = readScalar<int>(in);
    
    uint64 ndims = readScalar<uint64>(in);
    std::vector<int> dims(ndims);
    readBinaryData(&dims[0], ndims*sizeof(dims[0]), in); 

    std::auto_ptr<MatArray> arr;
    try {
      arr.reset(new MatArray(mx, dims));
    } catch(VrRecoverableException const &e) {
      // We're leaving the rest of the input stream unread, so this is fatal.
      // To make this more robust in the future, we should still read all of
      // the expected bytes from the input stream, but just stop creating
      // data structures to hold them.
      throw VrFatalError(e.what());
    }

    if (arr->mx() == MatDataTypeConstants::mxCELL_CLASS) {
      MatArray **a = (MatArray **)arr->data();
      for (size_t i=0; i<arr->numElm(); i++) {
        *a++ = readMatArray(in).release();
      }
    } else {
      size_t nBytes = arr->numElm() * MatDataTypeConstants::elmSize(arr->mx());
      readBinaryData(arr->data(), nBytes, in);
    }

    return arr;
  }

}; /* namespace VideoIO */

#endif
