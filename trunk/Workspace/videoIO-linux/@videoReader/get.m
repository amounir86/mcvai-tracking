function info = get(vr,varargin)
%INFO=GET(VR)
%  Returns a structure whose fields contain information about the opened
%  video object.  The (minimum) set of fields in the INFO structure is
%  shown below:
%    url        String specifying the data source, in the format preferred
%               by the plugin being used.  Sometimes this will be a true
%               URL, sometimes it will be a filename.
%
%    fps        Non-negative number indicating the number of frames per
%               second.  
%
%    height     Integer indicating the height of the video frames in
%               pixels.   
%
%    width      Integer indicating the width of the video frames in pixels.
%
%    numFrames  Integer indicating an estimate of the total number of 
%               frames in the video.  For typical videos, this number is
%               exact.  Users may attempt to read more than numFrames
%               frames at their own risk.  If nHiddenFinalFrames is
%               non-zero, this will typically fail (meaning next/step/seek
%               will return 0) or worse, corrupted data such as an
%               all-black frame may be returned by the codec.  Some plugins
%               and/or their codecs do not supply this information.  If the
%               number of frames is unknown, a negative number is returned.
%               Older ffmpeg versions (notably version 0.4.9-pre1) do not
%               supply this number.
%
%    fourcc     4- or fewer-character string roughly indicating the codec
%               used encode the video.  See http://www.fourcc.org for
%               additional background information and an extensive, but
%               non-comprehensive list of FourCC codes.
%
%    nHiddenFinalFrames
%               Non-negative integer.  Many codecs make it difficult or 
%               impossible to read the last few frames of a file.  When 
%               videoReader thinks that the last few cannot be read, it 
%               automatically guesses how many frames cannot be read,
%               records this number as nHiddenFinalFrames, and sets
%               numFrames to be the number of frames the file claims to
%               contain minus nHiddenFinalFrames.  An individual
%               videoReader plugin (like the ffmpegPopen2 plugin) may choose
%               to allow the user to try reading the frames that might be
%               hidden or it may choose not to allow even trying to read
%               them (like the DirectShow plugin).
%
%  Due to limitations in some file formats, it is not always possible to
%  determine all of these values (or sometimes they are not constant).  In
%  these cases, numerical values are given a value of NaN and string values
%  are blank.
%
%  Each call to GET makes a fresh call to the plugin, so be aware of
%  potential performance costs if calling it in an inner loop.
%
%VAL=GET(VR,FIELDNAME)
%  Returns the value of FIELDNAME.  The code
%    VAL = get(VR, FIELDNAME);
%  is equivalent to
%    INFO = get(VR);
%    VAL  = INFO.FIELDNAME;
%  This is useful when the value of a particular field is to be used in
%  an inline context, e.g.
%    vr = videoReader(...);
%    for i=0:get(vr, 'numFrames')
%      imshow(getnext(vr));
%      drawnow; pause(0.1);
%    end
%    vr = close(vr);
%
%EXAMPLES:
%  vr = videoReader(fullfile(videoIODir, 'tests/numbers.uncompressed.avi'));
%  info = get(vr)
%  get(vr,'fps')
%
%SEE ALSO
%  videoReader
%
%Copyright (c) 2008 Gerald Dalley
%See "MIT.txt" in the installation directory for licensing details (especially
%when using this library on GNU/Linux). 

% Without this, it can be easy for users to try to disp the object and 
% the error messages in that case are very cryptic.
if isnan(vr.handle)
  info = struct('status','closed');
  return
end

% Get information from the plugin
[names, vals] = feval(vr.plugin, 'get', vr.handle);
pinfo = cell2struct({vals{:}}, {names{:}}, 2);

% be nice and convert anything that looks like a number into one.
for i=1:length(names)
  name = names{i};
  if (length(pinfo.(name)) < 64) && ischar(pinfo.(name))
    [num,ok] = str2num(pinfo.(name)); %#ok<ST2NM> (these can be matrices)
    if ok
      pinfo.(name) = num;
    end
  end
end

% merge Matlab-side and plugin-side metadata
ctor = class(vr);
info = struct(vr);
fnames = fieldnames(pinfo);
for i=1:length(fnames)
  fname = fnames{i};
  info.(fname) = pinfo.(fname);
end
info = orderfields(info);

% make pretty plugin name...the way the constructor expects it
if isfield(info, 'plugin') && ~isempty(strmatch([ctor '_'], info.plugin))
  info.plugin = info.plugin(length(ctor)+2:end);
end

% Return what was requested
switch length(varargin)
 case 0
  % do nothing -- return the whole struct
 case 1
  info = info.(varargin{1});
 otherwise
  error('Too many arguments.');
end
