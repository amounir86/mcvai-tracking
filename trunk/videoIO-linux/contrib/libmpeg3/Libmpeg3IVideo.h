#ifndef LIBMPEG3IVIDEO_H
#define LIBMPEG3IVIDEO_H


/*
Insert copyright stuff etc...
*/

#include "debug.h"
#include "IVideo.h"
#include "libmpeg3.h"

// Normal includes
#include <string>
#include <sstream>
#include <map>
#include <vector>
#include <math.h>
#include <limits>
#include <memory>

namespace VideoIO 
{

  // AO = "Assert Open"
#undef AO
#define AO VrRecoverableCheck(isOpen())

  /** The Libmpeg3IVideo class is used to read videos using libmpeg3
  *  hosted at http://www.heroinewarrior.com/libmpeg3.php3  This class was 
  *  designed to be used by the videoIO library for Matlab
  *
  *  Copyright (C) 2008 Michael Siracusa
  *
  *  This code is released under the MIT license (see the accompanying MIT.txt
  *  file for details), unless the ffmpeg library requires a more restrictive
  *  license.  
  */
  class Libmpeg3IVideo : public IVideo
  {
  public:
    // Constructors/Destructors
    Libmpeg3IVideo();
    virtual ~Libmpeg3IVideo() { TRACE; close(); };

    // I/O Operations
    virtual void         open(KeyValueMap &kvm);
    virtual void         close();
    virtual bool         next();
    virtual bool         step(int numFrames=1);
    virtual bool         seek(int toFrame);
    virtual int          currFrameNum()   const {AO;return currentFrameNumber;}
    virtual Frame const &currFrame()      const {AO;return currentFrame;} 

    // video stats
    virtual std::string filename()             const { AO; return fname; }  
    virtual int         width()                const { AO; return frameWidth; }
    virtual int         height()               const { AO; return frameHeight; }
    virtual int         depth()                const { AO; return 3; } 
    virtual double      fps()                  const { AO; return mpeg3_frame_rate(pFile,videoStream);}
    virtual int         numFrames()            const { AO; return mpeg3_video_frames(pFile,videoStream);}
    virtual FourCC      fourcc()               const { AO; stringToFourCC("tocf"); }
    virtual int         numHiddenFinalFrames() const { AO; return nHiddenFinalFrames; }

    virtual ExtraParamsAndStats extraParamsAndStats() const {
      // TODO: it might be interesting to extract a lot of extra metadata 
      // from the pFormatCtx, pCodecCtx, etc.
      return ExtraParamsAndStats();
    }

  private:
    void        open(std::string const &fname);
    inline bool isOpen() const { return (pFile != NULL); }    
    bool getNextFrame();
    bool stepLowLevel(int numFrames);

    std::string                  fname;
    
    int                          currentFrameNumber;
    int                          videoStream;
  
    mpeg3_t                      *pFile;
    int                          nCPUs;
  
    int                          frameWidth;
    int                          frameHeight;
  
    // Some buffers for decoding the frame
    std::vector<unsigned char>   rgbData;
    std::vector<unsigned char *> rgbRowPtrs;
    
    // Frame to be return in matlab format
    Frame                        currentFrame;       

    int                          nHiddenFinalFrames; 

  };

#undef AO

}; /* namespace VideoIO */

#endif 
