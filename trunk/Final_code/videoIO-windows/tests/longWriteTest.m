function longWriteTest(plugin, readerPlugin)
%longWriteTests(plugin)
%longWriteTests(writerPlugin, readerPlugin)
%  Performs a battery of lengthy read-write tests on a given videoReader/
%  videoWriter plugin.  Uses the default codec.
%
%Examples:
%  longWriteTest               % use default plugin
%  longWriteTest ffmpegPopen2  % linux & similar
%  longWriteTest ffmpegDirect  % ...if system's gcc is compatible w/ Matlab's
%  longWriteTest DirectShow    % Windows

ienter

if nargin < 1, plugin = defaultVideoIOPlugin; end
if nargin < 2, readerPlugin = plugin;         end

w = 352;
h = 288;

for E=5:10
  nframes = 2^E;
  ienter('Testing writing then reading %d frames...', nframes);

  fname = [tempname '.avi'];
  
  % write video
  try
    tic;
    vw = videoWriter(fname, plugin, 'width',w, 'height',h);
    for i=1:nframes
      rgbFrame = psychedelicFrame(w,h, i);
      addframe(vw, rgbFrame);
      %subplot(111); imshow(rgbFrame); pause(0.01); axis equal;
    end
    vw = close(vw);
    writeTime = toc;
  
    % read it back in and make sure it's what we expected
    tic;
    vr = videoReader(fname, readerPlugin);
    info = get(vr);
    for i=1:nframes-double(info.nHiddenFinalFrames)
      vrassert next(vr);
      expectedFrame = double(psychedelicFrame(w,h, i)); %#ok<NASGU>
      actualFrame = double(getframe(vr)); %#ok<NASGU>
      % allow a bit of tolerance for compression artifacts...
      vrassert mean(abs(expectedFrame(:) - actualFrame(:))) < 30;
      vrassert median(abs(expectedFrame(:) - actualFrame(:))) < 10;
   
      %subplot(311); imshow(uint8(expectedFrame)); subplot(312); imshow(getframe(vr)); subplot(313); imagesc(max(expectedFrame - actualFrame,[],3)); colorbar; drawnow; pause(0.01);
    end
    vr = close(vr);
    readTime = toc;
    
    % delete temporary file
    delete(fname);
  catch %#ok<CTCH>
    e = lasterror; %#ok<LERR>
    try close(vr); catch end %#ok<CTCH>
    try close(vw); catch end %#ok<CTCH>
    delete(fname);
    rethrow(e);
  end

  iexit('  ...encoding time: %fs, decoding time: %fs', writeTime, readTime);
end

iexit
