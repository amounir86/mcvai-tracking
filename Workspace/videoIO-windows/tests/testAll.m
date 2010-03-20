%testAll
%  Script that runs all known tests for the current platform, using the
%  appropriate videoReader/videoWriter plugins.
%
%Example:
%  testAll
%
%Copyright (c) 2006 Gerald Dalley
%See "MIT.txt" in the installation directory for licensing details (especially
%when using this library on GNU/Linux). 

% make sure that we have fresh plugins
clear mex videoReader* videoWriter*;
% clear our indentation shared variable (assumes testAll is never called
% by a higher-level script).
clear global videoIO_test_indentLevel;

ienter

% this is an internal test that should never fail
test_pvtVideoIO_mexName;

% Test the 'load' and 'imread' plugins
testLoadAndImread;

% Test the 'matrix' plugin
testMatrix;

% Test the primary videoReader and videoWriter plugins for the current
% platform.
if ispc, 
  testDirectShow; 
  testVfw; 
else
  testFfmpeg;
end

% Test the videoread function
testVideoRead;

iexit
