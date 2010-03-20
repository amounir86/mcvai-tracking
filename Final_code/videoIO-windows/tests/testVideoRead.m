%testVideoRead
%  Simple tests for the videoread function.  Always uses the default
%  videoReader plugin.
%
%Example:
%  testVideoRead
%
%Copyright (c) 2006 Gerald Dalley
%See "MIT.txt" in the installation directory for licensing details
%(especially when using this library on GNU/Linux). 

ienter

imgs = doFullRead('numbers.uncompressed.avi');
mov = videoread('numbers.uncompressed.avi');

vrassert abs(length(imgs) - length(mov)) < 4;
for i=1:min(length(imgs), length(mov))
  movImg = mov(i).cdata;
  movImg = uint8(sum(double(movImg), 3) / size(movImg,3));
  vrassert all(movImg == imgs(:,:,i));
end

iexit
