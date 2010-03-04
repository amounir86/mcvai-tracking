function frame = genTestFrame(w,h,i,N)
%frame = genTestFrame(w,h,i,N)
%  Generates a frame useful for testing.  The video is a rotating
%  psychedelic ellipse with occasionally-repositioned blocks and the frame
%  number pasted inside.
%
%  w: desired frame width
%  h: desired frame height
%  i: frame # to create (0-indexed)
%  N: total # of frames 

% Create some image
frame = psychedelicFrame(w,h,i);
if (i>N/2) && (mod(i,2)==1), frame = fftshift(frame); end; % try to mess up precise seeking

% insert the frame number to make it a little more interesting
fnum = [...
  getDigit(floor(i/1000)) ...
  getDigit(mod(floor(i/100), 10)) ...
  getDigit(mod(floor(i/10), 10)) ...
  getDigit(mod(i,10))];
fnum = imresize(fnum, 8, 'nearest');
for plane=1:3
  block = frame(end-size(fnum,1)+1:end, end-size(fnum,2)+1:end, plane);
  block(logical(fnum)) = 0;
  frame(end-size(fnum,1)+1:end, end-size(fnum,2)+1:end, plane) = block;
end
