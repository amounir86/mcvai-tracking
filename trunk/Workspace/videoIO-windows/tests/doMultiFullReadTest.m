function doMultiFullReadTest(varargin)
%DOMULTIFULLREADTEST(...)
%  First we read the entire specified file into memory.  Then we attempt to
%  simultaneously read the same file in using two videoReader objects.
%  This tests thread and video handle management issues.
%
%  Any arguments given are passed directly to the videoReader constructor.
%
%Examples:
%  doMultiFullReadTest numbers.uncompressed.avi
%  doMultiFullReadTest numbers.uncompressed.avi ffmpegPopen2  % linux & similar
%  doMultiFullReadTest numbers.uncompressed.avi ffmpegDirect  % ...if system's gcc is compatible w/ Matlab's
%  doMultiFullReadTest numbers.uncompressed.avi DirectShow    % Windows
%
%Copyright (c) 2006 Gerald Dalley
%See "MIT.txt" in the installation directory for licensing details (especially
%when using this library on GNU/Linux).

ienter('>>> %s(''%s'',...)', mfilename, varargin{1});
images = doFullRead(varargin{:});
if (size(images,3) > 1) % skip single-frame videos
  % make sure first two frames have different data (makes sure next is
  % working)
  vrassert any(images(:,:,1) ~= images(:,:,2));

  % read from multiple videos at the same time
  vr1 = videoReader(varargin{:});
  vr2 = videoReader(varargin{:});
  i = 1;
  while (next(vr1) && next(vr2))
    i1 = getframe(vr1); i1 = uint8(sum(double(i1), 3) / size(i1,3));
    i2 = getframe(vr2); i2 = uint8(sum(double(i2), 3) / size(i2,3));
    
    % Do the "same" images really look the same?  
    % We must tolerate some differences because some decoders (quite a
    % few, actually) do not always decode the same frame exactly the same
    % every time.
    assertSimilarImages(i1,i2);
    assertSimilarImages(images(:,:,i), i1);
    
    % As a secondary check, we make sure that "same" images are more
    % similar than "different" ones.
    errThisFrame = imageDiff(ilookup(images,i),   i1);
    errNextFrame = imageDiff(ilookup(images,i+1), i1);
    errPrevFrame = imageDiff(ilookup(images,i-1), i1);
    if errPrevFrame > 2 || errThisFrame > 2 || errNextFrame > 2
        vrassert errThisFrame < errNextFrame;
        vrassert errThisFrame < errPrevFrame;
    end
    
    errThisFrame = imageDiff(ilookup(images,i),   i2);
    errNextFrame = imageDiff(ilookup(images,i+1), i2);
    errPrevFrame = imageDiff(ilookup(images,i-1), i2);
    if errPrevFrame > 2 || errThisFrame > 2 || errNextFrame > 2
        vrassert errThisFrame < errNextFrame;
        vrassert errThisFrame < errPrevFrame;
    end
    
    i = i + 1;
  end
  vr1 = close(vr1); %#ok<NASGU>
  vr2 = close(vr2); %#ok<NASGU>
end
iexit('<<< doMultiFullReadTest(''%s'',...)', varargin{1});

%------------------------------------------------------
function out = ilookup(images,i) 
out = images(:,:,mod(i-1,size(images,3))+1);
