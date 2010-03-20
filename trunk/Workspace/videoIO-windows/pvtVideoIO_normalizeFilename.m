function canonical = pvtVideoIO_normalizeFilename(raw)
%canonical = pvtVideoIO_normalizeFilename(raw)
%  PRIVATE function for the VideoIO Library.  Typical users should not use
%  this function.  This function is shared by multiple components in a way
%  that it cannot sit in a private/ directory, hence the verbose name.
%
%  Takes a raw filename and produces a canonical filename.  
%
%  On Windows, the canonical one will have all forward slashes replaced
%  with backslashes.
%
%  On non-Windows platforms, the canonical one will have all backslashes
%  replaced by forward ones.  Pathnames starting with a '~' character
%  will expand it according to standard user directory rules.
%
%  EXAMPLE:
%    > pvtVideoIO_normalizeFilename('~/foo.avi')
%    '/home/myuser/foo.avi'
%
%Copyright (c) 2008 Gerald Dalley
%See "MIT.txt" in the installation directory for licensing details (especially
%when using this library on GNU/Linux). 

[pathstr, name, ext, versn] = fileparts(raw);
if ispc
  canonical = fullfile(strrep(pathstr,'/','\'), [name, ext, versn]);
else
  canonical = fullfile(strrep(pathstr,'\','/'), [name, ext, versn]);
  % user directory resolution
  if canonical(1) == '~'
    splitPt = find(canonical, filesep);
    if isempty(splitPt)
      tildePortion = canonical;
      remainder    = '';
    else
      tildePortion = canonical(1:splitPt(1));
      remainder    = canonical(splitPt(1)+2:end);
    end
    fprintf('tp: "%s", r: "%s"\n', tildePortion, remainder);
    currDir = pwd;
    cd(tildePortion);
    baseDir = pwd;
    cd(currDir);
    canonical = fullfile(baseDir, remainder);
  end
end
 