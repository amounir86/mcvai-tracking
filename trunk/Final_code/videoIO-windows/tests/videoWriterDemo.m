%videoWriterDemo
%  A script showing an interesting usage of videoWriter.  Shows basic usage
%  of videoWriter objects with extra-safe cleanup.
%
%Example:
%  videoWriterDemo


ienter;

% be nice and build the plugins if the user for got to (most scripts would
% skip this).
if exist('buildVideoIO', 'file') == 2, buildVideoIO; end

% create the videoWriter object using default settings
fname = [tempname '.avi'];
try
  vw = videoWriter(fname);
  
  % get the width and height of the video so we know how big to make the
  % input frames.  This isn't strictly necessary--we either could have
  % told the videoWriter constructor what frame size we wanted or we could
  % let addframe rescale the frames automatically for us.
  info = get(vw);
  w = info.width;
  h = info.height;
  
  % Add 1001 frames to our video
  N = 5000;
  for i=0:N
    if (mod(i,100)==0), iprintf('creating frame %d...', i); end
    
    % Create some image
    frame = genTestFrame(w,h,i,N);
    
    % encode the frame
    addframe(vw, frame);
  end
  
  % make sure to clean up...otherwise the output file may be corrupted
  vw = close(vw);

  iprintf(['The file "%s" has been created.  Default videoWriter args were ' ...
           'used.  You may inspect it to see the results.'], fname);
catch
  % On error, here we try as hard as possible to clean up any messes.  
  e = lasterror;
  % Often the backend will close the writer object on error, but if it can
  % avoid closing it, it will.  Thus we try to close it here.  This way we
  % can free up any resources (memory, threads, file locks, etc.) and if
  % the video file doesn't have any errors, the backend gets a chance to
  % write out the footer for the video.
  try close(vw); catch end
  % In this case we just want to delete any problematic files (so writing
  % the footer wasn't actually important in this special case, but
  % releasing resources was).
  delete(fname);
  % Report the *original* problem to the user (not an error that might have
  % been generated by a failed close attemt).
  rethrow(e);
end

iexit;
