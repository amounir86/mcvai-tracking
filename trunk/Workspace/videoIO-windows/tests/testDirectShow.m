%testDirectShow
%  Script that runs tests on Windows using the DirectShow plugin.
%
%Example:
%  testDirectShow
%
%Copyright (c) 2006 Gerald Dalley
%See "MIT.txt" in the installation directory for licensing details (especially
%when using this library on GNU/Linux). 

ienter

% Make sure we have the most up-to-date version
if exist('buildVideoIO', 'file') == 2, buildVideoIO('DirectShow'); end 

standardTestBattery('DirectShow')

iprintf('SUCCESS: no errors detected in loadable files');

iexit