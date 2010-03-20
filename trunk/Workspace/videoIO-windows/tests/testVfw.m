%testVfw
%  Script that runs tests on Windows using the Vfw writer 'Vfw'.
%
%Example:
%  testVfw
%
%Copyright (c) 2008 Gerald Dalley
%See "MIT.txt" in the installation directory for licensing details (especially
%when using this library on GNU/Linux). 

ienter

% Make sure we have the most up-to-date version
if exist('buildVideoIO', 'file') == 2, buildVideoIO('DirectShow'); end 

writeTests('Vfw', 'DirectShow');
testBitRate('Vfw'); 
testGopSize('Vfw');
testQuality('Vfw');
longWriteTest('Vfw', 'DirectShow');

iexit