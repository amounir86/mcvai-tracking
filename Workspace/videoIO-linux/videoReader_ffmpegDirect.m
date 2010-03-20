%videoReader_ffmpegDirect
%  This is a videoReader plugin that uses libraries from the ffmpeg
%  project (libavcodec, libavformat, etc.) to decode video files on
%  GNU/Linux platforms.  
%  
%  Users should not call this function directly.  Instead they should use
%  the videoReader constructor and specify the 'ffmpegDirect' plugin.
%
%  It is similar to videoReader_ffmpegPopen2, except the ffmpeg libraries
%  are linked directly to the MEX function.  This results in lower
%  theoretical overhead and some more explanatory error messages, but
%  greater exposure to crashes in the ffmpeg libraries.  
%
%  For more details, type "help videoReader_ffmpegPopen2" at the Matlab
%  prompt. 
%
% SEE ALSO:
%   buildVideoIO             : how to build the plugin
%   videoReader              : overview, usage examples, other plugins
%   videoReader_ffmpegPopen2 : a safe flexible version of this plugin
%
%Copyright (c) 2008 Gerald Dalley
%See "MIT.txt" in the installation directory for licensing details (especially
%when using this library on GNU/Linux). 
