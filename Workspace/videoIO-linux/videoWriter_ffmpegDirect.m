%videoReader_ffmpegDirect
%  This is a videoWriter pluging that uses libraries from the ffmpeg
%  project (libavcodec, libavformat, etc.) to encode video files on
%  GNU/Linux platforms.  
%  
%  Users should not call this function directly.  Instead they should use
%  the videoReader constructor and specify the 'ffmpegDirect' plugin.
%
%  It is similar to videoWriter_ffmpegPopen2, except the ffmpeg libraries
%  are linked directly to the MEX function.  This results in lower
%  theoretical overhead and some more explanatory error messages, but
%  greater exposure to crashes in the ffmpeg libraries.  
%
%  For more details on using this plugin, type
%      help videoWriter_ffmpegPopen2 
%  at the Matlab prompt.  For more details on the difference between the
%  'ffmpegPopen2' and 'ffmpegDirect' plugins, type
%      help videoReader_ffmpegPopen2
%  at the Matlab prompt.
%
% SEE ALSO:
%   buildVideoIO             : how to build the plugin
%   videoWriter              : overview, usage examples, other plugins
%   videoWriter_ffmpegPopen2 : a safe flexible version of this plugin
%
%Copyright (c) 2008 Gerald Dalley
%See "MIT.txt" in the installation directory for licensing details (especially
%when using this library on GNU/Linux). 
