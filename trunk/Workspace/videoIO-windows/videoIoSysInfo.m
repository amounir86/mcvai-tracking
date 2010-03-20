function out = videoIoSysInfo
%videoIoSysInfo
%  Gathers information about the currently-running version of Matlab, your
%  operating system, and 3rd-party libraries used by the videoIO toolbox.
%  A report is generated which is sent to the screen and also saved to
%  'videoIoSysInfo.txt' in the current directory.  
%
%  The primary purpose of this function is to gather information for
%  debugging system configurations and sending this information to the
%  videoIO author.  If you are having difficulty with videoIO, have already
%  read README.txt and the appropriate INSTALL.*.txt file, then please run
%  this function and send the resulting 'videoIoSysInfo.txt' to the author.
%
%info=videoIoSysInfo
%  Instead of printing the information to the screen and saving it to a
%  file, the configuration information is returned as a struct.
%
%Copyright (c) 2008 Gerald Dalley
%See "MIT.txt" in the installation directory for licensing details (especially
%when using this library on GNU/Linux). 

info = struct;

% Matlab info
v = ver('Matlab');
info.matlabVersion = v.Version;
info.matlabRelease = v.Release;
info.matlabDate    = v.Date;

info.java = char(strread(version('-java'),'%s',1,'delimiter','\n'));

% Matlab platform
info.mexext   = mexext;
[info.computer, info.maxsize, info.endian] = computer;
try
  info.arch = computer('arch');
catch %#ok<CTCH>
  info.arch = 'unknown';
end

% get OS information (uses undocumented matlab features found in VER).
if ispc
  info.os      = system_dependent('getos');
  info.osver   = system_dependent('getwinsys');
  info.osarch  = getenv('PROCESSOR_ARCHITECTURE');
elseif ismac
  [fail, info.os] = unix('sw_vers');
  if fail, info.os = 'Unknown Macintosh'; end
else
  info.os = system_dependent('getos');
end

% Check status of 3rd-party lib installation described in INSTALL.*.txt.
% This code is system-specific.
if ispc
  info.include = getenv('INCLUDE');
  info.lib32   = getenv('LIB32');
  info.lib64   = getenv('LIB64');
  if strcmpi(info.mexext, 'mex') || ...
      ~isempty(strfind(info.mexext, '32')) || ...
      strcmpi(info.mexext, 'dll') % handle older versions
    info.allLibDirs = splitSemiColonPaths(info.lib32);
  else
    info.allLibDirs = splitSemiColonPaths(info.lib64);
  end
else
  % We may want to move this block into the makefile at some point
  info.cxxflags              = getenv('CXXFLAGS');
  [status,info.ffmpegCflags] = system(sprintf(...
      'cd %s; ./ffmpeg-config-internal.pl --cflags', videoIODir));
  [status,info.ffmpegLibs]   = system(sprintf(...
      'cd %s; ./ffmpeg-config-internal.pl --libs',   videoIODir));
  [status,info.gccLibDirs]   = system(...
      'gcc -print-search-dirs | grep libraries');
  if status == 0
    info.gccLibDirs = split(':',...
                            info.gccLibDirs(length('libraries: =')+1:end))';
  end
  
  d1 = getLinkPathsFromGccArgs(info.cxxflags);
  d2 = getLinkPathsFromGccArgs(info.ffmpegLibs);
  d3 = info.gccLibDirs;
  info.allLibDirs = {d1{:},d2{:},d3{:}};
  mask = true(1,length(info.allLibDirs));
  for i=1:length(mask)
    if isempty(info.allLibDirs{i})
      mask(i)=0;
    end
  end
  info.allLibDirs = { info.allLibDirs{mask} }';
  
  info.libsArch = getLibArchs(info.ffmpegLibs, info.allLibDirs);
end

% find all plugins
info.vrplugins = findPlugins('videoReader');
info.vwplugins = findPlugins('videoWriter');

% try to find the version info
try
  parts = split('\/', videoIODir);
  v = ver(parts{end});
  fns = fieldnames(v);
  for i=1:length(fns)    
    info.(['version_' lower(fns{i})]) = v.(fns{i});
  end
catch  %#ok<CTCH>
  info.version = 'could not retrieve';
end

% return result or print
if nargout==0
  printStruct(info, 1);
  
  fname = 'videoIoSysInfo.txt';
  F = fopen(fname, 'w');
  printStruct(info, F);
  fclose(F);
  fprintf('System information saved to %s.\n', fname);
else
  out = info;
end  

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function printStruct(info, F)
%printStruct(info, F)
%  prints a structure to the given file handle.  The structure must have a
%  single element and its fields may be strings, 1D or 2D numeric matrices,
%  and/or 1D or 2D cell arrays containing strings.
%
%  This implementation is specialized for use with videoIoSysInfo.  A more
%  general version would be much more complicated.  Look for 'serialize.m'
%  and 'gen_obj_display.m' at the MatlabCentral website for some approaches
%  taken by other authors.

for fn = sort(fieldnames(info))'
  fprintf(F, '%s:\n', fn{1});
  field = info.(fn{1});
  if isempty(field)
    % do nothing
  elseif ischar(field)
    fprintf(F, '  %s\n', field);
  elseif isnumeric(field)
    fprintf(F, '  %s\n', mat2str(field));
  elseif iscell(field)
    if isempty(field)
      % do nothing
    else
      padwidths = max(cellfun(@length, field), [], 1);
      for r=1:size(field,1)
        for c=1:size(field,2)
          field{r,c} = pad(sprintf('%s',field{r,c}), padwidths(c)+1);
        end
      end
      field = cell2mat(field);
      field = [...
        char(zeros(size(field,1),2))+' ', ...
        field, ...
        char(zeros(size(field,1),1))+sprintf('\n')]'; %#ok<AGROW>
      field = field(:)';
      field = field(1:end-1);
      fprintf(F, '%s\n', field);
    end
  else
    error('unsupported data type');
  end
  fprintf(F, '\n');
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function s = pad(in,w)
%s = pad(in,w)
%  Pads an input string with trailing spaces so it is at least W characters
%  wide.
s = [in char(zeros(1,w-numel(in)))+' '];

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function plugins = findPlugins(ctor)
%plugins = findPlugins(ctor)
%   Finds all videoIO plugin implementations for a given object class and
%   attempts to find the binary architecture for them.

plugins = cell(0,2);
allpaths = cat(2,split(pathsep, path), unique({videoIODir, pwd}));
for i=1:length(allpaths)
  p = allpaths{i};
  myplugins = dir(fullfile(p,[ctor '_*']));
  for j=1:length(myplugins)
    plugin = myplugins(j).name;
    % skip obvious backup files
    if ~ismember(plugin(end), '#~') && ~strcmpi(plugin(end-3:end), '.bak')
      pathname = fullfile(p, plugin);
      arch = getBinaryArch(pathname);
      plugins{end+1,1} = pathname; %#ok<AGROW>
      plugins{end,2}   = arch;
    end
  end
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function paths = getLinkPathsFromGccArgs(gccargs)
%paths = getLinkPathsFromGccArgs(gccargs)
%  Extract paths from -L arguments in a gcc-style parameter string

args = split(' ', gccargs);
paths = {};
for i=1:length(args)
  if strmatch('-L', args{i})
    newpaths = split(':', args{i}(3:end));
    paths = {paths{:} newpaths{:}};
  end
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function libsArch = getLibArchs(ffmpegLibs, allLibDirs)
%libsArch = getLibArchs(ffmpegLibs, allLibDirs)
%  Takes a set of gcc-style linker arguments (ffmpegLibs) and a list of
%  library search directories and returns a 2D cell array containing the
%  library files actually found and their architecture.

args = split(' ', ffmpegLibs);
libs = {};
for i=1:length(args)
  if strmatch('-l', args{i})
    newlibs = split(':', args{i}(3:end));
    libs = {libs{:} newlibs{:}};
  end
end

libsArch = cell(length(libs)*length(allLibDirs)*2,2);
row = 1;
for i=1:length(libs)
  l = libs{i};
  for j=1:length(allLibDirs)
    d = allLibDirs{j};
    for ext = {'so', 'a'};
      libname = ['lib' l '.' ext{1}];
      p = fullfile(d,libname);
      if exist(p,'file')
        arch = getBinaryArch(p);
        if ~isempty(arch)
          libsArch{row,1} = libname;%#ok<AGROW>
          libsArch{row,2} = arch;
        else
          libsArch{row,1} = libname; %#ok<AGROW>
        end
        row = row+1;
      end
    end
  end
end
libsArch = reshape({libsArch{1:row-1,:}}, [row-1,2]);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function arch = getBinaryArch(path)
%arch = getBinaryArch(path)
%  Given a full pathname to an executable or shared library (e.g. a mex
%  function), tries to find the binary architecture of that file.
%
%  On Windows, this will silently fail (i.e. return an empty string) if
%  cygwin is not installed or not in the current path.  As of 11 Jan 2008,
%  it will also fail for 64-bit mex extensions.

arch = '';
if ~isempty(dir(path))
  if strcmpi(path(end-1:end), '.m')
    if isMFileWithCode(path)
      arch = 'mfile';
    else
      arch = 'mdoc';
    end
  else
    [status,objdump] = system(sprintf(...
        'objdump -x ''%s'' | grep "file format" | head -n 1', path));
    if status==0
      arch = objdump(strfind(objdump, 'file format ')+12:end-1);
    end
  end
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function p = splitSemiColonPaths(p)
%p = splitSemiColonPaths(p)
%  Splits semicolon-delimited strings
p = split(';',p);

