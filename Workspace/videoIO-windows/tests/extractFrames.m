% Script to create the frames/ subdirectory.  The data in that directory is
% used to test the 'load' and 'imread' plugins.  This function also
% creates 'matrix3d.mat', 'matrix4d.mat', and 'matrixBoth.mat' for
% testing the 'matrix' plugin. 
%
% Normal users will likely have no need to directly call this function.

N = 100;

if ~exist('frames','dir') || length(dir('frames')) < N*2 || ...
      ~exist('matrix3d.mat', 'file') || ~exist('matrix4d.mat', 'file') || ...
      ~exist('matrixBoth.mat', 'file')
  ienter;
  if ~exist('frames', 'dir')
    mkdir('frames');
  end
  matrix3d = zeros(240, 320, N, 'uint8');
  matrix4d = zeros(240, 320, 3, N, 'uint8');
  for i=0:N-1,
    frame = genTestFrame(320,240,i,N);
    matrix3d(:,:,i+1)   = frame(:,:,1);
    matrix4d(:,:,:,i+1) = frame;
    imwrite(frame, sprintf('frames/numbers.%04d.png', i));
    save(sprintf('frames/numbers.%04d.mat', i), 'frame');    
  end
  save('matrix3d.mat',   'N', 'matrix3d')
  save('matrix4d.mat',   'N', 'matrix4d')
  save('matrixBoth.mat', 'N', 'matrix3d', 'matrix4d')
  iexit;
end