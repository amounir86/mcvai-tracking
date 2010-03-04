function vr = videoReader(url, varargin)
% videoReader class constructor
%   Creates a object that reads video streams.  We use a plugin 
%   architecture in the backend to do the actual reading.  For example, 
%   on Windows, DirectShow will typically be used and on Linux, the 
%   ffmpeg library is often used.
%
%   vr = videoReader(filenameEtc)
%     Opens the given FILENAMEETC file for reading using the default
%     plugin.  We use "filenameEtc" here because some plugins take
%     filenames (e.g. 'DirectShow', 'ffmpegPopen2', 'ffmpegDirect',
%     'matrix'), some take filename masks (e.g. 'imread' and 'load'), and
%     others can take certain in-memory data structures (e.g. 'matrix').
%
%     On Windows, the 'DirectShow' plugin is used by default and on
%     Linux, 'ffmpegPopen2' is used by default.  
%
%   vr = videoReader(filenameEtc, ..., 'plugin',pluginName, ...)
%   vr = videoReader(filenameEtc, pluginName, ...)
%     Uses the manually-specified plugin instead of the default plugin.
%     Note: plugin names are case sensitive.  
%
%     Available plugins include: 
%
%       'DirectShow': For reading videos on Microsoft Windows.  
%         Type "help videoReader_DirectShow" for details.
%
%       'ffmpegPopen2': For safely reading videos on GNU/Linux using the 
%         ffmpeg libraries (libavcodec, libavformat, etc.).
%         Type "help videoReader_ffmpegPopen2" for details.
%
%       'ffmpegDirect': A slightly lower-overhead variant of the
%         'ffmpegPopen2' plugin.
%         Type "help videoReader_ffmpegDirect" for details.
%
%       'imread': For loading sequences of image files as if they were
%         video frames.
%         Type "help videoReader_imread" for details.
%
%       'load': For loading sequences of .mat files as if each .mat
%         file contains a single video frame
%         Type "help videoReader_load" for details.
%
%       'matrix': For wrapping a videoReader interface on an in-memory
%         video and/or loading a whole video from a single .mat file.
%         Type "help videoReader_matrix" for details.
%
%   vr = videoReader(..., param,arg,...)
%     Allows the user to pass extra configuration arguments to plugin.
%     Parameter names are case-insensitive as a convenience.  The allowed
%     parameter names are plugin-specific and are documented by each
%     plugin.
%
%     For example, to see the list of allowable parameter-value pairs
%     when using the 'DirectShow' plugin, type 
%     "help videoReader_DirectShow" without quotes at the Matlab prompt.  
%
% 
% IMPORTANT DETAILS:
%   In our current implementation, frame numbers are 0-indexed.  That
%   means that the first frame is frame 0, not frame 1.  
%
%   The current frame in a video is the index of the most
%   recently-decoded frame (as opposed to the index of the next frame to
%   be read and decoded).  
%
%   When a new videoReader object is constructed, its current frame is
%   -1, meaning that the first frame (frame 0) has not been read yet.
%   Before calling GETFRAME, one must call NEXT, SEEK, or STEP at least
%   once to cause a frame to be read from disk.  *After* calling one of
%   these methods, you may call GETFRAME as many times as you like and it
%   will return the current frame without advancing to a different
%   frame. Caveat: GETNEXT is a convenience method that calls NEXT then
%   GETFRAME. 
%
%   GET may be called at any time (even before NEXT, SEEK, or STEP).
%   It returns basic information about the video stream.  The fields
%   present are plugin- and sometimes codec-specific.  
%
%   Once you are done using the videoReader object, make sure you call
%   CLOSE so that any system resources allocated by the plugin may be
%   released.  Here's a simple example of how you might use videoReader...
%
% EXAMPLE:
%   % Construct a videoReader object using one of the videoIO test videos
%   vr = videoReader(fullfile(videoIODir, 'tests/numbers.uncompressed.avi'));
%
%   % Do some processing on the video and display the results
%   avgIntensity = [];
%   i = 1;
%   figure;
%   while (next(vr))
%     img = getframe(vr);  
%     avgIntensity(i) = mean(img(:));
%     subplot(121); imshow(img);        title('current frame');
%     subplot(122); plot(avgIntensity); title('avg. intensity vs. frame');
%     drawnow;      pause(0.1);         i = i+1;
%   end
%   vr = close(vr);
%
% SEE ALSO:
%   buildVideoIO
%   videoIODir
%   videoread
%   videoWriter
%
%   videoReader_DirectShow
%   videoReader_ffmpegDirect
%   videoReader_ffmpegPopen2
%   videoReader_imread
%   videoReader_load
%   videoReader_matrix
%
%   videoReader/close
%   videoReader/getframe
%   videoReader/get
%   videoReader/getnext
%   videoReader/next
%   videoReader/seek
%   videoReader/step
%
%Copyright (c) 2006 Gerald Dalley
%See "MIT.txt" in the installation directory for licensing details (especially
%when using this library on GNU/Linux). 

% parse the function arguments
[plugin,pluginArgs] = ...
    pvtVideoIO_parsePlugin(varargin, defaultVideoIOPlugin(mfilename));

% create the base object with the correct plugin
vr = struct('plugin',pvtVideoIO_mexName(mfilename, plugin), ...
            'handle',int32(-1));
vr = class(vr, mfilename);

if ischar(url) 
  % looks like a source filter
  
  % Pull apart the URL.  For now, we do this to reassemble the string using
  % the right filesep.  In the future, we may want to automatically choose
  % plugins based on extension or do other smarter url handling.
  canonicalUrl = pvtVideoIO_normalizeFilename(url);
  
  % Convert arguments to strings to pass to the plugin.  Doing this string
  % conversion makes the plugin implementation much easier.
  strArgs = cell(size(pluginArgs));
  for i=1:numel(pluginArgs), 
    strArgs{i} = num2str(pluginArgs{i}); 
  end
  
  % Actually instantiate the reader in the plugin.
  vr.handle = feval(vr.plugin, 'open',vr.handle, ...
    canonicalUrl, strArgs{:});
  
elseif iscell(url)
  % URL looks like a more complex call like the 'concat' plugin.  For now
  % we'll avoid string conversions and just try calling the plugin.
  
  vr.handle = feval(vr.plugin, 'open',vr.handle, ...
    url, pluginArgs{:});
   
elseif isa(url,'videoReader')
  % building a filter -- no concrete implementations exist as of revision 566.
  src = url;
  vr.handle = feval(vr.plugin, 'attach',vr.handle, src, pluginArgs{:});
  
elseif isnumeric(url) && ...                          % is a numeric matrix
      ((ndims(url)==3) || ...                         % and grayscale frames
       ((ndims(url)==4) && (size(url,3)==3))) && ...  %   or RGB frames
      strcmp(plugin,'matrix')                         % and 'matrix' plugin
  
  % The 'matrix' plugin is a special one in that it takes an in-memory
  % data structure as the VIDEO argument (as opposed to a filename or
  % similar string).  For now, the user must manually-specify the
  % 'matrix' plugin.  In the future, we might try to automatically choose
  % default plugins ('matrix' for matrices, 'matrix' for single .mat
  % files, 'load' for filepatterns with a .mat extension, 'imread' for
  % other filepatterns, and the current defaults for all other cases).
  vr.handle = feval(vr.plugin, 'open',vr.handle, url, pluginArgs{:});

else
  error('invalid first argument class: %s', class(url));
end
