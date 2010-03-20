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

#include "handleMexRequest.h"
#include "IVideo.h"
#include "matarray.h"
#include "debug.h"
#include "registry.h"

using namespace std;
using namespace VideoIO;

//------ Operation implementations -------------------------------------------

void open(vector<MatArray*> &lhs, int nlhs, Handle handle, 
          vector<MatArray*> const &rhs)
{ 
  TRACE;
  nlhsCheck(nlhs, 1);
  VrRecoverableCheckMsg(rhs.size() >= 1, 
                        "The filename to open must be specified");
  VrRecoverableCheckMsg((rhs.size()-1) % 2 == 0, 
                        "Parameters and values must come in pairs");
  string filename = mat2string(rhs[0]);

  KeyValueMap kvm;
  for (size_t i=1; i<rhs.size(); i+=2) {
    kvm[mat2string(rhs[i])] = mat2string(rhs[i+1]);
  }
  kvm["filename"] = filename;

  // These exceptions are fatal...
  auto_ptr<IVideo> newVid(iVideoManager()->createVideo());
  VrRecoverableCheck(newVid.get() != NULL);
  newVid->open(kvm);
  Handle const newHandle = iVideoManager()->registerVideo(newVid.release());
  VERBOSE("New handle = " << newHandle);
  
  lhs.push_back(scalar2mat<Handle>(newHandle).release());
}

void get(vector<MatArray*> &lhs, int nlhs, Handle handle, 
         vector<MatArray*> const &rhs)
{ 
  TRACE;
  nlhsCheck(nlhs, 2);
  nrhsCheck(rhs,  0);

  IVideo *vid = iVideoManager()->lookupVideo(handle);
  VrRecoverableCheck(vid != NULL);

  string type;
  switch (vid->depth()) {
  case 1: type = "g"; break;
  case 2: type = "ga"; break;
  case 3: type = "rgb"; break;
  case 4: type = "rgba"; break;
  default: 
    VrRecoverableThrow("unsupported byte depth: " << vid->depth());
  }
  
  IVideo::ExtraParamsAndStats const extraParams = vid->extraParamsAndStats();

  static const int nFields = 10 + (int)extraParams.size();
  auto_ptr<MatArray> matFieldNames( 
    new MatArray(MatDataTypeConstants::mxCELL_CLASS, 1, nFields));
  MatArray **names  = (MatArray**)matFieldNames->data();
  auto_ptr<MatArray> matFields(
    new MatArray(MatDataTypeConstants::mxCELL_CLASS, 1, nFields));
  MatArray **fields = (MatArray**)matFields->data();

  *names++  = string2mat("url").release();
  *fields++ = string2mat(vid->filename()).release();

  *names++  = string2mat("fps").release();
  *fields++ = scalar2mat<double>(vid->fps()).release();

  *names++  = string2mat("width").release();
  *fields++ = scalar2mat<double>(vid->width()).release();

  *names++  = string2mat("height").release();
  *fields++ = scalar2mat<double>(vid->height()).release();

  *names++  = string2mat("bpp").release();
  *fields++ = scalar2mat<double>(vid->depth()*8).release();

  *names++  = string2mat("type").release();
  *fields++ = string2mat(type).release();

  *names++  = string2mat("numFrames").release();
  *fields++ = scalar2mat<double>(vid->numFrames()).release();

  // Use "approxFrameNum" as the undocumented field's name.  This is because 
  // some codecs use imprecise seeking (in DirectShow only, as of 14 Jan 2008).
  *names++  = string2mat("approxFrameNum").release();
  *fields++ = scalar2mat<double>(vid->currFrameNum()).release();

  *names++  = string2mat("fourcc").release();
  *fields++ = string2mat(fourCCToString(vid->fourcc())).release();

  *names++  = string2mat("nHiddenFinalFrames").release();
  *fields++ = scalar2mat(vid->numHiddenFinalFrames()).release();
  
  for (IVideo::ExtraParamsAndStats::const_iterator i=extraParams.begin(); 
       i!=extraParams.end(); ++i) 
  {
    *names++  = string2mat(i->first).release();
    *fields++ = string2mat(i->second).release();
  }

  // just a sanity check if we change the # of fields -- fatal because we
  // may have corrupted memory if we ran off the end of an array.
  VrFatalCheck(names - (MatArray**)matFieldNames->data() == nFields);

  lhs.push_back(matFieldNames.release());
  lhs.push_back(matFields.release());
}

void next(vector<MatArray*> &lhs, int nlhs, Handle handle, 
          vector<MatArray*> const &rhs)
{  
  TRACE;
  nlhsCheck(nlhs, 1);
  nrhsCheck(rhs,  0);

  IVideo *vid = iVideoManager()->lookupVideo(handle);
  VrRecoverableCheck(vid != NULL);

  lhs.push_back(scalar2mat<double>(vid->next()).release());
}

void step(vector<MatArray*> &lhs, int nlhs, Handle handle, 
          vector<MatArray*> const &rhs)
{ 
  TRACE;
  nlhsCheck(nlhs, 1);
  nrhsCheck(rhs,  1);

  IVideo *vid = iVideoManager()->lookupVideo(handle);
  VrRecoverableCheck(vid != NULL);

  int const amt = (int)mat2scalar<double>(rhs[0]);

  VERBOSE("stepping by " << amt);
  lhs.push_back(scalar2mat<double>(vid->step(amt)).release());
}

void seek(vector<MatArray*> &lhs, int nlhs, Handle handle, 
          vector<MatArray*> const &rhs)
{ 
  TRACE;
  nlhsCheck(nlhs, 1);
  nrhsCheck(rhs,  1);

  IVideo *vid = iVideoManager()->lookupVideo(handle);
  VrRecoverableCheck(vid != NULL);

  int const amt = (int)mat2scalar<double>(rhs[0]);

  lhs.push_back(scalar2mat<double>(vid->seek(amt)).release());
}

void getframe(vector<MatArray*> &lhs, int nlhs, Handle handle, 
              vector<MatArray*> const &rhs)
{ 
  TRACE;
  nlhsCheck(nlhs, 1);
  nrhsCheck(rhs,  0);

  IVideo *vid = iVideoManager()->lookupVideo(handle);
  VrRecoverableCheck(vid != NULL);

  if (vid->currFrameNum() < 0) {
    VrRecoverableThrow("Invalid frame.  Perhaps you have forgotten to first "
                       "call next, step, or seek.");
  }

  vector<int> dims;
  dims.push_back(vid->height());
  dims.push_back(vid->width());
  dims.push_back(vid->depth());
  
  auto_ptr<MatArray> mat(new MatArray(MatDataTypeConstants::mxUINT8_CLASS, 
                                      dims));

  const size_t nBytes = mat->numElm() * 
    MatDataTypeConstants::elmSize(mat->mx());
  memcpy(mat->data(), &vid->currFrame()[0], nBytes);

  lhs.push_back(mat.release());
}

void close(vector<MatArray*> &lhs, int nlhs, Handle handle, 
           vector<MatArray*> const &rhs)
{ 
  TRACE;
  nlhsCheck(nlhs, 0);
  nrhsCheck(rhs,  0);
  iVideoManager()->deleteVideo(handle);  
}

//////////////////////////////////////////////////////////////////////////////

void VideoIO::handleMexRequest(vector<MatArray*> &lhs, int nlhs, 
                               vector<MatArray*> const &rhs)
  throw(VrFatalError, VrRecoverableException)
{
  TRACE;

  vector<MatArray*> myRhs(rhs);

  string op;
  Handle handle;
  extractOpAndHandle(op, handle, myRhs);
  VERBOSE("Received a request for operation \"" << op 
          << "\" on handle " << handle);

  // Dispatch based on the desired operation
  if      (op == "open")     { open    (lhs, nlhs, handle, myRhs); }
  else if (op == "get")      { get     (lhs, nlhs, handle, myRhs); }
  else if (op == "next")     { next    (lhs, nlhs, handle, myRhs); }
  else if (op == "step")     { step    (lhs, nlhs, handle, myRhs); }
  else if (op == "seek")     { seek    (lhs, nlhs, handle, myRhs); }
  else if (op == "getframe") { getframe(lhs, nlhs, handle, myRhs); }
  else if (op == "close")    { close   (lhs, nlhs, handle, myRhs); }
  else {
    VrRecoverableThrow("Attempt to call unsupported operation " << op << ".");
  }  
}

void VideoIO::cleanup()
{
  TRACE;
  freeAllVideoManagers();
}
