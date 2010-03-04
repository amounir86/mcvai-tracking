function d = videoIODir
%d = videoIODir
%   Returns the directory where videoIO is installed.  This function is
%   useful for some of the videoIO maintenance scripts as well as
%   providing an easy way to find its regression tests and sample videos.
%
%   Note: videoIO must be in the current Matlab path.
%
%Example:
%  testFile = 'numbers.uncompressed.avi';
%  vr = videoReader(fullfile(videoIODir, 'tests', testFile));
%  info = get(vr)
%  vr = close(vr);
%
%SEE ALSO:
%  buildVideoIO
%  videoReader
%  videoWriter
%
%Copyright (c) 2007 Gerald Dalley
%See "MIT.txt" in the installation directory for licensing details
%(especially when using this library on GNU/Linux). 

% Figure out where this .m file is located.  This tells us where the plugin
% source code directory is.
[stack] = dbstack;
thisfunc = stack(1);
if (isfield(thisfunc,'file')), % Matlab 7
    d = fileparts(which(thisfunc.file));
elseif (isfield(thisfunc,'name')) % Matlab 6.5
    d = fileparts(thisfunc.name);
end