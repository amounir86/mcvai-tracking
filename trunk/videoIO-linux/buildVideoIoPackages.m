%buildVideoIoPackages
%  This script is used to generate downloadable packages for sourceforge 
%  and Matlab Central.  Most users will have no need for this script.
%
%  Assumptions:
%   * svn and grep are in Matlab''s system path
%   * Windows Matlab 2006a or later is being used
%   * If 32-bit Matlab is being used, the 64-bit mex functions have
%     already been built, or vice-versa.
%
%  Example:
%    buildVideoIoPackages

%-------------------------------------------------------------------------

% When enabled, does not create a lean-and-mean archives with no test files
% (to reduce the download size).
suppressNoTests = 1; 
% When enabled, only .zip outputs are created for linux-friendly
% distributions.
suppressGz = 1;

origDir = pwd;
cd(videoIODir);

%-------------------------------------------------------------------------
% Helpers
cellcat       = @(x,y)         {x{:},y{:}};

strrev        = @(x)           x(end:-1:1);

cellmap       = @(m,l)   cellfun(m,l, 'UniformOutput',0);
cellfilt      = @(filt,l)      {l{cellfun(filt, l)}}; % keeps true filt responses
excludeBegin  = @(beg,l) cellfilt(@(f) isempty(strmatch(beg, f)), l);
includeBegin  = @(beg,l) cellfilt(@(f) ~isempty(strmatch(beg, f)), l);
excludeMid    = @(mid,l) cellfilt(@(f) isempty(strfind(f,mid)), l);
excludeEnd    = @(ext,l) cellfilt(@(f) isempty(strmatch(strrev(ext), strrev(f))), l);
includeEnd    = @(ext,l) cellfilt(@(f) ~isempty(strmatch(strrev(ext), strrev(f))), l);

multiExclude  = @(excl,pats,l) cellfilt(@(f) isempty(cellfilt(@(p) isempty(excl(p,{f})), pats)), l);
multiInclude  = @(excl,pats,l) cellfilt(@(f) ~isempty(cellfilt(@(p) ~isempty(excl(p,{f})), pats)), l);
excludeBegins = @(begs,l) multiExclude(excludeBegin, begs, l);
includeBegins = @(begs,l) multiInclude(includeBegin, begs, l);
excludeMids   = @(mids,l) multiExclude(excludeMid,   mids, l);
excludeEnds   = @(exts,l) multiExclude(excludeEnd,   exts, l);
includeEnds   = @(exts,l) multiInclude(includeEnd,   exts, l);

%-------------------------------------------------------------------------
% Clean out old files
!rm -rf *.zip *.tar.gz

%-------------------------------------------------------------------------
% Get meta data
[status, revisionText] = system('svn info | grep Revision');
if status ~= 0
  error(['Error getting the current revision number.  '...
    'Are svn and grep in your system path?']);
end
revision = sscanf(revisionText, 'Revision: %d', 1);

[status,completeFileSet] = system('svn ls -R');
if status ~= 0
  error(['Error querying subversion for a recursive file list.   '...
    'is svn in your system path?']);
end
completeFileSet = split(sprintf('\n'), completeFileSet);
completeFileSet = cellfilt(@(x) ~isempty(x), completeFileSet);
completeFileSet = unique(...
  excludeEnds({'\', '/'}, ...
  completeFileSet));

nonTestFileSet = excludeBegin('tests/', completeFileSet); 

basePackageName = sprintf('videoIO-r%d', revision);

%-------------------------------------------------------------------------
% Build Contents.m
F = fopen('ChangeLog.txt');
version = 'UNKNOWN';
while 1
  line = fgetl(F);
  tokens = regexp(line, 'videoIO\s([0-9\.]+)', 'tokens');
  if ~isempty(tokens)
    version = tokens{1}{1};
    break;
  end
end
fclose(F);

nowstr  = datestr(now,1);

classes = unique(...
  cellmap(@(f) f(2:find(f=='/', 1)-1),...
  includeBegins({'@'},...
  completeFileSet)));

mfiles = unique(...
  cellmap(@(f) f(1:end-2),...                 % strip extension
  excludeEnds({'Contents.m'},...              % don't index Contents.m
  excludeMids({'/', '\'}, ...                 % none from subdirs
  includeEnds({'.m'}, completeFileSet)))));   % mfiles only

plugins = unique(...
  includeBegins({'videoReader_', 'videoWriter_'},...
  mfiles));

public = unique(...
  excludeBegins({'pvt'},...
  excludeMids({'_'},...
  mfiles)));

build = unique(...
  includeBegins({'build'},...
  public));

aux = unique(...
  excludeBegins({'build'},...
  public));

F = fopen('Contents.m', 'w');
fprintf(F,'%% videoIO Toolbox\n');
fprintf(F,'%% Version %s (revision %d) %s\n', version, revision, nowstr);
fprintf(F,'%% \n');

fprintf(F,'%% Granting easy, flexible, and efficient read/write access to\n');
fprintf(F,'%% video files in Matlab on Windows and GNU/Linux platforms. \n');
fprintf(F,'%% \n');
fprintf(F,'%% See README.txt for a general description of the library \n');
fprintf(F,'%% and tips on getting started.\n');
fprintf(F,'%% \n');

fprintf(F,'%% Classes.\n');
for i=1:length(classes)
  fprintf(F,'%%   %s - \n', classes{i}); 
end
fprintf(F,'%% \n');

fprintf(F,'%% Plugins (some may not be available for your system).\n');
for i=1:length(plugins)
  fprintf(F,'%%   %s - \n', plugins{i}); 
end
fprintf(F,'%% \n');

fprintf(F,'%% Build functions (may not be present).\n');
for i=1:length(build)
  fprintf(F,'%%   %s - \n', build{i}); 
end
fprintf(F,'%% \n');

fprintf(F,'%% Auxiliary functions.\n');
for i=1:length(aux)
  fprintf(F,'%%   %s - \n', aux{i}); 
end
fprintf(F,'%% \n');

fprintf(F,'\n');
fprintf(F,'%% Copyright (C) 2008, Gerald Dalley\n');
F = fclose(F);

%-------------------------------------------------------------------------
% Build the full source package 
if ~suppressGz
  tar([basePackageName '-source.tar'], completeFileSet);
  gzip([basePackageName '-source.tar']);
  delete([basePackageName '-source.tar']);
end
zip([basePackageName '-source.zip'], completeFileSet);

if ~suppressNoTests
  if ~suppressGz
    tar([basePackageName '-source-notests.tar'], nonTestFileSet);
    gzip([basePackageName '-source-notests.tar']);
    delete([basePackageName '-source-notests.tar']);
  end
  zip([basePackageName '-source-notests.zip'], nonTestFileSet);
end

%-------------------------------------------------------------------------
% Build Windows binaries
buildVideoIO;
mexw32 = dir('*.mexw32'); mexw32 = {mexw32.name};
mexw64 = dir('*.mexw64'); mexw64 = {mexw64.name};
if isempty(mexw32) 
  error('You must build the 32-bit Windows binaries before proceeding.');
end
if isempty(mexw64) 
  error('You must build the 64-bit Windows binaries before proceeding.');
end

win32binFileSet = ...
  unique(...
  cellcat(mexw32, ...
  cellcat(mexw64,...
  excludeMids({'linux', 'ffmpeg', 'Ffmpeg'},...
  excludeBegins({'echo'}, ...
  excludeEnds({'Echo.m'}, ...
  excludeBegins({'build'}, ...
  excludeEnds({'.cpp', '.c', '.h', '.hpp'}, ...
  excludeEnds({'makefile','.pl','.sh'}, completeFileSet)))))))));

win32binNoTestFileSet = excludeBegin('tests/', win32binFileSet);

zip([basePackageName '-windowsBin.zip'], win32binFileSet);
if ~suppressNoTests
  zip([basePackageName '-windowsBin-notests.zip'], win32binNoTestFileSet);
end

cd(origDir);
