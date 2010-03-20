function setup_framework()
% Setup paths for tracking framework.

if isunix()
  addpath('videoIO-linux');
else
  addpath('videoIO-windows');
end


