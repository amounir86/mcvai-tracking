function pluginName = defaultVideoIOPlugin(ctor)
%pluginName = defaultVideoIOPlugin(ctor)
%  Returns the name of the default videoIO (videoReader/videoWriter) plugin.  
%  The videoReader and videoWriter constructors will use the returned plugin 
%  if none is specified.  CTOR should be 'videoReader' or 'videoWriter'.
%
% Example:
%   defaultVideoIOPlugin('videoReader') % returns 'DirectShow' on Windows
%
% SEE ALSO:
%   buildVideoIO
%   videoReader
%   videoWriter
%
%Copyright (c) 2007 Gerald Dalley
%See "MIT.txt" in the installation directory for licensing details (especially
%when using this library on GNU/Linux). 

if nargin<1
  ctor = 'videoReader';
end

if ispc
  pluginName = 'DirectShow';
  
else
  pluginName = 'ffmpegPopen2';
  
  % Try to be nice and auto-detect if we should use ffmpegDirect instead
  try
    pvtVideoIO_mexName(ctor,pluginName);
    % if the above line succeeded, then ffmpegPopen2 exists.
  catch
    % ffmpegPopen2 doesn't exist
    try
      pvtVideoIO_mexName(ctor,'ffmpegDirect');
      % if the above line succeeded, ffmpegDirect exists.  Default to it.
      pluginName = 'ffmpegDirect';
    catch
      % Neither ffmpegPopen2 nor ffmpegDirect exist.  Use the standard
      % default.  The user probably needs to run buildVideoIO or run make.
    end
  end
end    
