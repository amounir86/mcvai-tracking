// $Date: 2008-11-29 20:52:15 -0500 (Sat, 29 Nov 2008) $
// $Revision: 712 $

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

#include "handleMexRequest.h"
#include "OVideo.h"
#include "matarray.h"
#include "debug.h"
#include "registry.h"

using namespace std;
using namespace VideoIO;

//------ Operation implementations -------------------------------------------

void codecs(vector<MatArray*> &lhs, int nlhs, Handle handle, 
            vector<MatArray*> const &rhs)
{ 
  TRACE;
  nlhsCheck(nlhs, 1);
  nrhsCheck(rhs, 0);
  // don't worry about checking the handle: go ahead and allow static method 
  // calls for instances.

  set<string> const codecs = oVideoManager()->getcodecs();
  auto_ptr<MatArray> matCodecs( 
    new MatArray(MatDataTypeConstants::mxCELL_CLASS, 1, codecs.size()));
  size_t i = 0;
  for (set<string>::const_iterator ii = codecs.begin(); 
       ii != codecs.end(); 
       ii++,i++) 
  {
    ((MatArray**)matCodecs->data())[i] = string2mat(*ii).release();
  }
  lhs.push_back(matCodecs.release());
}

void open(vector<MatArray*> &lhs, int nlhs, Handle handle, 
          vector<MatArray*> const &rhs)
{ 
  TRACE;
  nlhsCheck(nlhs, 3);
  VrRecoverableCheckMsg(rhs.size() >= 1, 
                        "The filename to open must be specified");
  VrRecoverableCheckMsg((rhs.size()-1) % 2 == 0, 
                        "Parameters and values must come in pairs");
  
  string const filename = mat2string(rhs[0]);

  KeyValueMap kvm;
  for (size_t i=1; i<rhs.size(); i+=2) {
    kvm[mat2string(rhs[i])] = mat2string(rhs[i+1]);
  }
  kvm["filename"] = filename;

  // These exceptions are fatal for now...
  auto_ptr<OVideo> newVid(oVideoManager()->createVideo());
  VrRecoverableCheck(newVid.get() != NULL);
  newVid->setup(kvm);
  if (!newVid->isOpen()) newVid->open(filename);
  Handle const newHandle = oVideoManager()->registerVideo(newVid.get());
  VERBOSE("New handle = " << newHandle << "\n");

  try {
    lhs.push_back(scalar2mat<Handle>(newHandle).release());
    lhs.push_back(scalar2mat<double>(newVid->getWidth()).release());
    lhs.push_back(scalar2mat<double>(newVid->getHeight()).release());
  } catch(...) {
    newVid.release();
    throw;
  }
  newVid.release();
}

void get(vector<MatArray*> &lhs, int nlhs, Handle handle, 
         vector<MatArray*> const &rhs)
{
  TRACE;
  nlhsCheck(nlhs, 2);
  nrhsCheck(rhs,  0);

  // lookupOVideo should never give us a NULL pointer and the caller should
  // never ask for an invalid handle.  Don't convert to VrRecoverableException
  OVideo *vid = oVideoManager()->lookupVideo(handle);
  VrRecoverableCheck(vid != NULL);

  KeyValueMap kvm = vid->getSetupAndStats();

  int const nFields = kvm.size();
  auto_ptr<MatArray> matFieldNames( 
    new MatArray(MatDataTypeConstants::mxCELL_CLASS, 1, nFields));
  MatArray **names  = (MatArray**)matFieldNames->data();
  auto_ptr<MatArray> matFields(
    new MatArray(MatDataTypeConstants::mxCELL_CLASS, 1, nFields));
  MatArray **fields = (MatArray**)matFields->data();

  for (KeyValueMap::const_iterator i=kvm.begin(); i!=kvm.end(); i++) {
    *names++  = string2mat(i->first).release();
    *fields++ = string2mat(i->second).release();
  }

  lhs.push_back(matFieldNames.release());
  lhs.push_back(matFields.release());
}

void addFrame(vector<MatArray*> &lhs, int nlhs, Handle handle, 
              vector<MatArray*> const &rhs)
{ 
  TRACE;
  nlhsCheck(nlhs, 0);
  nrhsCheck(rhs,  1);

  VrRecoverableCheckMsg(rhs[0]->mx() == MatDataTypeConstants::mxUINT8_CLASS,
                        "Only uint8 arrays are supported.");
  VrRecoverableCheckMsg(rhs[0]->dims().size() == 3, 
                        "Only color images are supported.");
  VrRecoverableCheckMsg(rhs[0]->dims()[2] == 3, 
                        "Only 3-channel color images are supported");

  OVideo *vid = oVideoManager()->lookupVideo(handle);
  
  int const h = rhs[0]->dims()[0];
  int const w = rhs[0]->dims()[1];
  int const d = rhs[0]->dims()[2];

  const size_t N = w*h*d*sizeof(unsigned char);
  IVideo::Frame data(N);
  memcpy(&data[0], rhs[0]->data(), N);

  vid->addframe(w, h, d, data);

  // no lhs returned.
}

void close(vector<MatArray*> &lhs, int nlhs, Handle handle, 
           vector<MatArray*> const &rhs)
{ 
  TRACE;
  nlhsCheck(nlhs, 0);
  nrhsCheck(rhs,  0);
  oVideoManager()->deleteVideo(handle);  
}

//////////////////////////////////////////////////////////////////////////////

void VideoIO::handleMexRequest(vector<MatArray*> &lhs, 
                                   int nlhs, 
                                   vector<MatArray*> const &rhs)
  throw(VrFatalError, VrRecoverableException)
{
  TRACE;

  vector<MatArray*> myRhs(rhs);

  string op;
  Handle handle;
  extractOpAndHandle(op, handle, myRhs);
  VERBOSE("Received a request for operation \"" << op 
          << "\" on handle " << handle << "\n");

  // Dispatch based on the desired operation
  if      (op == "codecs")   { codecs  (lhs, nlhs, handle, myRhs); } // static
  else if (op == "open")     { open    (lhs, nlhs, handle, myRhs); } // c'tor
  else if (op == "get")      { get     (lhs, nlhs, handle, myRhs); }
  else if (op == "addframe") { addFrame(lhs, nlhs, handle, myRhs); }
  else if (op == "close")    { close   (lhs, nlhs, handle, myRhs); }
  else {
    VrRecoverableThrow("Attempt to call unsupported operation: '"<<op<<"'.");
  }  
}

void VideoIO::cleanup()
{
  TRACE;
  freeAllVideoManagers();
}
