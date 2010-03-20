function testQuality(varargin)
%testQuality
%   This function attempts to figure out what codecs support the quality
%   constructor parameter (see videoWriter.m).  To do so, we try encoding a
%   short video clip with various quality values and see if the resulting
%   file sizes differ (if so, then quality is supported).  We do this for
%   each codec and print the results to the screen.
%
%testQuality(pluginName)
%   Run the tests with a manually-specified videoWriter plugin (see
%   videoWriter.m).
%
%Examples:
%  testQuality               % use default plugin
%  testQuality ffmpegPopen2  % linux & similar
%  testQuality ffmpegDirect  % ...if system's gcc is compatible w/ Matlab's
%  testQuality DirectShow    % Windows
%
% SEE ALSO:
%   buildVideoIO
%   videoWriter
%   testBitRate
%   testGopSize
%

ienter;

if nargin < 1
  pluginSpec = {}; % use default
else
  pluginSpec = {'plugin', varargin{1}};
end

width = 352; height = 288; 
nFrames = 25; % This is usually enough to tell, adjust higher at will

qualitySupported = 'quality supported';
qualityIgnored   = 'quality ignored';
CantEncode       = 'unable to encode';
Skipped          = 'skipped'; % known compatability problems

% Generate some frames that have enough structure that there's a point in
% not keyframing every frame but some noise so that there's some incentive
% to keyframe every once in a while.
frames = zeros(height, width, nFrames);
frames(:,:,1)   = rand(height, width, 1);
for i=2:nFrames
  frames(:,:,i) = max(min(...
    [frames(:,5:end,i-1) frames(:,1:4,i-1)] + ...
    randn(height, width, 1)*25/255, ...
    1), 0);
end

try 
  w = warning; warning off; %#ok<WNOFF>
  tmpDir = tempname; mkdir(tmpDir);
  
  codecs = videoWriter([],'codecs',pluginSpec{:});
  qualities = [0,10000];
  iprintf('     codec encoding time quality supported   sizes');
  iprintf('---------- ------------- -----------------   -----');
  for c=1:length(codecs)
    codec = codecs{c};
    status = CantEncode;
    tic;  
    try
      sz = zeros(size(qualities));

      if (strcmpi(codec, 'CFHD'))
        % Right now (13 Nov 2007), the CineForm HD codec does not play well
        % with Matlab.  If an encoder license has not been purchased, it will
        % crash some versions of Matlab.  Remove this conditional if you
        % have purchased an encoder license.
        status = Skipped;
        throw;
      end

      for gi = 1:length(qualities)
        quality = qualities(gi);
        sz(gi) = encode(tmpDir, pluginSpec, codec, quality, frames);
      end
      
      if all(sz(1:end-1) == sz(2:end))
        status = qualityIgnored;
      else
        status = qualitySupported;
      end
    catch
      clearVideoIO videoWriter;
    end
    encodingTime = toc;
    
    iprintf('%10s %10ds   %17s   %s', ...
      codec, ceil(encodingTime), status, num2str(sz));
  end
  
  pause(1);
  try rmdir(tmpDir, 's'); catch end
  warning(w);
catch
  warning(w);
  try rmdir(tmpDir, 's'); catch end
  rethrow(lasterror);
end

iexit;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function sz = encode(tmpDir, pluginSpec, codec, quality, frames)
%sz = encode(tmpDir, pluginSpec, codec, quality, frames)
%   encode the frames, return its size, and cleanup our messes

try
  filename = fullfile(tmpDir, sprintf('testQuality_%s_%04d.avi', codec, quality));
  vw = videoWriter(filename, pluginSpec{:}, ...
    'quality',quality, 'codec',codec, 'width',size(frames,2), ...
    'height',size(frames,1)); 
  for i=1:size(frames,3), 
    addframe(vw, frames(:,:,i)); 
  end
  close(vw);
  d = dir(filename);
  sz = d.bytes;
  delete(filename);
catch
  e = lasterror;
  try close(vw); catch end
  delete(filename);
  rethrow(e);
end
