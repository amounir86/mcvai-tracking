function testMatrix
%testMatrix
%  Runs platform-independent tests using the 'matrix' videoReader
%  plugin. 
%
%Example:
%  testMatrix
%
%Copyright (c) 2008 Gerald Dalley
%See "MIT.txt" in the installation directory for licensing details (especially
%when using this library on GNU/Linux). 

ienter;

% generate the data, if needed
extractFrames; 

load matrix3d.mat matrix3d N;
load matrix4d.mat matrix4d;

vr3   = videoReader(matrix3d, 'matrix');
vr3f  = videoReader('matrix3d.mat', 'matrix');
vr3b  = videoReader('matrixBoth.mat', 'matrix', 'varname','matrix3d');
vr4   = videoReader(matrix4d, 'matrix');
vr4f  = videoReader('matrix4d.mat', 'matrix');
vr4b  = videoReader('matrixBoth.mat', 'matrix', 'varname','matrix4d');
vrb   = videoReader('matrixBoth.mat', 'matrix');

for i=0:N-1
  vrassert next(vr3);
  vrassert next(vr3f);
  vrassert next(vr3b);
  vrassert next(vr4);
  vrassert next(vr4f);
  vrassert next(vr4b);
  vrassert next(vrb);
  
  vrassert all(all(matrix3d(:,:,i+1) == getframe(vr3)));
  vrassert all(all(matrix3d(:,:,i+1) == getframe(vr3f)));
  vrassert all(all(matrix3d(:,:,i+1) == getframe(vr3b)));
  vrassert all(all(all(matrix4d(:,:,:,i+1) == getframe(vr4))));
  vrassert all(all(all(matrix4d(:,:,:,i+1) == getframe(vr4f))));
  vrassert all(all(all(matrix4d(:,:,:,i+1) == getframe(vr4b))));
  vrassert all(all(all(matrix4d(:,:,:,i+1) == getframe(vrb))));
end

close(vr3);
close(vr3f);
close(vr3b);
close(vr4);
close(vr4f);
close(vr4b);
close(vrb);

iexit;
