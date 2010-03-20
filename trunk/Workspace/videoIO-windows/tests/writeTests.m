function writeTests(plugin, readerPlugin)
%writeTests(plugin)
%writeTests(writerPlugin, readerPlugin)
%  Performs a battery of simple read-write tests on a given videoReader/
%  videoWriter plugin.  Uses the default codec.
%
%Examples:
%  writeTests
%  writeTests ffmpegPopen2  % linux & similar
%  writeTests ffmpegDirect  % ...if system's gcc is compatible w/ Matlab's
%  writeTests DirectShow    % Windows

ienter

if nargin < 1, plugin = defaultVideoIOPlugin; end
if nargin < 2, readerPlugin = plugin;         end

w = 100;
h = 30;
N = 100;

tmpFile = [tempname '.avi'];

% Make sure the plugin catches bad argument errors
try
  vw = videoWriter(tmpFile, plugin, 'thisIsNotAValidParameterName',0);
  error('invalid parameter name not caught');
catch  %#ok<CTCH>
  % good...we expected an error
end
try
  % make sure ordering doesn't matter
  vw = videoWriter(tmpFile, plugin, ...
                   'width',320, 'thisIsNotAValidParameterName',0);
  error('invalid parameter name not caught');
catch  %#ok<CTCH>
  % good...we expected an error
end

% Try writing a short video
try
  % write the video
  vw = videoWriter(tmpFile, plugin, 'width',w, 'height',h);
  
  frames = {};
  for i=1:N
    frame = [getDigit(floor(i/100)) ...
             getDigit(mod(floor(i/10), 10)) ...
             getDigit(mod(i,10))];
    frame = imresize(frame, [h,w]);
    frames{i} = repmat(uint8(255*frame), [1 1 3]); %#ok<AGROW>
    addframe(vw, frame);
  end
  vw = close(vw);
  
  % read it back in
  vr = videoReader(tmpFile, readerPlugin);
  info = get(vr);
  filt = fspecial('gaussian', 5,2);
  for i=1:N-double(info.nHiddenFinalFrames) - 2 %don't worry if the last few frames didn't work
    vrassert next(vr);  
    diffImg = abs(double(imfilter(frames{i},filt)) - ...
                  double(imfilter(getframe(vr),filt))); %#ok<NASGU>
    vrassert all(all(rgb2gray(diffImg) < 10));
    %subplot(121); imshow(frames{i}); subplot(122); imshow(getframe(vr)); pause(0.01);
  end
  close(vr);
  
  delete(tmpFile);
catch %#ok<CTCH>
  e = lasterror; %#ok<LERR>
  try close(vr); catch end %#ok<CTCH>
  try close(vw); catch end %#ok<CTCH>
  delete(tmpFile);
  rethrow(e);
end
  
iexit
