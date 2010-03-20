function clearVideoIO(varargin)
%clearVideoIO
%   Removes all videoIO plugin mex functions from memory.  The mex
%   functions perform whatever cleanup is necessary and possible to release
%   system resources (file locks, threads, memory, etc.) and close any open
%   files (so that videoWriter files are not corrupted).
%
%clearVideoIO('videoReader')
%   Only clears the videoReader plugins.
%
%clearVideoIO('videoWriter')
%   Only clears the videoWriter plugins.
%
%clearVideoIO('echo')
%   Only clears the echo plugins (Linux only).
%
%Example:
%   clearVideoIO;
%
%SEE ALSO:
%   buildVideoReader
%   videoReader
%   videoread
%   videoWriter

if nargin == 0
  clearReaders = 1;
  clearWriters = 1;
  clearEcho    = 1;
else
  clearReaders = 0;
  clearWriters = 0;
  clearEcho    = 0;
  for i=1:nargin
    if strcmp(varargin{i}, 'videoReader'), clearReaders = 1; end
    if strcmp(varargin{i}, 'videoWriter'), clearWriters = 1; end
    if strcmp(varargin{i}, 'echo'),        clearEcho    = 1; end
  end
end

[m,mex] = inmem;
toClear = {};
for i=1:length(mex)
  x = mex{i};
  if ...
      (clearReaders && ~isempty(strfind(x,'videoReader_'))) || ...
      (clearWriters && ~isempty(strfind(x,'videoWriter_'))) || ...
      (clearEcho    && ~isempty(strfind(x,'echo')))
    toClear{end+1} = x; %#ok<AGROW> (isn't going to grow too much)
  end
end
if (~isempty(toClear))
  clear(toClear{:});
end
