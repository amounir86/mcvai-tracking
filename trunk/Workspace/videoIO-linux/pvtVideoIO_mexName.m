function n = pvtVideoIO_mexName(ctor, plugin)
%n = pvtVideoIO_mexName(ctor, plugin)
%  PRIVATE function for the VideoIO Library.  Typical users should not use
%  this function.  This function is shared by multiple components in a way
%  that it cannot sit in a private/ directory, hence the verbose name.
%
%  Takes the name of a constructor ('videoReader' or 'videoWriter'), and a
%  user-style plugin name ('DirectShow', 'ffmpegPopen2', etc.) and returns
%  the function name for its implementation.  It also searches for that
%  function in the current path and generates a user-friendly message if
%  the function does not exist.
%
%  EXAMPLE:
%    > pvtVideoIO_mexName('videoReader', 'ffmpegPopen2')
%    'videoReader_ffmpegPopen2.mexglx'
%
%Copyright (c) 2008 Gerald Dalley
%See "MIT.txt" in the installation directory for licensing details (especially
%when using this library on GNU/Linux). 

n = [ctor '_' plugin];

if exist([n '.' mexext], 'file')
  % looks like a mex implementation that has been successfully compiled

elseif isMFileWithCode(which(n))
  % looks like an M-file implementation

else
  exts = findAllFuncExts(n);
  if isempty(exts)
    extsMsg = [...
      'The plugin (a) has not been compiled for this platform (with '...
      'extension ' mexext '), (b) it is misspelled, or (c) it is not '...
      'supported on this platform.'];
  else
    extsMsg = sprintf([...
      'The plugin has not been compiled for this platform (with '...
      'extension %s), but it has been for others (%s exists on your system '...
      'with the following extensions:%s).  '],...
      mexext, n, sprintf(' %s', exts{:}));
  end
  
  errMsg = sprintf([...
    'Cannot find the %s plugin.  '...
    '\n\n'...
    '%sType ''help %s'' for a list of official plugins and on which '...
    'platforms they are supported.'...
    '\n\n'...
    'If you have spelled the plugin name correctly, try running '...
    '"buildVideoIO" (without quotes) at the Matlab prompt.  '...
    '\n\n'...
    'If you have further difficulties, follow the instructions in '...
    'INSTALL.dshow.html on Windows or INSTALL.ffmpeg.txt on Linux.'], ...
    n, extsMsg, ctor);
  
  error(wordWrap(errMsg, 80));
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function v = findAllFuncExts(m)
%v = findAllFuncExts(m)
%  Takes a Matlab function M and finds all versions of it in the current
%  path.  Returns the extensions for each of these.
%
%  Example: say FOO.M, FOO.MEXA64, and FOO.MEXGLX exist in the current
%  Matlab path.  Then FINDALLFUNCEXTS will return 'm', 'mexa64', and 'mexglx'.
%
%  Motivation: when making multi-platform mex functions, it can be handy to
%  find versions for other platforms to help people know when they need to
%  recompile.

if isMFileWithCode(which([m '.m']))
  v = {[m '.m']}; 
else
  v = {};
end

try
  exts = mexext('all'); exts = {exts.ext};
catch
  % mexext('all') was introduced in Matlab R14sp3 (at least on linux).
  % Use all known extensions.
  exts = {'mex', ... % really old versions 
          'mexsol','mexhpux','mexglx','mexi64','mexmac','dll',...% R14sp2
          'mexhp7','mexa64','mexs64','mexw32','mexw64','mexmaci'...%R14sp3+ 
          };
end

for ee=exts
  e = ee{1};
  if exist([m '.' e], 'file')
    v{end+1} = e; %#ok<AGROW>
  end
end 

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function w = wordWrap(s,c)
% w = wordWrap(s,c)
%  Wordwraps string s at column c

% Note: we don't use the 'last' form of FIND because it's not available
% in some older versions of Matlab.

newline = sprintf('\n');
w = '';
while ~isempty(s) % until we have no more string left
  if numel(s) <= c % last little string
    w = [w s newline]; %#ok<AGROW> -- these strings aren't *that* big
    s = '';
  else 
    nlIdx = find(s(1:c+1)==newline);
    if isempty(nlIdx) 
      % no existing newlines, so we have to make one
      wsIdx = find(isspace(s(1:c+1)));
      if isempty(wsIdx)
        % can't find a good breaking point--just clip mid-word
        w = [w s(1:c)]; %#ok<AGROW>
        s = s(c+1:end);
      else
        % Found whitespace: break there
        w = [w s(1:wsIdx(end)-1) newline]; %#ok<AGROW>
        s = s(wsIdx(end)+1:end);
      end
    else     
      % Use an existing newline
      w = [w s(1:nlIdx(end))]; %#ok<AGROW>
      s = s(nlIdx(end)+1:end);
    end
  end
end
  
if ~isempty(w)
  w = w(1:end-1);
end


