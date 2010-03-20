function doMultiFullReadTestOnAllLoadables(varargin)
%DOMULTIFULLREADTESTONALLLOADABLES(...)
%  For any loadable file (according to GETLOADABLEFILES), we run
%  DOMULTIFULLREADTEST on it.
%
%  Any arguments given are passed directly to the videoReader constructors.
%
%Examples:
%  doMultiFullReadTestOnAllLoadables
%  doMultiFullReadTestOnAllLoadables ffmpegPopen2  % linux & similar
%  doMultiFullReadTestOnAllLoadables ffmpegDirect  % ...if system's gcc is compatible w/ Matlab's
%  doMultiFullReadTestOnAllLoadables DirectShow    % Windows
%
%Copyright (c) 2006 Gerald Dalley
%See "MIT.txt" in the installation directory for licensing details (especially
%when using this library on GNU/Linux). 

ienter

[loadables, nonloadables, errors] = getLoadableFiles(varargin{:});
for i=1:length(loadables)
  doMultiFullReadTest(loadables{i}, varargin{:});
end
for i=1:length(nonloadables)
  if (length(nonloadables{i}) > 3)
    if (strcmpi(nonloadables{i}(end-3:end), '.avi'))
      iprintf(['"%s" (or more likely its codec) is not fully '...
        'compatible with videoReader...\t not tested (%s)'], ...
        nonloadables{i}, errors{i}); 
    end
  end
end

iexit
