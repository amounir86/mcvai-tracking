// Hacked up by Michael Siracusa
// $Date: ? $
// $Revision: 1 $

/*
copyright stuff
*/

#include <iostream>
#include <errno.h>
#include "Libmpeg3IVideo.h"
#include "registry.h"
#include <algorithm>
#include <cctype>


using namespace std;

namespace VideoIO
{
  class Libmpeg3IVideoManager : public IVideoManager
  {
  public:
    virtual IVideo *createVideo() throw() {
      return new(nothrow) Libmpeg3IVideo();
    }
  };

  static auto_ptr<IVideoManager> oldManager(
    registerIVideoManager(new Libmpeg3IVideoManager()));
  

  // This function generates a .toc file to be named dst from .mpg src.
  // Code taken from mpeg3toc util for Libmpeg3
  bool generateTOCFile(std::string &src,std::string &dst)
  {
    int64_t total_bytes;
    mpeg3_t *file = mpeg3_start_toc((char *)src.c_str(), (char *)dst.c_str(), &total_bytes);
  
    if(!file) { return false; }
    
    int64_t bytes_processed = 0;
    
    while(bytes_processed < total_bytes) {
      mpeg3_do_toc(file, &bytes_processed);
    }

    mpeg3_stop_toc(file);
    return true;
    
  }
  
  // Stupid utility to make things lower case
  // and avoid name conflicts
  int lower_case ( int c )
  {
    return tolower ( c );
  }

  
  
  Libmpeg3IVideo::Libmpeg3IVideo() :
    fname(""), 
    currentFrameNumber(-1),
    videoStream(0),
    pFile(NULL), 
    nHiddenFinalFrames(0),
    nCPUs(1),
    frameWidth(-1),
    frameHeight(-1)
  { 
    TRACE;
  }

  /** Converts C-style RGB images to Matlab's preferred byte layout for images.
   */
  static inline void rgbToMatlab(unsigned char *out, 
    unsigned char const *bgrData, 
    int w, int h, int d)
  {    
    const int dy = w*d;
    for (int c=(d-1); c>=0; c--) {
      for (int x=0; x<w; x++) {
        unsigned char const *b = &bgrData[x*d + (d-1-c)];
        for (int y=0; y<h; y++) {
          // We need to transpose from row-major to column-major, and do 
          // BGR->RGB conversion.
          //*out++ = bgrData[(x+y*w)*d + (d-1-c)]; // without unrolling
          *out++ = *b; 
          b += dy;
        }
      }
    }
  }

 
/** For now this plugin can only seek if a .toc file was specified. 
  * .toc files can be created with the mpeg3toc util that is part of Libmpeg3.
  */

  bool Libmpeg3IVideo::next() 
  {
    TRACE;
    return seek(currentFrameNumber + 1);
  }

  bool Libmpeg3IVideo::step(int frameDelta) 
  { 
    TRACE;
    return seek(currentFrameNumber + frameDelta);
  }


  bool Libmpeg3IVideo::seek(int toFrame) 
  { 
    TRACE;
    VrRecoverableCheckMsg(isOpen(), "No video file is open.");
    VrRecoverableCheckMsg(toFrame >= 0, "Cannot seek to frame " << toFrame << ".");
    VrRecoverableCheckMsg(toFrame < numFrames(), 
                          "Frame " << toFrame << " is past the end of this video.");
    
    
    // There is some issue with seeking backwards with libmpeg3
    if(toFrame < currentFrameNumber) {
      VERBOSE("Seeking backwards: Reopening file to ensure consistent behavoir");
      close();
      open(fname);
    }
    
    VERBOSE("Seeking to frame "<< toFrame );
    
    mpeg3_set_frame(pFile, (long)toFrame, videoStream);
    currentFrameNumber = (int) mpeg3_get_frame(pFile, videoStream);
    
    VrRecoverableCheckMsg(currentFrameNumber == toFrame, 
                          "Failed to seek to frame " << toFrame << ".");
    
    // Decode Frame into rgb buffer
    VERBOSE("Decoding Frame.");
    mpeg3_read_frame(pFile,&rgbRowPtrs[0],0,0,width(),height(),
                     width(),height(),MPEG3_RGB888,videoStream);
    
    // Convert to matlab
    VERBOSE("Converting frame to Matlab Format.");    
    rgbToMatlab(&currentFrame[0], &rgbData[0], width(), height(), depth());
    
    VERBOSE("Frame gotten and converted.");
    
    return true;
  }

  void Libmpeg3IVideo::open(KeyValueMap &kvm) 
  {
    TRACE;

    std::string fname;

    // Extract arguments
    VrRecoverableCheckMsg(kvm.hasKey("filename"), "The filename must be specified");

    for (KeyValueMap::const_iterator i=kvm.begin(); i!=kvm.end(); i++) {
      if (strcasecmp("filename", i->first.c_str())==0) {
        fname = i->second; // no type conversion necessary
      } else if (strcasecmp("videoStream", i->first.c_str())==0) {
        videoStream = atoi(i->second.c_str());
      } else if (strcasecmp("numCPUs", i->first.c_str())==0) {
        nCPUs = atoi(i->second.c_str());
      } else {
        VrRecoverableThrow("Unrecognnized argument name: " << i->first);
      }
    }

    // Do all the work to open the file.
    open(fname);
  }

  void Libmpeg3IVideo::open(std::string const &filename) {
   
     TRACE;
    if (isOpen()) close();

    try {
      fname = filename;


      // Deal with file type issues. If .mpg convert to .toc
      
      // Check if this file the file extension
      string::size_type idx = fname.find_last_of ( '.' );
      VrRecoverableCheckMsg(idx != string::npos, 
        "File must have a file extension indicating type");
      
      // Get extension
      std::string ext = fname.substr(idx+1);
      
      // Make string lowercase
      std::transform(ext.begin(), ext.end(), ext.begin(), lower_case);
      
      // Check extension
      VERBOSE("Checking file extension " << ext);
      if(ext.compare("mpg")==0) {
      
        // Check the .mpg file
        VrRecoverableCheckMsg( mpeg3_check_sig((char *)fname.c_str()),
          "Could not open \"" << fname << "\".  Make sure the filename is "
          "correct, that the file is not corrupted, and that mpeg3toc or"
          "libmpeg3 can read the file.");
        
        std::string tocfname = fname.substr(0,fname.size()-3) + "toc";
        
        // Check if a .toc file exists already exists and is valid
        // If not, generate a .toc file in the same place
        if(!mpeg3_check_sig((char *)tocfname.c_str())) {
        
          VERBOSE("Generating " << tocfname << " for fast indexing");
          VrRecoverableCheckMsg(generateTOCFile(fname,tocfname),
            "Failed to generate .toc file");
        
          VERBOSE("Opening and using generated .toc file");  
         
        } else {
          VERBOSE("Using existing " << tocfname << " instead of .mpg");
        }
        
        fname = tocfname;
        
      } else if(ext.compare("toc")==0) {
        // Nothing to do, move along
      } else {
        VrRecoverableThrow("Unkown file extension: " << ext);
      }
      
      
      // Open video file
      VERBOSE("Opening video file (" << fname.c_str() << ") for reading...");
    
      int err;    

      VrRecoverableCheckMsg(
        mpeg3_check_sig((char *)fname.c_str()),
        "Could not open \"" << fname << "\".  Make sure the filename is "
        "correct, that the file is not corrupted, and that mpeg3toc or"
        "libmpeg3 can read the file.");
    
        
      pFile = mpeg3_open((char *)fname.c_str(),&err);
    
      VrRecoverableCheckMsg(pFile != NULL && err==0, 
        "Libmpeg3 could not open " << fname);

      int numStreams = mpeg3_total_vstreams(pFile);
    
      PRINTINFO("There is(are) " << numStreams << " stream(s).");
      
      VrRecoverableCheckMsg(
        videoStream < numStreams,
        "There is no video stream " << videoStream);

      frameWidth = mpeg3_video_width(pFile,videoStream);
      frameHeight = mpeg3_video_height(pFile,videoStream);
      
      PRINTINFO("Video is " << frameWidth << " x " << frameHeight);
      
      // Create RGB Image buffer (extra 12 bytes for processing)
      rgbData.resize(frameWidth*frameHeight*3+12);
      rgbRowPtrs.resize(frameHeight);
      for(int k=0;k<frameHeight;k++){rgbRowPtrs[k] = &rgbData[k*frameWidth*3];}
      
      currentFrame.resize(frameWidth*frameHeight*3);
     
      
      PRINTINFO("done.");
    } catch (...) {
      close();
      throw;
    }
  }

  void Libmpeg3IVideo::close() 
  {
    TRACE;
    if(pFile != NULL){
      mpeg3_close(pFile);
      pFile = NULL;
      frameWidth = -1;
      frameHeight = -1;
    }
    nHiddenFinalFrames = 0;  
  }
  
  

};
