function readTests(plugin)
%readTests(plugin)
%  Performs a battery of read tests on a given videoReader plugin
%
%Examples:
%  readTests
%  readTests ffmpegPopen2  % linux & similar
%  readTests ffmpegDirect  % ...if system's gcc is compatible w/ Matlab's
%  readTests DirectShow    % Windows

ienter

if nargin < 1, plugin = defaultVideoIOPlugin; end

% use only constant bit rate and/or indexed videos
try
  doPreciseSeekTests('numbers.uncompressed.avi', plugin, 'preciseFrames',1);
catch %#ok<CTCH> -- backward compatibility
  warning('videoIO:tests:precise', ...
    ['Seeking in uncompressed videos is imprecise on your system when '...
    'using the ' plugin ' plugin.  This deficiency is known to occur '...
    'on some Windows XP systems.']);
end
if ispc
  % old versions of ffmpeg on linux didn't handle wmv3 files properly, so
  % skip the test on non-Windows boxes
  try
    doPreciseSeekTests('numbers.wmv3.avi', plugin);
  catch %#ok<CTCH> -- backward compatibility
    warning('videoIO:tests:precise', ...
      ['Seeking in Windows Media 9 videos is imprecise on your system '...
      'when using the ' plugin ' plugin.  This is not a major problem.']);
  end
end

% use all
doMultiFullReadTestOnAllLoadables(plugin);

% cause an exception in the mex file
vr = videoReader('numbers.uncompressed.avi', plugin);
try
  vrassert seek(vr, struct('abc', sparse(10)));
  error('The previous seek command should have failed');
  %vr = close(vr);
catch
  vr = close(vr); %#ok<NASGU>
end

% cause an exception in the backend
vr = videoReader('numbers.uncompressed.avi', plugin);
try
  vrassert seek(vr, 'abcdef'); 
  error('The previous seek command should have failed');
  %vr = close(vr);
catch
  close(vr);
  iprintf('Successfully caught backend error: %s\n', lasterr);
end

iexit
