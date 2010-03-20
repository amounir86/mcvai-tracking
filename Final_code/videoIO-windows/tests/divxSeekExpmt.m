function divxSeekExpmt
%divxSeekExpmt
%  This is a test file for debugging off-by-one biases for mpeg4 decoders,
%  especially the DivX and ffdshow filters on Windows.  People other than
%  the author will probably not need this file.
%
%Example:
%  divxSeekExpmt;
%  --> a few plots are created that the user can check for consistency.

%%
clear all; clc; clf; drawnow;
buildVideoIO;
mov = videoRead('numbers.uncompressed.avi');
R = 2;
C = 3;

%%
rr = 1;
vr = videoReader('numbers.divx611.avi');
get(vr)
subplot(R,C,C*(rr-1)+1); next(vr); showResult(mov,vr,0); ylabel('next from 0');
subplot(R,C,C*(rr-1)+2); next(vr); showResult(mov,vr,1);
subplot(R,C,C*(rr-1)+3); next(vr); showResult(mov,vr,2);
vr = close(vr); %#ok<NASGU>

%%
rr = 2;
k=20;

vr = videoReader('numbers.divx611.avi','preciseFrames',k);
subplot(R,C,C*(rr-1)+1); f=19; seek(vr,f); showResult(mov,vr,f); ylabel(sprintf('seek %d, pf=%d', f, k));
vr = close(vr); %#ok<NASGU>

vr = videoReader('numbers.divx611.avi','preciseFrames',k);
subplot(R,C,C*(rr-1)+2); f=20; seek(vr,f); showResult(mov,vr,f); ylabel(sprintf('seek %d, pf=%d', f, k));
vr = close(vr); %#ok<NASGU>

vr = videoReader('numbers.divx611.avi','preciseFrames',k);
subplot(R,C,C*(rr-1)+3); f=21; seek(vr,f); showResult(mov,vr,f); ylabel(sprintf('seek %d, pf=%d', f, k));
vr = close(vr); %#ok<NASGU>

%----------------------------------------------------------------------
function showResult(mov, vr, f)

img = double(getframe(vr))/255;

N = length(mov);
mad = zeros(N,1);
for i=1:N
  mad(i) = mean(mean(mean(abs(double(mov(i).cdata)/255 - img))));
end
[dummy,bestGuess] = min(mad);
bestGuess = bestGuess - 1;

if bestGuess == f
  imshow(img);
  title(f);
else
  imshow(1-img);
  title(sprintf('is %d; expected %d', bestGuess, f));
end
