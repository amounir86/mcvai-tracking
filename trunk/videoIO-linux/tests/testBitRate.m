function testBitRate(varargin)
%testBitRate
%   This function attempts to figure out what codecs support the bitRate
%   constructor parameter (see videoWriter.m).  To do so, we try encoding a
%   short video clip with various bitRate values and see if the resulting
%   file sizes differ (if so, then bitRate is supported).  We do this for
%   each codec and print the results to the screen.
%
%testBitRate(pluginName)
%   Run the tests with a manually-specified videoWriter plugin (see
%   videoWriter.m).
%
%Examples:
%  testBitRate               % use default plugin
%  testBitRate ffmpegPopen2  % linux & similar
%  testBitRate ffmpegDirect  % ...if system's gcc is compatible w/ Matlab's
%  testBitRate DirectShow    % Windows
%
% SEE ALSO:
%   buildVideoIO
%   videoWriter
%   testGopSize
%   testBitRate
%

ienter;

if nargin < 1
  pluginSpec = {}; % use default
else
  pluginSpec = {'plugin', varargin{1}};
end

width = 352; height = 288; 
nFrames = 25; % This is usually enough to tell, adjust higher at will

bitRateSupported = 'bitRate supported';
bitRateIgnored   = 'bitRate ignored';
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
  bitRates = [1024,1024*1024];
  iprintf('     codec encoding time bitRate supported   sizes');
  iprintf('---------- ------------- -----------------   -----');
  for c=1:length(codecs)
    codec = codecs{c};
    status = CantEncode;
    tic;  
    try
      sz = zeros(size(bitRates));

      if (strcmpi(codec, 'CFHD'))
        % Right now (13 Nov 2007), the CineForm HD codec does not play well
        % with Matlab.  If an encoder license has not been purchased, it will
        % crash some versions of Matlab.  Remove this conditional if you
        % have purchased an encoder license.
        status = Skipped;
        throw;
      end

      for gi = 1:length(bitRates)
        bitRate = bitRates(gi);
        sz(gi) = encode(tmpDir, pluginSpec, codec, bitRate, frames);
      end
      
      if all(sz(1:end-1) == sz(2:end))
        status = bitRateIgnored;
      else
        status = bitRateSupported;
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
function sz = encode(tmpDir, pluginSpec, codec, bitRate, frames)
%sz = encode(tmpDir, pluginSpec, codec, bitRate, frames)
%   encode the frames, return its size, and cleanup our messes

try
  filename = fullfile(tmpDir, sprintf('testBitRate_%s_%04d.avi', codec, bitRate));
  vw = videoWriter(filename, pluginSpec{:}, ...
    'bitRate',bitRate, 'codec',codec, 'width',size(frames,2), ...
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
