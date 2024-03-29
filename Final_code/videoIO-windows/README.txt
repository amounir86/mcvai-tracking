===============================================================================

  videoIO -- granting easy, flexible, and efficient read/write access  
                 to video files in Matlab on Windows and GNU/Linux platforms.

    by Gerald Dalley
  
===============================================================================

Contents
--------
1) Legalese (MIT license on Windows, GPL on Linux)
2) Quick Description
3) Motivation
4) Similar projects
5) Acknowledgments

Legalese
--------
This software is released under the MIT license (see MIT.txt) whenever 
possible.  If linked against the GPL version of ffmpeg, this software
inherits the GPL license as well (see MIT.txt and GPL.txt).

Quick Description
-----------------
videoIO is a library designed to allow easy and efficient reading and
writing of video files in Matlab on Windows and Linux.  It is designed to 
enhance and/or complement other options that were available at the time it 
was originally written (summer 2006).

To install the library on Microsoft Windows, see INSTALL.dshow.html.
To install the library on GNU/Linux and similar operating systems, see
INSTALL.ffmpeg.txt.  

If you only wish to read videos stored as individual frames (in a format 
readable by IMREAD or in .mat files), you need only add the directory
containing this README.txt file to your Matlab path.  Note: if you do 
this, you will not be able to use the videoIO toolbox to write videos 
of any type or read true video files (e.g. .mpg, .avi, etc.).

As a quick usage example, here's how to animate one of the test movies:
  
  fname = fullfile(videoIODir, 'tests', 'numbers.uncompressed.avi');
  vr = videoReader(fname);   % create read object
  while (next(vr))           % read next frame
    img = getframe(vr);      % extract frame
    imshow(img);
    pause(0.01);
  end
  vr = close(vr);            % release resources
  
For more detailed usage examples and instructions, type the following in 
Matlab:  
  help buildVideoIO
  help videoReader
  help videoWriter
  help videoread
and see
  tests/testAll.m          % Master test script (see all scripts it calls
                           %   for various usage examples)
  tests/videoWriterDemo.m  % Example showing how to create videos

Motivation
----------
Matlab's Image Processing Toolbox ships with the AVIREAD function which 
provides limited video reading functionality.  Specifically, as of version 
2006a, AVIREAD has the following key limitations:
  1) Inability to decode many stream types on Windows (e.g. try using AVIREAD 
     on the supplied tests/numbers.3ivx.avi file)
  2) Only uncompressed AVI files are supported on non-Windows platforms, and
     uncompressed AVI files are poorly supported on Windows.
  3) Only AVI files are supported (not WMV, MP4, MPG, etc.)
  4) All frames are read at once, meaning that if the user doesn't have enough
     RAM to hold the entire file's uncompressed contents in memory, it must be
     it must be read in chunks, resulting in a O(n^2) performance cost (where 
     n is the number of chunks).

The Matlab Image Processing Toolbox also ships with AVIFILE, a function for
writing videos.  As of version 2006a, AVIFILE has the following key 
limitations that are overcome by this library:
  1) Very limited codec support on Windows: only Indeo3, Indeo5, Cinepak,
     MSVC, RLE, and no compression are available.  All of these codecs are
     quite dated and provide poor compression relative to newer codecs.
  2) No codec support on Unix/Linux platforms.  Only uncompressed videos
     may be created.
AVIFILE only writes to AVI files, and depending on the operating system,
videoIO shares this limitation.  

Mathworks has also created some Simulink filters in the Video and Image 
Processing Blockset.  These filters require purchasing extra packages and
the usage of the Simulink framework.  They also seem to share the same codec
restrictions as AVIREAD and AVIFILE.

Starting with Matlab 2007b, Mathworks has created an MMREADER object that is
very similar in spirit to our videoReader.  Like our package, it uses
DirectShow.  As of 2008a, they added Macintosh support via QuickTime.  We 
hope that in the future, MMREADER will make videoIO obsolete.  In the mean
time, the videoIO package has the following advantages over MMREADER:
  1) videoIO works on Linux and Windows (but is untested on Macintosh).
  2) videoIO works on Matlab 6.5 and later (instead of requiring 2007a or 
     2008b).
  3) videoIO avoids seek operations more aggressively than MMREADER
     (e.g. on 2007a, read(mm,100);read(mm,101) induces a seek to read frame 
      101.  By default, using a videoIO object to seek(vr,100);seek(vr,101) 
     will stream the second frame).  This is important because seeks are
     slow and because many decoders yield inconsistent results when 
     seeking.
  4) There is no MMWRITER analagous to videoIO's videoWriter (we already
     made the comparison to AVIFILE above).
  5) videoIO allows much finer control of the video processing pipeline 
     when needed.

videoIO either overcomes or provides a mechanism to overcome all of these
limitations.  When reading, it is designed to stream in frames one at a time 
so that large amounts of memory need not be allocated for the video.  It 
currently supports virtually any DRM-free video file that can be played in 
Windows Media Player (on Windows) or ffmpeg (on Linux).  

The library has been designed so that it is (relatively) easy to add support
for other video files.  For example, if an ambitious person wanted to add 
support for QuickTime files, that could be done in a way that is largely 
transparent to the end user.

Similar Projects
----------------
aviread, avifile, mmreader (Mathworks)
  In the Motivation section above, we described the relationship between 
  videoIO and Matlab's aviread, avifile, and mmreader.

mplayerMex (http://cs-people.bu.edu/tvashwin/mplayerMex/)
  The idea is very similar to ours, in principle.  mplayerMex attempts to tie 
  into the powerful MPlayer application instead of using ffmpeg (like we do). 
  Unfortunately, mplayerMex is not fully implemented (e.g. closing files is 
  not supported as of July 2006).  We also had difficulty getting mplayerMex 
  to work with the current version of MPlayer as mplayerMex is not being
  actively maintained.  MPlayer is really an application and it takes a
  fair amount of work to modify the source code to turn it into a linkable
  library.  mplayerMex not support writing new video files.
  
dxAvi (http://cs-people.bu.edu/tvashwin/dx_avi/)
  Written by the same person that wrote mplayerMex, this mex function works on
  Windows.  This implementation uses the one-shot mode of DirectShow and 
  performs an explicit seek for every frame that's read.  In the past, we've
  noticed performance and/or round-off problems when using the one-shot mode, 
  but it would be instructive to do a head-to-head experiment again using many 
  different codecs, then switch to their approach if it is better.  By using 
  the one-shot mode, dxAvi avoids many of the threading headaches we 
  encounter, but potentially exposes itself to more imprecise seeking issues.
  Note that starting with DirectX 8.1, Microsoft recommends not using the 
  oneshot mode.  dxAvi does not support writing new video files.
  
NetAvi (http://cs-people.bu.edu/tvashwin/netAvi/)
  Also written by the author of mplayerMex and dxAvi, a server process is run
  on 32-bit Windows for decoding videos.  Clients read decoded frames over a 
  socket connection.  Installation appears to be very easy.  The networked 
  approach requires that all video files be accessible from the server box and
  creates significant additional network traffic as it transmits uncompressed 
  frames.  NetAvi does not support writing new video files.

Acknowledgments
---------------
We would like to thank Josh Midgal (jmigdal@mit.edu) for figuring out how to 
get DirectShow to behave in a pull-mode instead of a push-mode.  The general 
design and especially the core interaction model between DirectShowVideo::seek 
and DirectShowVideo::SampleCB is based off his work.

We would also like to thank all those who have donated time to the ffmpeg, 
xvid, and x264 projects.

A final thanks goes to all those who have given feedback on this library
and thus helped it be better for everyone.
