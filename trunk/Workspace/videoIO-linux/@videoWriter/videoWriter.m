function vw = videoWriter(url, varargin)
% videoWriter class constructor
%   Creates a object that writes video files.  We use a plugin 
%   architecture in the backend to do the actual writing.  For example, 
%   on Windows, DirectShow will typically be used and on Linux, the 
%   ffmpeg library is often used.
%
%   vw = videoWriter(filenameEtc)
%     Opens the given FILENAMEETC file for writing using the default
%     plugin.  We use "filenameEtc" here because some plugins take
%     filenames (e.g. 'DirectShow', 'ffmpegPopen2', 'ffmpegDirect'), and
%     in the future, some may take filename masks and/or in-memory data
%     structure specifications.
%
%     On Windows, the 'DirectShow' plugin is used by default and on
%     Linux, 'ffmpegPopen2' is used by default.  
%
%   vw = videoWriter(filenameEtc, ..., 'plugin',pluginName, ...)
%   vw = videoWriter(filenameEtc,pluginName, ...)
%     Uses the manually-specified plugin instead of the default plugin.
%     Note: plugin names are case-sensitive.
%
%     Available plugins include:
%       'DirectShow': For writing AVI files on Microsoft Windows.  This
%         plugin writes OpenDML or AVI 2.0 files that can be bigger than
%         2GB, it can use VfW, DirectShow, and DMO encoders, but it
%         doesn't configure them quite as nicely as the 'VfW' plugin.
%         Type "help videoWriter_DirectShow" for details.  
%
%       'VfW': For writing AVI files on Microsoft Windows.  This plugin
%         only supports AVI 1.0 files (max size is 2GB), it can only use
%         VfW encoders, and it has good ways of configuring those
%         encoders.  Type "help videoWriter_VfW" for details.
%
%       'ffmpegPopen2': For safely writing video files on GNU/Linux using
%         the ffmpeg libraries (libavcodec, libavformat, etc.).
%         Type "help videoWriter_ffmpegPopen2" for details.
%
%       'ffmpegDirect': A slightly lower-overhead variant of the
%         'ffmpegPopen2' plugin.
%         Type "help videoWriter_ffmpegDirect" for details.
%
%   vr = videoWriter(..., param,arg,...)
%     Allows the user to pass extra configuration arguments to plugin.
%     Parameter names are case-insensitive as a convenience.  The allowed
%     parameter names are plugin-specific and are documented by each
%     plugin.
%
%     For example, to see the list of allowable parameter-value pairs
%     when using the 'DirectShow' plugin, type 
%     "help videoWriter_DirectShow" without quotes at the Matlab prompt.  
%
%  codecs = videoWriter([], 'codecs')
%  codecs = videoWriter([], 'codecs', pluginName)
%  codecs = videoWriter([], 'codecs', 'plugin',pluginName)
%    Queries the backend for a list of the valid codecs that may be used
%    with the 'codec' plugin parameter.  
% 
%
% IMPORTANT DETAILS:
%   In our current implementation, frame numbers are 0-indexed.  That
%   means that the first frame is frame 0, not frame 1.  
%
%   Once you are done using the videoWriter object, make sure you call
%   CLOSE so that any system resources allocated by the plugin may be
%   released and so that all data is actually written out.  Here's a
%   simple example of how you might use videoWriter to create a video of
%   continually adding more motion blur to an image...
%
% EXAMPLE:
%   % Construct a videoWriter object
%   vw = videoWriter('writertest.avi', ...
%                    'width',320, 'height',240, 'codec','xvid');
%   img = imread('peppers.png');
%   h = fspecial('motion',10,5);
%   for i=1:100
%     addframe(vw, img);
%     img = imfilter(img, h);
%   end
%   vw=close(vw);
%
% SEE ALSO:
%   buildVideoIO
%   videoIODir
%   videoReader
%
%   videoWriter_DirectShow
%   videoWriter_Vfw
%   videoWriter_ffmpegDirect
%   videoWriter_ffmpegPopen2
%
%   videoWriter/addframe
%   videoWriter/close
%   videoWriter/get
%
%   tests/videoWriterDemo
%
%Copyright (c) 2006 Gerald Dalley
%See "MIT.txt" in the installation directory for licensing details (especially
%when using this library on GNU/Linux). 

if isempty(url)
  % static method call
  staticMethod = varargin{1};
  [plugin,methodArgs] = pvtVideoIO_parsePlugin(...
      {varargin{2:end}}, defaultVideoIOPlugin(mfilename));

  vw = feval(pvtVideoIO_mexName(mfilename, plugin), ...
                                staticMethod, int32(-1), methodArgs{:});
else
  % constructor call
  [plugin,ctorArgs] = ...
      pvtVideoIO_parsePlugin(varargin, defaultVideoIOPlugin(mfilename));
  
  vw = struct('plugin',pvtVideoIO_mexName(mfilename, plugin), ...
              'handle',int32(-1), ...
              'w',int32(-1), 'h',int32(-1));
  vw = class(vw, mfilename);
  
  canonicalUrl = pvtVideoIO_normalizeFilename(url);
    
  strArgs = cell(size(ctorArgs));
  for i=1:numel(ctorArgs), strArgs{i} = num2str(ctorArgs{i}); end
  [vw.handle,vw.w,vw.h] = feval(vw.plugin, 'open', vw.handle, ...
                                canonicalUrl, ...
                                strArgs{:});
end
  