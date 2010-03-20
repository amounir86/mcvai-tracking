function testLoadAndImread
%testLoadAndImread
%  Runs platform-independent tests using the 'load' and 'imread'
%  videoReader plugins. 
%
%Example:
%  testLoadAndImread
%
%Copyright (c) 2008 Gerald Dalley
%See "MIT.txt" in the installation directory for licensing details (especially
%when using this library on GNU/Linux). 

ienter;

extractFrames; % generate the data, if needed
readIndvFrameTests('load','mat', 'varname','frame'); % load w/ expl varname
readIndvFrameTests('load','mat'); % load w/ auto-detected varname
readIndvFrameTests('imread','png'); 

iexit;
