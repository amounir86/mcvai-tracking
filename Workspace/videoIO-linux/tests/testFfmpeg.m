function testFfmpeg
%testFfmpeg
%  Runs tests on Linux using the Ffmpeg plugin, using the ffmpegPopen2 and
%  ffmpegDirect plugins.  Linux and linux-like operating systems only.  
%
%  On some systems, the ffmpegDirect plugin may fail due to incompatibilies
%  between the version of gcc used for Matlab and the version used to
%  compile the plugins.  In these cases, the user should only use the
%  ffmpegPopen2 plugin (see INSTALL.ffmpeg.txt).
%
%Example:
%  testFfmpeg
%
%Copyright (c) 2006 Gerald Dalley
%See "MIT.txt" in the installation directory for licensing details (especially
%when using this library on GNU/Linux). 

ienter;

if exist('buildVideoIO', 'file') == 2, buildVideoIO('ffmpeg'); end 

standardTestBattery('ffmpegPopen2')
standardTestBattery('ffmpegDirect')

iprintf('SUCCESS: no errors detected\n');

iexit;