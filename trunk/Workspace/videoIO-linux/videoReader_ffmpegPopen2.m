%videoReader_ffmpegPopen2
%  This is a videoReader plugin that uses libraries from the ffmpeg
%  project (libavcodec, libavformat, etc.) to decode video files on
%  GNU/Linux platforms.  
%  
%  Users should not call this function directly.  Instead they should use
%  the videoReader constructor and specify the 'ffmpegPopen2' plugin.
%
%  This 'ffmpegPopen2' plugin creates a separate server process to
%  communicate with the ffmpeg libraries.  Key features of this
%  architecture are:
%    - Works when the system's version of GCC is very different from
%      the one that MathWorks used to compile Matlab.
%    - On 64-bit systems, this allows the usage of 32-bit ffmpeg
%      libraries with 64-bit Matlab or 64-bit ffmpeg libraries with
%      32-bit Matlab.
%    - Isolates ffmpeg errors so they typically cannot crash
%      Matlab.  
%    - May allow for more flexible distribution terms for your code 
%      when it uses videoIO (ffmpeg may be compiled with either 
%      the LGPL or GPL license).
%
%  The 'ffmpegDirect' plugin is the same as 'ffmpegPopen2', but the
%  ffmpeg libraries are loaded directly by the MEX file.  'ffmpegDirect'
%  is theoretically faster and can sometimes propagate more useful error
%  messages to the user.  It is also less likely to work when there are
%  GCC differences and some error conditions produced inside the ffmpeg
%  libraries can crash Matlab.
%
%  Before using the 'ffmpegPopen2' or 'ffmpegDirect' plugins, the ffmpeg
%  libraries must be installed (see INSTALL.ffmpeg.txt) and the plugin
%  MEX functions must be built using BUILDVIDEOIO (type 
%  "help buildVideoIO" for details).
%
%  vr = videoReader(filename, 'ffmpegPopen2', ...)
%  vr = videoReader(filename, ..., 'plugin','ffmpegPopen2',...)
%    Loads the FILENAME using the ffmpeg libraries.
%
%  vr = videoReader(..., 'preciseFrames',PF, ...)
%    For forward seeks smaller or equal to this integer value, the seek
%    is guaranteed to be precise.  Precise seeking means that if you seek
%    to frame 1032, you will always go exactly to frame 1032.  Imprecise
%    seeks allow a codec to (optionally) jump to approximately the
%    requested frame without worrying about whether it goes exactly
%    there.  
%
%    For forward seeks of less than or equal to PF frames, we override
%    the codec's default behavior to ensure preciseness.  Choosing a
%    small value for 'preciseFrames' can result in much faster seeks
%    (often O(1) for imprecise versus O(n) for precise, where n is the
%    seek distance) with the risk of not going to exactly the requested
%    frame.  If the value of PF is negative, precise seeks are always
%    guaranteed, even for backward seeks.  Note that for many codecs,
%    "imprecise" seeks will actually be precise. 
%
%    Note: the current implementation of the 'ffmpegDirect' and
%    'ffmpegPopen2' plugins always performs precise seeks.  In the
%    future, we may allow imprecise seeks for a speedup.
%
%  vr = videoReader(..., 'dropBadPackets',BOOL, ...)
%    The FFMPEG libraries read data in chunks of bytes called packets.
%    We aggregate these packets and decode them.  Sometimes video files
%    are corrupted and/or produced by buggy encoders; however, useful
%    video data can often be extracted by ignoring certain types of
%    errors.  If BOOL=true, then packets that cannot be decoded properly,
%    they are dropped or ignored.  If BOOL=false, we treat any decoder
%    errors as errors and refuse to proceed.
%
%    BOOL must be a scalar number where 0 is false, and any other number
%    is true.  Strings are not allowed.  The default value is 1.
%
% SEE ALSO:
%   buildVideoIO             : how to build the plugin
%   videoReader              : overview, usage examples, other plugins
%   videoReader_ffmpegDirect : a lower-overhead version of this plugin
%
%Copyright (c) 2008 Gerald Dalley
%See "MIT.txt" in the installation directory for licensing details (especially
%when using this library on GNU/Linux). 
