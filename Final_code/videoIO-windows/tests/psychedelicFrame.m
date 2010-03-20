function rgbFrame = psychedelicFrame(w,h,i)
%rgbFrame = psychedelicFrame(w,h,i)
%  Creates an RGB image for frame #I that cycles through hues and has
%  expanding ovals.  
%
%Example:
%  vw = videoWriter('psychedelic.avi', 'width',320, 'height',240);
%  for i=1:100
%    addframe(vw, psychedelicFrame(320,240,i));
%  end
%  vw = close(vw);

[x,y] = meshgrid(1:w, 1:h);
x = 3 * (x - w/2) / w;
y = 3 * (y - h/2) / h;
hsvFrame = ones(h,w,3);

val = cos(2.*pi.*(x.^2 + y.^2) - i/5) + 1;
hue = mod(i/500,1);
hsvFrame(:,:,1) = hue;
hsvFrame(:,:,2) = val;
rgbFrame = hsv2rgb(hsvFrame);

rgbFrame = floor(255*rgbFrame);
rgbFrame(rgbFrame<0)   = 0;
rgbFrame(rgbFrame>255) = 255;
rgbFrame = uint8(rgbFrame);
