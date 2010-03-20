function buildVideoIO(varargin)
%buildVideoIO
%  Wrapper function for building the videoIO (videoReader and videoWriter) 
%  plugins.  Assumes that the user has already installed all required 
%  prerequisites, as described in INSTALL.*.txt.  
%
%  Those using 32-bit Matlab and/or 32-bit ffmpeg on 64-bit GNU/Linux
%  should read the corresponding sections of INSTALL.ffmpeg.txt and will
%  likely want to use at least one of the command-line shell script to
%  perform the build instead of buildVideoIO.
%
%buildVideoIO(makefileTarget)
%  Builds a specific makefile target, where makefileTarget is one of the 
%  following strings:
%
%    'clean'      : removes any compiled and/or temp files
%    'ffmpeg'     : builds the ffmpeg plugins               (Linux only)
%    'DirectShow' : builds the DirectShow plugins           (Windows only)
%    'echo'       : builds a simple popen2 protocol tester  (Linux only)
%
%  Other targets may exist as defined in 'makefile' (Linux only) and
%  'dshow.mak' (Windows only).
%
%buildVideoIO(...)
%  Passes along any arguments as command-line parameters to the
%  underlying makefile.  See 'dshow.mak' on Windows and 'makefile' on
%  GNU/Linux for additional targets and/or environment variables.
%
%Examples:
%  % build plugins using default settings
%  buildVideoIO       
%  % delete all temporary build and all mex files
%  buildVideoIO clean 
%  % build just the popen2 plugins with 32-bit ffmpeg for 64-bit Matlab
%  buildVideoIO FFMPEG_ARCH=glnx86 MEXEXT=mexa64 iffmpegPopen2 offmpegPopen2
%
%SEE ALSO:
%  videoReader
%  videoWriter
%  makefile
%  dshow.mak
%  INSTALL.dshow.html
%  INSTALL.ffmpeg.txt
%
%Copyright (c) 2006,2007,2008 Gerald Dalley
%See "MIT.txt" in the installation directory for licensing details (especially
%when using this library on GNU/Linux). 

clearVideoIO; % avoids file locking issues on .mex* files

origDir = pwd;
cd(videoIODir);

% Construct command-line call to make or nmake
if ispc
  % Windows
  if (isempty(varargin))
    % No varargin
    cmd = ['nmake -f dshow.mak all MEXEXT=' mexext];
  elseif isempty(strmatch('MEXEXT=', varargin{:}))
    % No MEXEXT=<ext> arg
    cmd = ['nmake -f dshow.mak MEXEXT=' mexext ' ' sprintf('%s ',varargin{:})];
  else
    % At least one MEXEXT=<ext> arg
    if all(strcmp(['MEXEXT=' mexext], {varargin{strmatch('MEXEXT=', varargin)}}))
      % <ext> matches the current platform
      cmd = ['nmake -f dshow.mak ', sprintf('%s ',varargin{:})];
    else
      error('Cross-compilation is not supported yet on Windows.');
    end
  end
  
else
  % Linux
  cmd = ['make ', sprintf('%s ',varargin{:},['MEXEXT=' mexext])];
end

fprintf('%s\n', cmd);
[s] = system(cmd);

cd(origDir);
if (s~=0), 
  error(['build failed.  Make sure you read and follow ',...
    'all instructions found in INSTALL.*.txt before attempting ',...
    'to build portions of the videoIO library.']);
end
