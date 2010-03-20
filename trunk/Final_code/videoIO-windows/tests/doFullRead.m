function images = doFullRead(varargin)
%IMAGES=DOFULLREAD(...)
%  Reads in an entire video into a 3D array where only the red channel is 
%  retained (just to make it easier).
%
%  Any arguments given are passed directly to the videoReader constructor.
%
%Examples:
%  imgs = doFullRead;
%  imgs = doFullRead('numbers.uncompressed.avi','ffmpegPopen2');  % linux & similar
%  imgs = doFullRead('numbers.uncompressed.avi','ffmpegDirect');  % ...if system's gcc is compatible w/ Matlab's
%  imgs = doFullRead('numbers.uncompressed.avi','DirectShow');    % Windows
%
%Copyright (c) 2006 Gerald Dalley
%See "MIT.txt" in the installation directory for licensing details (especially
%when using this library on GNU/Linux). 

ienter('>>> %s(''%s'',...)', mfilename, varargin{1});
vr = videoReader(varargin{:});
info = get(vr);
images = uint8(zeros(info.height, info.width, info.numFrames));
i=1;
while (next(vr))
  img = getframe(vr);
  images(:,:,i) = uint8(sum(double(img), 3) / size(img,3));
  %imshow(img); drawnow; pause(0.001);
  i = i+1;
end
vr = close(vr); %#ok<NASGU>
iexit('<<< doFullRead(''%s'',...)', varargin{1});
