function doPreciseSeekTests(varargin)
%DOPRECISESEEKTESTS(...)
%  Performs a set of tests on a video file that are designed to succeed only if
%  precise seeking actually works on that file.  Note that if a file has
%  a small number of frames and/or only a small variance in bitrate
%  between frames, it may pass the precise seek tests when other files
%  using the same codec may not.
%
%  Any arguments given are passed directly to the videoReader constructor.
%
%Examples:
%  doPreciseSeekTests numbers.uncompressed.avi
%  doPreciseSeekTests numbers.uncompressed.avi ffmpegPopen2  % linux & similar
%  doPreciseSeekTests numbers.uncompressed.avi ffmpegDirect  % ...if system's gcc is compatible w/ Matlab's
%  doPreciseSeekTests numbers.uncompressed.avi DirectShow    % Windows
%
%Copyright (c) 2006 Gerald Dalley
%See "MIT.txt" in the installation directory for licensing details (especially
%when using this library on GNU/Linux). 

ienter('>>> %s(''%s'',...)', mfilename, varargin{1});
images = doFullRead(varargin{:});

%%% test seek and step %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

vr = videoReader(varargin{:});
% make sure first two frames have different data (makes sure next is
% working)
vrassert any(any(images(:,:,1) ~= images(:,:,2)));

% step back one frame to 1st frame
vrassert next(vr);                      % -1 -> 0
vrassert next(vr);                      % 0 -> 1
vrassert step(vr, -1);                  % 1 -> 0
img = getframe(vr); img = uint8(sum(double(img), 3) / size(img,3));
assertSimilarImages(images(:,:,1), img);

% seek backward to 1st frame
vrassert next(vr);                      % 0 -> 1
vrassert seek(vr, 0);                   % 1 -> 0
img = getframe(vr); img = uint8(sum(double(img), 3) / size(img,3));
assertSimilarImages(images(:,:,1), img);
% step nowhere
vrassert step(vr, 0);                   % 0 -> 0
img = getframe(vr); img = uint8(sum(double(img), 3) / size(img,3));
assertSimilarImages(images(:,:,1), img);

% step back one frame
vrassert next(vr);                      % 0 -> 1
vrassert next(vr);                      % 1 -> 2
vrassert step(vr, -1);                  % 2 -> 1
img = getframe(vr); img = uint8(sum(double(img), 3) / size(img,3));
assertSimilarImages(images(:,:,2), img);
% seek back one frame
vrassert next(vr);                      % 1 -> 2
vrassert seek(vr, 1);                   % 2 -> 1
img = getframe(vr); img = uint8(sum(double(img), 3) / size(img,3));
assertSimilarImages(images(:,:,2), img);
% step back 2 frames
vrassert next(vr);                      % 1 -> 2
vrassert next(vr);                      % 2 -> 3
vrassert step(vr, -2);                  % 3 -> 1
img = getframe(vr); img = uint8(sum(double(img), 3) / size(img,3));
assertSimilarImages(images(:,:,2), img);
% seek back 2 frames
vrassert next(vr);                      % 1 -> 2
vrassert next(vr);                      % 2 -> 3
vrassert seek(vr, 1);                   % 3 -> 1
img = getframe(vr); img = uint8(sum(double(img), 3) / size(img,3));
assertSimilarImages(images(:,:,2), img);
% step forward 2 frames
vrassert step(vr, 2);                   % 1 -> 3
img = getframe(vr); img = uint8(sum(double(img), 3) / size(img,3));
assertSimilarImages(images(:,:,4), img);
% seek forward 2 frames
vrassert seek(vr, 5);                   % 3 -> 5
img = getframe(vr); img = uint8(sum(double(img), 3) / size(img,3));
assertSimilarImages(images(:,:,6), img);
if (size(images,3)>30*7)
  % step forward > 5 seconds
  vrassert seek(vr,0);
  vrassert step(vr,6*30);
  img = getframe(vr); img = uint8(sum(double(img), 3) / size(img,3));
  assertSimilarImages(images(:,:,6*30+1), img);
  % seek forward > 5 seconds
  vrassert seek(vr,0);
  vrassert seek(vr,6*30);
  img = getframe(vr); img = uint8(sum(double(img), 3) / size(img,3));
  assertSimilarImages(images(:,:,6*30+1), img);
end

% random seeks 
info = get(vr);
for f=floor(rand(1,100)*(info.numFrames-1))
  vrassert seek(vr,f);
  img = getframe(vr); img = uint8(sum(double(img), 3) / size(img,3));
  assertSimilarImages(images(:,:,f+1), img);
end

close(vr);

iexit('<<< doPreciseSeekTests(''%s'',...)', varargin{1});

%-------------------------------------------------------------
function dispResults(images, img, f) %#ok<DEFNU>
% Little helper function to show results when precise seeks don't work
% as expected

subplot(311); 
imshow(images(:,:,f+1)); 
title(sprintf('linearly-read frame %d', f));

subplot(312); 
imshow(img); 
title('read via seeking');

subplot(313);
imshow(double(images(:,:,f+1)) - double(img), []);
colorbar;
title('diff image');
