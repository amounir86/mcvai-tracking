function [out,out2] = videoReader_imread(cmd, handle, varargin)
%videoReader_imread
%  This is a videoReader plugin that uses Matlab's IMREAD function to
%  read individual images from disks as if they were video frames.  
%
%  This function provides the documentation and implementation for the
%  plugin.  Users should not call this function directly.  Instead they
%  should use the videoReader constructor and specify the 'imread'
%  plugin.
%
%  vr = videoReader(FILEPATTERN,'imread',...)
%  vr = videoReader(FILEPATTERN,...,'plugin','imread',...)
%     Indexes a set of image files so they can be accessed via the
%     videoReader interface.  FILEPATTERN may either use wildcards,
%     e.g. 'mydir/*.png' or it may use a sprintf-like '%d' string,
%     e.g. 'mydir/%04d.png'.  The wildcard or sprintf substitution must 
%     be in the filename, not in a directory name (e.g. neither
%     'mydir/%04d/pic.png' nor 'mydir/*/pic.png' is allowed).
%
%     For sprintf strings, we assume that the substituted number is the
%     frame number.  Currently, only non-negative numbers are supported.
%     Only frames that are found when the open command is executed can 
%     be read.  If one seeks to a frame number that does not correspond
%     to a file on disk, GETFRAME will treat it as a dropped frame and
%     silently return an empty matrix, [].
%
%     For wildcard strings, all files matching the pattern are examined
%     and they are sorted in alphabetic order.  The alphabetically-first
%     frame is used as frame 0.  Only frames that are found when the
%     open command is executed can be read.
%
%     Both the percent character (%) and wildcards (?,*) cannot appear 
%     in the same file pattern at the present time (e.g. 
%     'mydir/*/%04d.png' is not allowed).  The percent character may
%     appear at most once (e.g. 'mydir/%04d_%04d.png' is not allowed). 
%    
%     At this time, no optional constructor arguments are allowed.
%
%     This plugin is implemented as an M-file, so no compilation is
%     required. 
%
% EXAMPLE:
%     % make a few video frames -- a rotating gradient
%     for i=1:10
%       frame = repmat(mod([0:99]/99 + (i-1)/10, 1), [75,1]);
%       imwrite(frame, sprintf('%04d.jpg', i));
%     end
%
%     % read in the video and show it as a movie
%     vr = videoReader('%04d.jpg', 'plugin','imread');
%     for i=1:10
%       seek(vr,i);
%       imshow(getframe(vr));
%       title(sprintf('frame %d', i));
%       pause(1);
%     end
%     vr = close(vr);
%
% SEE ALSO:
%     imread
%     videoReader
%     videoReader_load
%     videoReader_matrix
%
%Copyright (c) 2008 Gerald Dalley
%See "MIT.txt" in the installation directory for licensing details
%(especially when using this library on GNU/Linux). 

% We use private/handleManager under the covers to map handles to objects.

if strcmp(cmd, 'close'),
  %........................................................................
  % CLOSE COMMAND
  if ~isempty(varargin)
    error('The "close" command does not take any optional arguments');
  end
  handleManager(handle, 'close');
  
elseif strcmp(cmd, 'getframe')
  %........................................................................
  % GETFRAME COMMAND
  if ~isempty(varargin)
    error('The "getframe" command does not take any optional arguments');
  end
  obj     = handleManager(handle);
  dirname = obj.dirname;
  fname   = obj.filenames{obj.currFrame+1};
  try
    out = imread(fullfile(dirname, fname));
  catch
    out = [];
  end
  
elseif strcmp(cmd, 'get')
  %........................................................................
  % GET COMMAND
  if ~isempty(varargin)
    error('The "get" command does not take any optional arguments');
  end
  obj                 = handleManager(handle);
  info                = obj.info;
  info.currFrame      = obj.currFrame;
  info.approxFrameNum = obj.currFrame;
  out                 = fieldnames(info);
  out2                = struct2cell(info);
  
elseif strcmp(cmd, 'next')
  %........................................................................
  % NEXT COMMAND
  if ~isempty(varargin)
    error('The "next" command does not take any optional arguments');
  end
  obj = handleManager(handle);
  obj.currFrame = obj.currFrame + 1;
  if obj.currFrame < obj.info.numFrames
    out = int32(1);
  else
    out = int32(0);
  end
  handleManager(handle, obj);
  
elseif strcmp(cmd, 'open')
  %........................................................................
  % OPEN COMMAND
  
  if length(varargin)>1
    error(['No optional arguments are supported for the "open" command are '...
           'supported for the imread plugin']); 
  end
  
  filepattern = varargin{1};
  [dirname, filenames] = getFileList(filepattern);
  
  img = imread(fullfile(dirname, filenames{end}));

  obj = struct;
  obj.currFrame = -1;
  obj.dirname   = dirname;
  obj.filenames = filenames;
  obj.info = struct(...
      'url',                varargin{1}, ...
      'fps',               -1, ...
      'height',             size(img,1), ...
      'width',              size(img,2), ...
      'numFrames',          length(filenames), ...
      'fourcc',             '',...
      'nHiddenFinalFrames', 0);
  out = handleManager([], obj);
  
elseif strcmp(cmd, 'seek')
  %........................................................................
  % SEEK COMMAND
  if length(varargin) ~= 1
    error('The "seek" command takes exactly one argument');
  end
  obj           = handleManager(handle);
  obj.currFrame = varargin{1};
  if obj.currFrame < obj.info.numFrames 
    out = int32(1);
  else
    out = int32(0);
  end
  handleManager(handle, obj);
  
elseif strcmp(cmd, 'step')
  %........................................................................
  % STEP COMMAND
  if length(varargin) ~= 1
    error('The "step" command takes exactly one argument');
  end
  obj = handleManager(handle);
  obj.currFrame = obj.currFrame + varargin{1};
  if obj.currFrame < obj.info.numFrames 
    out = int32(1);
  else
    out = int32(0);
  end
  handleManager(handle, obj);
  
else
  error(['Unrecognized command: "' cmd '"']);
end

