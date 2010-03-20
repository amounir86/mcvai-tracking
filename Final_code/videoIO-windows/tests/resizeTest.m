function resizeTest(plugin)
%writeTests(plugin)
%  Checks to see if automatic resizing of images is working properly for a
%  given videoReader/videoWriter plugin using some quick heuristics.  
%
%Examples:
%  resizeTest
%  resizeTest ffmpegPopen2  % linux & similar
%  resizeTest ffmpegDirect  % ...if system's gcc is compatible w/ Matlab's
%  resizeTest DirectShow    % Windows

ienter

if nargin < 1, plugin = defaultVideoIOPlugin; end

W = 640;
H = 480;
fname = [tempname '.avi'];
try
  vw = videoWriter(fname, plugin, 'width',W, 'height',H);
  widths = 4:40:640;
  for i=1:length(widths)
    w = widths(i);
    frame = psychedelicFrame(w,w,i);
    addframe(vw, frame);
  end
  vw = close(vw);
  
  vr = videoReader(fname, plugin);
  info = get(vr); %#ok<NASGU>
  vrassert W == info.width;
  vrassert H == info.height;
  vr = close(vr); %#ok<NASGU>
  
  delete(fname);
catch
  e = lasterror;
  try close(vw); catch end
  delete(fname);
  rethrow(e);
end

iexit
